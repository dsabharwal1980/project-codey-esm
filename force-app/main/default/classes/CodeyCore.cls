/**
 * Project Codey shared helpers: preview tokens and the approval gate, the change log (audit + undo),
 * production guard, quote lookup, CPQ settings, secret masking and plain-language fixes.
 *
 * Approval gate: a preview stores a Codey_Change_Log__c (Status Previewed) with a token = hash of tool + user + the inputs.
 * A commit must send the same token AND the same inputs (re-hashed), by the same user, within 30 minutes.
 * Nothing is written unless that matches, so nothing is ever saved without a preview the person saw and approved.
 */
public with sharing class CodeyCore {

    public class ToolException extends Exception {}

    public static final Integer PREVIEW_MINUTES = 30;
    static final Set<String> NOT_HASHED = new Set<String>{ 'mode', 'previewtoken', 'confirmproduction', 'surface', 'jobid' };

    // ------------------------------------------------------------------ org
    @TestVisible static Boolean sandboxOverride;
    static Boolean sandboxCache;

    public static Boolean isSandbox() {
        if (sandboxOverride != null) return sandboxOverride;
        if (sandboxCache == null) sandboxCache = [SELECT IsSandbox FROM Organization LIMIT 1].IsSandbox;
        return sandboxCache;
    }

    /** Production changes need an explicit extra confirmation (PRD: sandbox by default, production always approved). */
    public static void guardProduction(Boolean confirmProduction) {
        if (!isSandbox() && confirmProduction != true) {
            throw new ToolException('This is a PRODUCTION org. Tell the person, and only if they confirm they want the change in production, call again with confirmProduction = true (same inputs and preview token).');
        }
    }

    public static String productionNote() {
        return isSandbox() ? null : 'This is a production org: the change needs your explicit confirmation for production.';
    }

    // ------------------------------------------------------------------ approval gate
    public static String token(String tool, Map<String, Object> inputs) {
        List<String> keys = new List<String>();
        Map<String, String> norm = new Map<String, String>();
        if (inputs != null) {
            for (String k : inputs.keySet()) {
                String lk = k.toLowerCase();
                if (NOT_HASHED.contains(lk)) continue;
                Object v = inputs.get(k);
                String s = v == null ? '' : (v instanceof String ? (String) v : JSON.serialize(v));
                s = s.trim();
                if (String.isBlank(s)) continue;
                keys.add(lk);
                norm.put(lk, s);
            }
        }
        keys.sort();
        String raw = tool + '|' + UserInfo.getUserId();
        for (String k : keys) raw += '|' + k + '=' + norm.get(k);
        return EncodingUtil.convertToHex(Crypto.generateDigest('SHA-256', Blob.valueOf(raw))).left(40);
    }

    /** Records a preview and returns the log (its Preview_Token__c is what the person approves). */
    public static Codey_Change_Log__c logPreview(String tool, String changeType, String target, Object before, Object after, Map<String, Object> inputs) {
        Codey_Change_Log__c l = new Codey_Change_Log__c(
            Tool__c = tool, Change_Type__c = changeType, Target__c = String.isBlank(target) ? null : target.left(255),
            Status__c = 'Previewed', Preview_Token__c = token(tool, inputs),
            Input_JSON__c = clip(JSON.serialize(scrub(inputs), true)),
            Before_JSON__c = before == null ? null : clip(before instanceof String ? (String) before : JSON.serialize(before, true)),
            After_JSON__c = after == null ? null : clip(after instanceof String ? (String) after : JSON.serialize(after, true)),
            Expires_At__c = System.now().addMinutes(PREVIEW_MINUTES), Is_Production__c = !isSandbox(),
            Surface__c = surface(inputs));
        insert l; // audit records are always written (system mode) so every action is logged
        return l;
    }

    /** Checks the approval: same user, same inputs, previewed and not expired. Returns the preview log to commit against. */
    public static Codey_Change_Log__c requireApproval(String tool, Map<String, Object> inputs, String previewToken) {
        if (String.isBlank(previewToken)) {
            throw new ToolException('No preview token. Run mode=preview first, show the person the Approval card, and commit only after they approve.');
        }
        String expected = token(tool, inputs);
        if (expected != previewToken.trim()) {
            throw new ToolException('The inputs are not the same as in the preview. Run mode=preview again with the new inputs and ask the person to approve that preview.');
        }
        List<Codey_Change_Log__c> logs = [
            SELECT Id, Name, Status__c, Expires_At__c, Tool__c, Change_Type__c, Target__c, Before_JSON__c, After_JSON__c, Input_JSON__c, Record_Ids__c
            FROM Codey_Change_Log__c
            WHERE Preview_Token__c = :expected AND CreatedById = :UserInfo.getUserId() AND Tool__c = :tool
            ORDER BY CreatedDate DESC LIMIT 5];
        for (Codey_Change_Log__c l : logs) {
            if (l.Status__c == 'Committed') throw new ToolException('Already done: this preview was committed (' + l.Name + '). Nothing was changed again.');
            if (l.Status__c == 'Previewed') {
                if (l.Expires_At__c < System.now()) {
                    l.Status__c = 'Expired';
                    update l;
                    throw new ToolException('The preview expired (older than ' + PREVIEW_MINUTES + ' minutes). Run mode=preview again and ask the person to approve.');
                }
                return l;
            }
        }
        throw new ToolException('No open preview found for this token. Run mode=preview first.');
    }

    public static void markCommitted(Codey_Change_Log__c l, Object after, List<Id> recordIds) {
        l.Status__c = 'Committed';
        l.Committed_At__c = System.now();
        l.Approved_By__c = UserInfo.getUserId();
        if (after != null) l.After_JSON__c = clip(after instanceof String ? (String) after : JSON.serialize(after, true));
        if (recordIds != null && !recordIds.isEmpty()) l.Record_Ids__c = clip(String.join(recordIds, ','));
        update l;
    }

    public static void markFailed(Codey_Change_Log__c l, String error) {
        if (l == null) return;
        l.Status__c = 'Failed';
        l.Error__c = clip(error);
        update l;
    }

    public static Codey_Change_Log__c logRead(String tool, String target, Map<String, Object> inputs) {
        // usage tracking for read-only skill runs (PRD: track skill runs, approvals, results and errors)
        Codey_Change_Log__c l = new Codey_Change_Log__c(Tool__c = tool, Change_Type__c = 'read', Target__c = target == null ? null : target.left(255),
            Status__c = 'Committed', Committed_At__c = System.now(), Input_JSON__c = clip(JSON.serialize(scrub(inputs), true)),
            Is_Production__c = !isSandbox(), Surface__c = surface(inputs));
        insert l;
        return l;
    }

    static String surface(Map<String, Object> inputs) {
        Object s = inputs == null ? null : inputs.get('surface');
        if (s != null && String.isNotBlank(String.valueOf(s))) return String.valueOf(s).left(80);
        String c = Request.getCurrent() == null ? null : String.valueOf(Request.getCurrent().getQuiddity());
        return c == null ? null : c.left(80);
    }

    static Map<String, Object> scrub(Map<String, Object> inputs) {
        Map<String, Object> out = new Map<String, Object>();
        if (inputs == null) return out;
        for (String k : inputs.keySet()) out.put(k, isSecretName(k) ? (Object) '****' : inputs.get(k));
        return out;
    }

    public static String clip(String s) { return s == null ? null : s.left(131000); }

    // ------------------------------------------------------------------ secrets
    public static Boolean isSecretName(String name) {
        if (name == null) return false;
        String n = name.toLowerCase();
        return n.contains('password') || n.contains('secret') || n.contains('token') || n.contains('apikey') || n.contains('api key')
            || n.contains('pvtkey') || n.contains('privatekey') || n.endsWith('key') && !n.endsWith('globalkey') && !n.contains('partitionkey');
    }

    public static String mask(String name, String value, Boolean secretFlag) {
        if (secretFlag == true || isSecretName(name)) return String.isBlank(value) || value == 'None' ? '(not set)' : '•••• (set)';
        return value;
    }

    // ------------------------------------------------------------------ CPQ settings
    static Map<String, vlocity_cmt__CpqConfigurationSetup__c> cpqCache;

    public static Map<String, vlocity_cmt__CpqConfigurationSetup__c> cpqSettings() {
        if (cpqCache == null) {
            cpqCache = new Map<String, vlocity_cmt__CpqConfigurationSetup__c>();
            for (vlocity_cmt__CpqConfigurationSetup__c s : [SELECT Id, Name, vlocity_cmt__SetupValue__c, vlocity_cmt__Description__c FROM vlocity_cmt__CpqConfigurationSetup__c LIMIT 2000]) {
                cpqCache.put(s.Name.toLowerCase(), s);
            }
        }
        return cpqCache;
    }

    public static String cpqValue(String name) {
        vlocity_cmt__CpqConfigurationSetup__c s = cpqSettings().get(name == null ? '' : name.toLowerCase());
        return s == null ? null : s.vlocity_cmt__SetupValue__c;
    }

    public static void resetCaches() { cpqCache = null; }

    // ------------------------------------------------------------------ records
    public static Quote findQuote(String idOrName) {
        if (String.isBlank(idOrName)) throw new ToolException('Which quote? Give the quote Id (0Q0...) or its name.');
        String v = idOrName.trim();
        List<Quote> qs;
        if (v.startsWith('0Q0') && (v.length() == 15 || v.length() == 18)) {
            qs = [SELECT Id, Name, AccountId, Account.Name, OpportunityId, Status, RecordType.DeveloperName, CreatedDate FROM Quote WHERE Id = :v LIMIT 1];
        } else {
            String likeV = '%' + v.replace('%', '').replace('_', '\\_') + '%';
            qs = [SELECT Id, Name, AccountId, Account.Name, OpportunityId, Status, RecordType.DeveloperName, CreatedDate FROM Quote
                  WHERE Name = :v OR Name LIKE :likeV ORDER BY CreatedDate DESC LIMIT 6];
            List<Quote> exact = new List<Quote>();
            for (Quote q : qs) if (q.Name.equalsIgnoreCase(v)) exact.add(q);
            if (!exact.isEmpty()) qs = exact;
            if (qs.size() > 1) {
                List<String> names = new List<String>();
                for (Quote q : qs) names.add(q.Name + ' (' + q.Id + ')');
                throw new ToolException('Several quotes match "' + v + '": ' + String.join(names, '; ') + '. Which one?');
            }
        }
        if (qs.isEmpty()) throw new ToolException('No quote found for "' + v + '".');
        return qs[0];
    }

    public static List<String> splitList(String s) {
        List<String> out = new List<String>();
        if (String.isBlank(s)) return out;
        for (String p : s.split('[,;\\n]')) if (String.isNotBlank(p)) out.add(p.trim());
        return out;
    }

    public static String staticText(String resourceName) {
        List<StaticResource> rs = [SELECT Body FROM StaticResource WHERE Name = :resourceName LIMIT 1];
        if (rs.isEmpty()) throw new ToolException('Static resource ' + resourceName + ' is missing. Deploy the Codey knowledge packs.');
        return rs[0].Body.toString();
    }

    /** Splits a "## key" document into sections (key -> text including the heading). */
    public static Map<String, String> sections(String text) {
        Map<String, String> out = new Map<String, String>();
        if (text == null) return out;
        for (String part : ('\n' + text).split('\n## ')) {
            if (String.isBlank(part)) continue;
            Integer nl = part.indexOf('\n');
            String key = (nl < 0 ? part : part.substring(0, nl)).trim().toLowerCase();
            out.put(key, '## ' + part.trim());
        }
        return out;
    }

    public static String money(Decimal d) {
        if (d == null) return '0.00';
        return d.setScale(2).format();
    }

    // ------------------------------------------------------------------ plain-language fixes
    public static String suggestFix(String message) {
        String m = message == null ? '' : message.toLowerCase();
        if (m.contains('insufficient_access') || m.contains('insufficient access') || m.contains('no access') || m.contains('permission'))
            return 'The person asking is missing access. Use the permissions skill (manage_esm_permissions) or ask an admin to assign the Codey / ESM permission sets.';
        if (m.contains('expired') || m.contains('preview')) return 'Run the same request with mode=preview again, show the Approval card and commit after approval.';
        if (m.contains('production')) return 'Confirm with the person that the change should happen in production, then repeat with confirmProduction = true.';
        if (m.contains('unable_to_lock_row') || m.contains('lock')) return 'Another job is updating the same records. Wait a minute and try again.';
        if (m.contains('too many') || m.contains('limit')) return 'A platform limit was hit. Use a smaller batch size or let the background job continue.';
        if (m.contains('field_custom_validation') || m.contains('validation')) return 'A validation rule rejected the change; read the rule message and adjust the value.';
        if (m.contains('already running') || m.contains('blocked')) return 'A job is already running for this. Track it with track_codey_job; do not start another.';
        if (m.contains('no quote') || m.contains('which quote') || m.contains('several quotes')) return 'Give the exact quote Id (0Q0...) or the full quote name.';
        return 'Check the message above; if it repeats, stop and hand over with the change log id (escalation in the playbook).';
    }
}
