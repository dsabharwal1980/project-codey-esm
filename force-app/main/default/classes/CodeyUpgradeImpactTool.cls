/**
 * Codey tool check_esm_upgrade_impact (read-only) - Upgrade check skill.
 * Lists the org's ESM/CPQ screens and procedures (FlexCards, legacy cards, OmniScripts, Integration Procedures) that match the
 * Release change list (Codey_Release_Change_List), works out whether each one is customized (new versions, other authors,
 * later edits) and rates the impact: High / Medium / Low with a suggested action. Report only - nothing is changed.
 */
public with sharing class CodeyUpgradeImpactTool {

    public static final String TOOL = 'check_esm_upgrade_impact';
    static final Set<String> STANDARD_AUTHORS = new Set<String>{ 'vlocity', 'salesforce', 'industries', 'vlocity_cmt', 'communications' };

    public class Request {
        @InvocableVariable(label='Target Release' description='Release to check, e.g. 268 (default: the newest release in the release change list).')
        public String targetRelease;
        @InvocableVariable(label='Include Standard' description='true: also list matching components that are not customized (Low risk, take the new version).')
        public Boolean includeStandard;
        @InvocableVariable(label='Surface' description='Optional: where the request comes from.')
        public String surface;
    }

    @InvocableMethod(label='check_esm_upgrade_impact' description='Read-only upgrade check: which customized ESM screens and procedures (FlexCards, OmniScripts, Integration Procedures) a release affects, what changed, a risk level (High/Medium/Low) and a suggested action. Nothing is changed.')
    public static List<CodeyResult> run(List<Request> requests) {
        List<CodeyResult> out = new List<CodeyResult>();
        for (Request r : requests) out.add(handle(r));
        return out;
    }

    public class Component {
        public String name; public String kind; public Integer version; public Boolean customized; public String why; public String key;
    }

    public static CodeyResult handle(Request r) {
        try {
            Map<String, Object> pack = (Map<String, Object>) JSON.deserializeUntyped(CodeyCore.staticText('Codey_Release_Change_List'));
            Map<String, Object> rel = pickRelease((List<Object>) pack.get('releases'), r.targetRelease);
            String release = String.valueOf(rel.get('release'));
            List<Component> comps = components();
            List<CodeyCards.ImpactRow> rows = new List<CodeyCards.ImpactRow>();
            List<Map<String, Object>> items = new List<Map<String, Object>>();
            Integer customizedCount = 0;
            for (Component c : comps) if (c.customized) customizedCount++;
            for (Object o : (List<Object>) rel.get('components')) {
                Map<String, Object> ch = (Map<String, Object>) o;
                String pattern = String.valueOf(ch.get('pattern'));
                String kind = String.valueOf(ch.get('kind'));
                for (Component c : comps) {
                    if (!kindMatches(kind, c.kind) || !matches(pattern, c.key)) continue;
                    if (!c.customized && r.includeStandard != true) continue;
                    CodeyCards.ImpactRow row = new CodeyCards.ImpactRow();
                    row.screen = c.name + (c.version == null ? '' : ' v' + c.version);
                    row.kind = c.kind;
                    row.change = String.valueOf(ch.get('change')) + (c.customized ? ' · customized: ' + c.why : ' · standard copy');
                    row.risk = c.customized ? String.valueOf(ch.get('risk')) : 'Low';
                    row.action = c.customized ? String.valueOf(ch.get('advice')) : 'Not customized: take the new standard version.';
                    rows.add(row);
                    items.add(new Map<String, Object>{ 'component' => c.name, 'kind' => c.kind, 'version' => c.version, 'customized' => c.customized, 'why' => c.why,
                        'change' => ch.get('change'), 'risk' => row.risk, 'action' => row.action, 'pattern' => pattern });
                }
            }
            Integer hi = 0, med = 0;
            for (CodeyCards.ImpactRow x : rows) { if (x.risk == 'High') hi++; else if (x.risk == 'Medium') med++; }
            String status = String.valueOf(pack.get('status'));
            String msg = 'Release ' + release + ': ' + rows.size() + ' affected screens/procedures (' + hi + ' High, ' + med + ' Medium) out of ' + customizedCount + ' customized ESM/CPQ components checked.'
                + (status != null && status.startsWith('SEED') ? ' Note: the release change list is a seed/sample until the official list for this release is loaded.' : '');
            CodeyResult res = CodeyResult.ok('read', msg, new Map<String, Object>{ 'release' => release, 'listStatus' => status, 'affected' => items, 'customizedChecked' => customizedCount, 'componentsScanned' => comps.size() });
            res.card = CodeyCards.upgrade(release, rows, customizedCount);
            if (status != null && status.startsWith('SEED')) CodeyCards.callout(res.card, 'Release list', 'Sample entries – load the official release change list before relying on this report.', 'warning');
            res.nextStep = rows.isEmpty() ? 'No customized screen is affected by this release list.' : 'Start with High items. On request, suggest a combined version for one screen for review (never deploy it without approval).';
            res.changeLogId = CodeyCore.logRead(TOOL, 'release ' + release, new Map<String, Object>{ 'targetRelease' => release, 'surface' => r.surface }).Id;
            return res;
        } catch (Exception e) {
            return CodeyResult.fail('read', e);
        }
    }

    static Map<String, Object> pickRelease(List<Object> releases, String target) {
        Map<String, Object> best;
        for (Object o : releases) {
            Map<String, Object> rel = (Map<String, Object>) o;
            String v = String.valueOf(rel.get('release'));
            if (String.isNotBlank(target) && v == target.trim()) return rel;
            if (best == null || (v.isNumeric() && String.valueOf(best.get('release')).isNumeric() && Integer.valueOf(v) > Integer.valueOf(String.valueOf(best.get('release'))))) best = rel;
        }
        if (String.isNotBlank(target)) throw new CodeyCore.ToolException('Release ' + target + ' is not in the release change list yet. Available: ' + releaseNames(releases) + '.');
        if (best == null) throw new CodeyCore.ToolException('The release change list is empty.');
        return best;
    }

    static String releaseNames(List<Object> releases) {
        List<String> n = new List<String>();
        for (Object o : releases) n.add(String.valueOf(((Map<String, Object>) o).get('release')));
        return String.join(n, ', ');
    }

    /** Active ESM/CPQ-related components with a customization signal. */
    @TestVisible static List<Component> testComponents;

    public static List<Component> components() {
        if (testComponents != null) return testComponents;
        List<Component> out = new List<Component>();
        for (OmniUiCard c : [SELECT Name, VersionNumber, AuthorName, CreatedDate, LastModifiedDate FROM OmniUiCard WHERE IsActive = true
                             AND (Name LIKE 'cpq%' OR Name LIKE 'ESM%' OR Name LIKE 'multi%' OR Name LIKE 'b2b%' OR Name LIKE 'cfCpq%' OR Name LIKE 'cfESM%') LIMIT 2000]) {
            out.add(comp(c.Name, 'FlexCard', c.VersionNumber == null ? null : c.VersionNumber.intValue(), c.AuthorName, c.CreatedDate, c.LastModifiedDate, c.Name));
        }
        for (vlocity_cmt__VlocityCard__c c : [SELECT Name, vlocity_cmt__Version__c, vlocity_cmt__Author__c, CreatedDate, LastModifiedDate FROM vlocity_cmt__VlocityCard__c WHERE vlocity_cmt__Active__c = true LIMIT 2000]) {
            out.add(comp(c.Name, 'FlexCard', c.vlocity_cmt__Version__c == null ? null : c.vlocity_cmt__Version__c.intValue(), c.vlocity_cmt__Author__c, c.CreatedDate, c.LastModifiedDate, c.Name));
        }
        for (OmniProcess p : [SELECT Name, Type, SubType, Language, IsIntegrationProcedure, VersionNumber, CreatedDate, LastModifiedDate FROM OmniProcess WHERE IsActive = true
                              AND (Type LIKE 'ESM%' OR Type LIKE 'CPQ%' OR Type LIKE 'MultiService%' OR Type LIKE 'B2B%' OR Type LIKE 'b2b%') LIMIT 2000]) {
            out.add(comp(p.Type + '/' + p.SubType + (p.IsIntegrationProcedure ? '' : ' (' + p.Language + ')'), p.IsIntegrationProcedure ? 'IntegrationProcedure' : 'OmniScript',
                p.VersionNumber == null ? null : p.VersionNumber.intValue(), null, p.CreatedDate, p.LastModifiedDate, p.Type + '/' + p.SubType));
        }
        return out;
    }

    @TestVisible static Component comp(String name, String kind, Integer version, String author, Datetime created, Datetime modified, String key) {
        Component c = new Component();
        c.name = name; c.kind = kind; c.version = version; c.key = key;
        List<String> why = new List<String>();
        if (version != null && version > 1) why.add('version ' + version);
        if (String.isNotBlank(author) && !STANDARD_AUTHORS.contains(author.trim().toLowerCase())) why.add('author ' + author);
        if (created != null && modified != null && modified > created.addDays(1)) why.add('edited ' + modified.format('yyyy-MM-dd'));
        c.customized = !why.isEmpty();
        c.why = String.join(why, ', ');
        return c;
    }

    static Boolean kindMatches(String listed, String actual) {
        if (listed == null) return true;
        return listed.equalsIgnoreCase(actual);
    }

    /** Glob match ("*" at the end, case-insensitive); FlexCard names with or without the compiled "cf" prefix. */
    public static Boolean matches(String pattern, String name) {
        if (pattern == null || name == null) return false;
        String p = norm(pattern), n = norm(name);
        if (p.endsWith('*')) return n.startsWith(p.removeEnd('*'));
        return n == p;
    }

    static String norm(String s) {
        String v = s.trim().toLowerCase();
        if (v.startsWith('cf') && v.length() > 2 && !v.contains('/')) v = v.substring(2);
        return v;
    }
}
