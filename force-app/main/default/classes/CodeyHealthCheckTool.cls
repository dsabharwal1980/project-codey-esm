/**
 * Codey tool check_esm_setup (read-only) - Settings health check and Fresh-install prerequisites.
 * Reads the installed packages, quoting settings, add-assets-to-quote settings, performance settings, Console,
 * permissions and admin job history, compares them with the Recommended settings pack (Codey_Recommended_Setting__mdt)
 * and returns OK / Warning / Needs Fix with the reason, a help link and a fix (as a Health check report card).
 * Nothing is changed. Designed to return well within two minutes (a handful of aggregate queries).
 */
public with sharing class CodeyHealthCheckTool {

    public static final String TOOL = 'check_esm_setup';
    static final Map<String, String> SCOPES = new Map<String, String>{
        'prereq' => 'Prereq', 'quoting' => 'Quoting', 'assets' => 'AddAssets', 'addassets' => 'AddAssets', 'performance' => 'Performance',
        'console' => 'Console', 'permissions' => 'Permissions', 'adminjobs' => 'AdminJobs', 'jobs' => 'AdminJobs' };

    public class Request {
        @InvocableVariable(label='Scope' description='all (default), prereq, quoting, assets, performance, console, permissions or adminjobs. Comma-separate several.')
        public String scope;
        @InvocableVariable(label='Surface' description='Optional: where the request comes from.')
        public String surface;
    }

    @InvocableMethod(label='check_esm_setup' description='Read-only ESM settings health check: compares quoting, add-assets-to-quote, performance, Console, permission and admin-job settings (and install prerequisites) with the recommended settings pack. Returns OK / Warning / Needs Fix per item with reason, help link and fix. Changes nothing.')
    public static List<CodeyResult> run(List<Request> requests) {
        List<CodeyResult> out = new List<CodeyResult>();
        for (Request r : requests) out.add(handle(r));
        return out;
    }

    public static CodeyResult handle(Request r) {
        try {
            Set<String> areas = areas(r.scope);
            List<Codey_Recommended_Setting__mdt> rules = new List<Codey_Recommended_Setting__mdt>();
            for (Codey_Recommended_Setting__mdt s : [SELECT DeveloperName, MasterLabel, Area__c, Source__c, Target__c, Operator__c, Recommended__c, Severity__c,
                                                     Label__c, Reason__c, Help_Url__c, Fixable__c, Secret__c
                                                     FROM Codey_Recommended_Setting__mdt WHERE Active__c = true ORDER BY Area__c, DeveloperName]) {
                if (areas.isEmpty() || areas.contains(s.Area__c)) rules.add(s);
            }
            Context ctx = new Context(rules);
            List<CodeyCards.HealthRow> rows = new List<CodeyCards.HealthRow>();
            List<Map<String, Object>> items = new List<Map<String, Object>>();
            for (Codey_Recommended_Setting__mdt s : rules) {
                CodeyCards.HealthRow h = evaluate(s, ctx);
                rows.add(h);
                items.add(new Map<String, Object>{ 'key' => s.MasterLabel, 'area' => h.area, 'label' => h.label, 'status' => h.status, 'current' => h.current,
                    'recommended' => h.recommended, 'reason' => h.reason, 'helpUrl' => h.helpUrl, 'fix' => h.fixMessage });
            }
            Integer ok = 0, warn = 0, fix = 0;
            for (CodeyCards.HealthRow h : rows) { if (h.status == 'OK') ok++; else if (h.status == 'Warning') warn++; else fix++; }
            String subtitle = ctx.versionLine() + ' · ' + (CodeyCore.isSandbox() ? 'Sandbox' : 'Production org') + ' · scope ' + (areas.isEmpty() ? 'all' : String.join(new List<String>(areas), ', '));
            String msg = 'ESM health check: ' + ok + ' OK, ' + warn + ' Warning, ' + fix + ' Needs Fix.' + (fix + warn == 0 ? ' Everything matches the recommended settings.' : '');
            Map<String, Object> details = new Map<String, Object>{ 'summary' => new Map<String, Object>{ 'ok' => ok, 'warning' => warn, 'needsFix' => fix },
                'installed' => ctx.versionLine(), 'isSandbox' => CodeyCore.isSandbox(), 'items' => items };
            CodeyResult res = CodeyResult.ok('read', msg, details);
            res.card = CodeyCards.health('ESM settings health check', subtitle, rows);
            res.nextStep = fix + warn == 0 ? 'No action needed.' : 'Offer the fixes: each Fix it starts a preview (apply_esm_change / manage_esm_permissions / run_esm_admin_jobs) that the person must approve.';
            res.changeLogId = CodeyCore.logRead(TOOL, 'scope ' + (String.isBlank(r.scope) ? 'all' : r.scope), new Map<String, Object>{ 'scope' => r.scope, 'surface' => r.surface, 'result' => msg }).Id;
            return res;
        } catch (Exception e) {
            return CodeyResult.fail('read', e);
        }
    }

    static Set<String> areas(String scope) {
        Set<String> out = new Set<String>();
        for (String p : CodeyCore.splitList(scope)) {
            String k = p.toLowerCase().replace(' ', '');
            if (k == 'all') return new Set<String>();
            if (!SCOPES.containsKey(k)) throw new CodeyCore.ToolException('Unknown scope "' + p + '". Use all, prereq, quoting, assets, performance, console, permissions or adminjobs.');
            out.add(SCOPES.get(k));
        }
        return out;
    }

    /** Reads everything the rules need with as few queries as possible. */
    public class Context {
        public Set<String> namespaces = new Set<String>();
        public Map<String, String> licenceStatus = new Map<String, String>();
        public Set<String> recordTypes = new Set<String>();
        public Set<String> permissionSets = new Set<String>();
        public Set<String> apps = new Set<String>();
        public Map<String, Datetime> lastJobRun = new Map<String, Datetime>();
        public Map<String, String> general = new Map<String, String>();

        public Context(List<Codey_Recommended_Setting__mdt> rules) {
            Set<String> psNames = new Set<String>(), appNames = new Set<String>(), jobClasses = new Set<String>(), rts = new Set<String>(), gs = new Set<String>();
            Boolean needPkg = false;
            for (Codey_Recommended_Setting__mdt s : rules) {
                if (s.Source__c == 'PermissionSet') psNames.add(s.Target__c.contains('.') ? s.Target__c.substringAfter('.') : s.Target__c);
                else if (s.Source__c == 'App') appNames.add(s.Target__c);
                else if (s.Source__c == 'AdminJob') jobClasses.add(s.Target__c);
                else if (s.Source__c == 'RecordType') rts.add(s.Target__c.substringAfter('.'));
                else if (s.Source__c == 'GeneralSettings') gs.add(s.Target__c);
                else if (s.Source__c == 'Package') needPkg = true;
            }
            if (needPkg) {
                for (PackageLicense pl : [SELECT NamespacePrefix, Status FROM PackageLicense]) {
                    namespaces.add(pl.NamespacePrefix);
                    licenceStatus.put(pl.NamespacePrefix, pl.Status);
                }
                // packages without a licence record (free / org-wide) - detect by their classes
                for (AggregateResult ar : [SELECT NamespacePrefix ns FROM ApexClass WHERE NamespacePrefix IN ('vlocity_cmt', 'omnistudio') GROUP BY NamespacePrefix]) {
                    namespaces.add((String) ar.get('ns'));
                }
            }
            if (!rts.isEmpty()) for (RecordType rt : [SELECT SobjectType, DeveloperName FROM RecordType WHERE DeveloperName IN :rts AND IsActive = true]) recordTypes.add(rt.SobjectType + '.' + rt.DeveloperName);
            if (!psNames.isEmpty()) for (PermissionSet p : [SELECT Name, NamespacePrefix FROM PermissionSet WHERE Name IN :psNames]) permissionSets.add((p.NamespacePrefix == null ? '' : p.NamespacePrefix + '.') + p.Name);
            if (!appNames.isEmpty()) for (AppMenuItem a : [SELECT Name FROM AppMenuItem WHERE Name IN :appNames]) apps.add(a.Name);
            if (!jobClasses.isEmpty()) {
                for (AggregateResult ar : [SELECT ApexClass.Name n, MAX(CompletedDate) d FROM AsyncApexJob WHERE ApexClass.Name IN :jobClasses AND Status = 'Completed' GROUP BY ApexClass.Name]) {
                    lastJobRun.put((String) ar.get('n'), (Datetime) ar.get('d'));
                }
            }
            if (!gs.isEmpty()) for (vlocity_cmt__GeneralSettings__c g : [SELECT Name, vlocity_cmt__Value__c FROM vlocity_cmt__GeneralSettings__c WHERE Name IN :gs]) general.put(g.Name.toLowerCase(), g.vlocity_cmt__Value__c);
        }

        public String versionLine() {
            String cmt = licenceStatus.containsKey('vlocity_cmt') ? 'Communications Cloud licence ' + licenceStatus.get('vlocity_cmt') : (namespaces.contains('vlocity_cmt') ? 'Communications Cloud installed' : 'Communications Cloud: not checked');
            return cmt + ' · ' + CodeyCore.cpqSettings().size() + ' CPQ settings read';
        }
    }

    public static CodeyCards.HealthRow evaluate(Codey_Recommended_Setting__mdt s, Context ctx) {
        CodeyCards.HealthRow h = new CodeyCards.HealthRow();
        h.area = s.Area__c; h.label = s.Label__c; h.reason = s.Reason__c; h.helpUrl = s.Help_Url__c;
        h.recommended = s.Recommended__c;
        Boolean pass;
        String current;
        try {
            if (s.Source__c == 'CpqConfigurationSetup') {
                current = CodeyCore.cpqValue(s.Target__c);
                pass = compare(s.Operator__c, current, s.Recommended__c, CodeyCore.cpqSettings().containsKey(s.Target__c.toLowerCase()));
                current = CodeyCore.mask(s.Target__c, current, s.Secret__c);
            } else if (s.Source__c == 'GeneralSettings') {
                current = ctx.general.get(s.Target__c.toLowerCase());
                pass = compare(s.Operator__c, current, s.Recommended__c, ctx.general.containsKey(s.Target__c.toLowerCase()));
            } else if (s.Source__c == 'Package') {
                Boolean has = ctx.namespaces.contains(s.Target__c);
                current = has ? 'installed' + (ctx.licenceStatus.containsKey(s.Target__c) ? ' (licence ' + ctx.licenceStatus.get(s.Target__c) + ')' : '') : 'not installed';
                pass = has && (!ctx.licenceStatus.containsKey(s.Target__c) || ctx.licenceStatus.get(s.Target__c) == 'Active');
            } else if (s.Source__c == 'RecordType') {
                pass = ctx.recordTypes.contains(s.Target__c);
                current = pass ? 'exists' : 'missing';
            } else if (s.Source__c == 'PermissionSet') {
                pass = ctx.permissionSets.contains(s.Target__c);
                current = pass ? 'exists' : 'missing';
            } else if (s.Source__c == 'App') {
                pass = ctx.apps.contains(s.Target__c);
                current = pass ? 'exists' : 'missing';
            } else if (s.Source__c == 'Query') {
                Integer n = Database.countQuery(s.Target__c);
                current = String.valueOf(n);
                pass = compare(s.Operator__c, current, s.Recommended__c, true);
            } else if (s.Source__c == 'AdminJob') {
                Datetime last = ctx.lastJobRun.get(s.Target__c);
                current = last == null ? 'no completed run found' : 'last run ' + last.format('yyyy-MM-dd');
                Integer days = String.isBlank(s.Recommended__c) ? 30 : Integer.valueOf(s.Recommended__c);
                pass = last != null && last >= System.now().addDays(-days);
                h.recommended = 'within ' + days + ' days';
            } else if (s.Source__c == 'Manual') {
                pass = null;
                current = 'check by hand';
            } else {
                pass = null; current = 'unknown source ' + s.Source__c;
            }
        } catch (Exception e) {
            pass = false;
            current = 'could not read: ' + e.getMessage().left(120);
        }
        h.current = current;
        h.status = pass == true ? 'OK' : (pass == null || s.Severity__c == 'Warning' ? 'Warning' : 'Needs Fix');
        if (h.status != 'OK') h.fixMessage = fixMessage(s);
        return h;
    }

    public static Boolean compare(String op, String current, String recommended, Boolean exists) {
        String cur = current == null ? '' : current.trim();
        String o = op == null ? 'equals' : op;
        if (o == 'exists') return exists;
        if (o == 'notBlank') return String.isNotBlank(cur) && cur != 'None';
        if (o == 'equals') return cur.equalsIgnoreCase(recommended == null ? '' : recommended.trim());
        if (o == 'gte' || o == 'lte' || o == 'between') {
            if (!cur.isNumeric() && !isDecimal(cur)) return false;
            Decimal v = Decimal.valueOf(cur);
            if (o == 'gte') return v >= Decimal.valueOf(recommended);
            if (o == 'lte') return v <= Decimal.valueOf(recommended);
            List<String> b = recommended.split('\\.\\.');
            return v >= Decimal.valueOf(b[0]) && v <= Decimal.valueOf(b[1]);
        }
        return false;
    }

    static Boolean isDecimal(String s) { try { Decimal.valueOf(s); return true; } catch (Exception e) { return false; } }

    /** The message a "Fix it" button sends back to the agent; the agent then runs a preview the person approves. */
    public static String fixMessage(Codey_Recommended_Setting__mdt s) {
        if (s.Secret__c) return 'Open App Launcher → Codey Setup and enter the ' + s.Label__c + ' in the secure form (never in chat).';
        if (s.Source__c == 'CpqConfigurationSetup' && s.Fixable__c) {
            String value = s.Recommended__c;
            if (s.Operator__c == 'between' && value != null && value.contains('..')) value = value.split('\\.\\.')[1];
            if (String.isBlank(value)) return 'Set the CPQ setting ' + s.Target__c + ' (ask the person for the value), with a preview first.';
            return 'Fix it: preview apply_esm_change changeType=cpqSetting target=' + s.Target__c + ' value=' + value + ' and ask me to approve.';
        }
        if (s.Area__c == 'Permissions') return 'Fix it: use manage_esm_permissions (preview first) or deploy the missing permission set ' + s.Target__c + '.';
        if (s.Area__c == 'AdminJobs') return 'Fix it: preview run_esm_admin_jobs jobs=default and ask me to approve.';
        if (s.Source__c == 'Manual') return 'Check by hand in Setup: ' + s.Label__c + ' (see Help).';
        if (s.Area__c == 'Prereq') return 'Prerequisite: ' + s.Label__c + ' – see Help; licences and packages are installed by an admin.';
        return 'See Help for ' + s.Label__c + '.';
    }
}
