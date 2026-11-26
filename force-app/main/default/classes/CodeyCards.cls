/**
 * Builds the four Project Codey HXL experience screens from tool results:
 *   approval()  - Approval screen: exactly what will change, Before and After, Approve / Reject
 *   health()    - Health check report: each setting OK / Warning / Needs Fix, reason, help link, Fix it
 *   progress()  - Progress tracker: long jobs, per-step status, where a failed job resumes
 *   upgrade()   - Upgrade impact report: customized screens a release affects, risk and suggested action
 * Buttons only open a link or send a message to the agent, so every change still goes through preview -> approve -> commit.
 * Builders never throw; basic() is the fallback.
 */
public with sharing class CodeyCards {

    public static final Integer MAX_ITEMS = 25;

    public class Change {
        public String target; public String action; public String before; public String after; public String detail;
        public Change(String target, String action, String before, String after) { this.target = target; this.action = action; this.before = before; this.after = after; }
    }
    public class HealthRow {
        public String area; public String label; public String status; public String current; public String recommended;
        public String reason; public String helpUrl; public String fixMessage;
    }
    public class StepRow {
        public String label; public String status; public Decimal percent; public String detail;
    }
    public class ImpactRow {
        public String screen; public String kind; public String change; public String risk; public String action;
    }

    // ================================================================= Approval
    public static CodeyCard approval(String title, String subtitle, List<Change> changes, String token, String summary) {
        CodeyCard c = start('approval', title, subtitle, 'check-circle');
        badge(c, 'Waiting for approval', 'warning');
        Integer creates = 0, updates = 0;
        for (Change ch : changes) {
            if (ch.action == 'Create' || ch.action == 'Assign' || ch.action == 'Load' || ch.action == 'Start') creates++; else updates++;
        }
        stat(c, 'Changes', String.valueOf(changes.size()), null);
        if (creates > 0) stat(c, 'New', String.valueOf(creates), null);
        if (updates > 0) stat(c, 'Updated', String.valueOf(updates), null);
        c.itemsTitle = 'What will change';
        Integer shown = 0;
        for (Change ch : changes) {
            if (shown++ >= MAX_ITEMS) break;
            CodeyCardItem it = item(c, iconFor(ch.action), 'primary', ch.target, ch.detail, null, null);
            it.hasBefore = true;
            it.beforeValue = String.isBlank(ch.before) ? '(none)' : ch.before.left(200);
            it.afterValue = String.isBlank(ch.after) ? '(none)' : ch.after.left(200);
            it.subtitle = 'Before: ' + it.beforeValue + '   →   After: ' + it.afterValue + (String.isBlank(ch.detail) ? '' : '  · ' + ch.detail);
            itemBadge(it, ch.action, ch.action == 'Remove' ? 'error' : 'info');
        }
        more(c, changes.size(), shown > MAX_ITEMS ? MAX_ITEMS : shown, 'changes');
        String prod = CodeyCore.productionNote();
        if (prod != null) callout(c, 'Production org', prod, 'warning');
        note(c, (String.isBlank(summary) ? '' : summary + ' ') + 'Nothing is saved until you approve. Every change is logged.');
        if (String.isNotBlank(token)) {
            messageButton(c, 'Approve', 'primary', 'Approve – go ahead with "' + title + '" (preview token ' + token + ').');
            messageButton(c, 'Reject', 'secondary', 'Reject – do not make the change "' + title + '".');
        }
        return c;
    }

    // ================================================================= Health check report
    public static CodeyCard health(String title, String subtitle, List<HealthRow> rows) {
        CodeyCard c = start('health', title, subtitle, 'heart-pulse');
        Integer ok = 0, warn = 0, fix = 0;
        for (HealthRow r : rows) { if (r.status == 'OK') ok++; else if (r.status == 'Warning') warn++; else fix++; }
        stat(c, 'OK', String.valueOf(ok), null);
        stat(c, 'Warning', String.valueOf(warn), null);
        stat(c, 'Needs Fix', String.valueOf(fix), null);
        badge(c, fix > 0 ? 'Needs Fix' : (warn > 0 ? 'Warnings' : 'All OK'), fix > 0 ? 'error' : (warn > 0 ? 'warning' : 'success'));
        c.itemsTitle = fix + warn > 0 ? 'Items to look at' : 'All checks passed';
        // Needs Fix first, then Warning, then OK
        List<HealthRow> ordered = new List<HealthRow>();
        for (String s : new List<String>{ 'Needs Fix', 'Warning', 'OK' }) for (HealthRow r : rows) if (r.status == s) ordered.add(r);
        Integer shown = 0;
        for (HealthRow r : ordered) {
            if (r.status == 'OK' && fix + warn > 0) continue; // keep the card about what needs attention
            if (shown++ >= MAX_ITEMS) break;
            String sub = (String.isBlank(r.reason) ? '' : r.reason) +
                (r.status == 'OK' ? '' : '  Current: ' + nz(r.current, '(not set)') + (String.isBlank(r.recommended) ? '' : ' · Recommended: ' + r.recommended));
            CodeyCardItem it = item(c, r.status == 'OK' ? 'check' : (r.status == 'Warning' ? 'alert-triangle' : 'x-circle'),
                r.status == 'OK' ? 'success' : (r.status == 'Warning' ? 'warning' : 'error'), r.label, sub.trim(), r.area, null);
            itemBadge(it, r.status, r.status == 'OK' ? 'success' : (r.status == 'Warning' ? 'warning' : 'error'));
            if (String.isNotBlank(r.fixMessage)) { it.hasAction = true; it.actionLabel = 'Fix it'; it.actionMessage = r.fixMessage; }
            if (String.isNotBlank(r.helpUrl)) { it.hasLink = true; it.linkLabel = 'Help'; it.linkUrl = r.helpUrl; }
        }
        Integer attention = fix + warn;
        more(c, attention == 0 ? rows.size() : attention, shown > MAX_ITEMS ? MAX_ITEMS : shown, 'items');
        note(c, 'Read-only check. A fix changes nothing until you approve its preview.');
        if (fix + warn > 0) messageButton(c, 'Fix all fixable items', 'primary', 'Preview fixes for all fixable Needs Fix and Warning items from the health check.');
        messageButton(c, 'Run again', 'secondary', 'Run the ESM settings health check again.');
        return c;
    }

    // ================================================================= Progress tracker
    public static CodeyCard progress(String title, String subtitle, String status, Decimal percent, List<StepRow> steps, String jobId, String resumeHint, String resultsUrl) {
        CodeyCard c = start('progress', title, subtitle, 'activity');
        badge(c, status, status == 'Completed' ? 'success' : (status == 'Failed' ? 'error' : (status == 'Paused' ? 'warning' : 'info')));
        c.hasProgress = true;
        c.progressValue = percent == null ? 0 : percent.setScale(0);
        c.progressLabel = c.progressValue + '% done';
        c.progressColor = status == 'Failed' ? 'error' : (status == 'Completed' ? 'success' : 'primary');
        c.itemsTitle = 'Steps';
        Integer shown = 0;
        for (StepRow s : steps) {
            if (shown++ >= MAX_ITEMS) break;
            String col = s.status == 'Completed' ? 'success' : (s.status == 'Failed' ? 'error' : (s.status == 'Manual' ? 'warning' : 'primary'));
            CodeyCardItem it = item(c, s.status == 'Completed' ? 'check' : (s.status == 'Failed' ? 'x-circle' : (s.status == 'Manual' ? 'hand' : 'loader')), col, s.label, s.detail, null, null);
            itemBadge(it, s.status, col == 'primary' ? 'info' : col);
            if (s.percent != null) { it.hasBar = true; it.percent = s.percent.setScale(0); it.barColor = col == 'warning' ? 'primary' : col; }
        }
        more(c, steps.size(), shown > MAX_ITEMS ? MAX_ITEMS : shown, 'steps');
        if (status == 'Failed' && String.isNotBlank(resumeHint)) callout(c, 'Can resume', resumeHint, 'warning');
        if (String.isNotBlank(jobId)) {
            messageButton(c, 'Refresh', 'secondary', 'Show the progress of Codey job ' + jobId + '.');
            if (status == 'Failed' || status == 'Paused') messageButton(c, 'Resume', 'primary', 'Resume Codey job ' + jobId + ' from where it stopped.');
        }
        if (String.isNotBlank(resultsUrl)) linkButton(c, 'Results file', resultsUrl);
        return c;
    }

    // ================================================================= Upgrade impact report
    public static CodeyCard upgrade(String release, List<ImpactRow> rows, Integer checked) {
        CodeyCard c = start('upgrade', 'Upgrade impact – release ' + release, checked + ' customized screens checked', 'layers');
        Integer hi = 0, med = 0, lo = 0;
        for (ImpactRow r : rows) { if (r.risk == 'High') hi++; else if (r.risk == 'Medium') med++; else lo++; }
        stat(c, 'High', String.valueOf(hi), null);
        stat(c, 'Medium', String.valueOf(med), null);
        stat(c, 'Low', String.valueOf(lo), null);
        badge(c, hi > 0 ? 'Review before upgrading' : (med > 0 ? 'Some changes' : 'Low risk'), hi > 0 ? 'error' : (med > 0 ? 'warning' : 'success'));
        c.itemsTitle = 'Affected customized screens';
        Integer shown = 0;
        for (String level : new List<String>{ 'High', 'Medium', 'Low' }) {
            for (ImpactRow r : rows) {
                if (r.risk != level) continue;
                if (shown++ >= MAX_ITEMS) break;
                CodeyCardItem it = item(c, r.risk == 'High' ? 'alert-octagon' : (r.risk == 'Medium' ? 'alert-triangle' : 'info'),
                    r.risk == 'High' ? 'error' : (r.risk == 'Medium' ? 'warning' : 'primary'), r.screen, r.change, r.kind, r.action);
                itemBadge(it, r.risk, r.risk == 'High' ? 'error' : (r.risk == 'Medium' ? 'warning' : 'info'));
                it.hasAction = true; it.actionLabel = 'Suggest merged version';
                it.actionMessage = 'Suggest a combined version of the customized ' + r.kind + ' ' + r.screen + ' for release ' + release + ' for my review (do not deploy).';
            }
        }
        more(c, rows.size(), shown > MAX_ITEMS ? MAX_ITEMS : shown, 'screens');
        note(c, 'Report only: nothing is changed. A combined version is a suggestion for your review.');
        return c;
    }

    // ================================================================= basic / fallback
    public static CodeyCard basic(CodeyResult r, String title) {
        CodeyCard c = start('basic', title, null, r != null && r.success == false ? 'alert-circle' : 'info');
        if (r == null) return c;
        if (r.success == false) badge(c, 'Not done', 'error');
        note(c, r.message);
        if (String.isNotBlank(r.fix)) callout(c, 'How to fix', r.fix, 'warning');
        if (String.isNotBlank(r.nextStep)) callout(c, 'Next step', r.nextStep, 'info');
        return c;
    }

    // ================================================================= parts
    public static CodeyCard start(String type, String title, String subtitle, String icon) {
        CodeyCard c = new CodeyCard();
        c.cardType = type; c.title = title; c.subtitle = nz(subtitle, ' '); c.icon = icon;
        return c;
    }
    public static void badge(CodeyCard c, String label, String variant) { c.hasBadge = true; c.badgeLabel = label; c.badgeVariant = variant; }
    public static void stat(CodeyCard c, String label, String value, String detail) {
        CodeyCardStat s = new CodeyCardStat(); s.label = label; s.value = nz(value, '0'); s.detail = nz(detail, ' ');
        c.stats.add(s); c.hasStats = true;
    }
    public static CodeyCardItem item(CodeyCard c, String icon, String color, String title, String subtitle, String value, String detail) {
        CodeyCardItem it = new CodeyCardItem();
        it.icon = icon; it.iconColor = color; it.title = nz(title, ' ').left(120); it.subtitle = nz(subtitle, ' ').left(400);
        it.value = nz(value, ' '); it.detail = nz(detail, ' ').left(300);
        c.items.add(it); c.hasItems = true;
        return it;
    }
    public static void itemBadge(CodeyCardItem it, String label, String variant) { it.hasBadge = true; it.badgeLabel = label; it.badgeVariant = variant; }
    public static void callout(CodeyCard c, String title, String text, String variant) {
        if (String.isBlank(text)) return;
        c.hasCallout = true; c.calloutTitle = title; c.calloutText = text.left(600); c.calloutVariant = variant;
    }
    public static void note(CodeyCard c, String text) { if (String.isNotBlank(text)) { c.hasNote = true; c.note = text.left(800); } }
    public static void more(CodeyCard c, Integer total, Integer shown, String noun) {
        if (total > shown) { c.hasMore = true; c.moreLabel = (total - shown) + ' more ' + noun + ' in the details'; }
    }
    public static void messageButton(CodeyCard c, String label, String variant, String message) {
        CodeyCardButton b = new CodeyCardButton(); b.label = label; b.variant = variant; b.isMessage = true; b.message = message;
        c.buttons.add(b); c.hasButtons = true;
    }
    public static void linkButton(CodeyCard c, String label, String url) {
        CodeyCardButton b = new CodeyCardButton(); b.label = label; b.variant = 'secondary'; b.isLink = true; b.url = url;
        c.buttons.add(b); c.hasButtons = true;
    }
    static String iconFor(String action) {
        if (action == 'Assign') return 'user-plus';
        if (action == 'Create') return 'plus-circle';
        if (action == 'Load') return 'upload';
        if (action == 'Start') return 'play';
        if (action == 'Remove') return 'trash';
        return 'edit';
    }
    public static String nz(String s, String dflt) { return String.isBlank(s) ? dflt : s; }
    public static String recordUrl(Id recordId) { return recordId == null ? null : URL.getOrgDomainUrl().toExternalForm() + '/' + recordId; }
}
