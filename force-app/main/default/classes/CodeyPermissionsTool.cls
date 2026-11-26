/**
 * Codey tool manage_esm_permissions (preview / commit) - Permissions skill.
 * Compares the recommended permission sets for a user type (Codey_UserType_Permission__mdt) with what the users have,
 * previews the missing assignments (Approval card) and assigns them only after approval. Never removes anything.
 * Assignments run in USER_MODE, so the person asking needs the right to assign permission sets.
 */
public with sharing class CodeyPermissionsTool {

    public static final String TOOL = 'manage_esm_permissions';
    public static final Integer MAX_USERS = 200;

    public class Request {
        @InvocableVariable(label='Mode' description='preview (default) or commit. Commit only after the person approved the preview, with the same inputs and the previewToken.')
        public String mode;
        @InvocableVariable(label='User Type' description='Sales rep, Sales manager, Admin, Pricing admin, Product designer, Service agent or Coworker user.' required=true)
        public String userType;
        @InvocableVariable(label='Users' description='Comma-separated usernames, e-mails, full names or user Ids. Or use profile / role.')
        public String users;
        @InvocableVariable(label='Profile' description='Optional profile name: all active users with this profile.')
        public String profile;
        @InvocableVariable(label='Role' description='Optional role name: all active users with this role.')
        public String role;
        @InvocableVariable(label='Preview Token' description='From the preview, for mode=commit.')
        public String previewToken;
        @InvocableVariable(label='Confirm Production' description='true only when the person confirmed the change in a production org.')
        public Boolean confirmProduction;
        @InvocableVariable(label='Surface' description='Optional: where the request comes from.')
        public String surface;
    }

    @InvocableMethod(label='manage_esm_permissions' description='Give ESM users the recommended permission sets for their user type. mode=preview shows per user what is missing (nothing changes); mode=commit assigns after the person approved, with the same inputs and previewToken. Only adds, never removes.')
    public static List<CodeyResult> run(List<Request> requests) {
        List<CodeyResult> out = new List<CodeyResult>();
        for (Request r : requests) out.add(handle(r));
        return out;
    }

    static Map<String, Object> inputs(Request r) {
        return new Map<String, Object>{ 'userType' => r.userType, 'users' => r.users, 'profile' => r.profile, 'role' => r.role, 'surface' => r.surface };
    }

    public static CodeyResult handle(Request r) {
        String mode = String.isBlank(r.mode) ? 'preview' : r.mode.trim().toLowerCase();
        Codey_Change_Log__c log;
        try {
            Plan p = plan(r);
            if (mode == 'preview') {
                List<CodeyCards.Change> changes = new List<CodeyCards.Change>();
                List<Map<String, Object>> after = new List<Map<String, Object>>();
                for (Missing m : p.missing) {
                    changes.add(new CodeyCards.Change(m.userName, 'Assign', 'not assigned', m.permissionSetLabel));
                    after.add(new Map<String, Object>{ 'userId' => m.userId, 'user' => m.userName, 'permissionSetId' => m.permissionSetId, 'permissionSet' => m.permissionSetLabel });
                }
                if (p.missing.isEmpty()) {
                    CodeyResult ok = CodeyResult.ok('preview', 'All ' + p.users.size() + ' users already have the recommended permission sets for ' + p.userType + '.' + p.notInOrgText(), p.details());
                    ok.card = CodeyCards.approval('Permission sets – ' + p.userType, p.users.size() + ' users already OK', changes, null, 'Nothing to assign.');
                    ok.nextStep = 'Nothing to do.';
                    return ok;
                }
                log = CodeyCore.logPreview(TOOL, 'permissionSetAssignment', p.userType, 'missing ' + p.missing.size(), after, inputs(r));
                CodeyResult res = CodeyResult.ok('preview', 'Preview: assign ' + p.missing.size() + ' permission sets to ' + p.usersMissing() + ' of ' + p.users.size() + ' users (' + p.userType + '). Nothing has changed yet.' + p.notInOrgText(), p.details());
                res.previewToken = log.Preview_Token__c;
                res.changeLogId = log.Id;
                res.card = CodeyCards.approval('Assign permission sets – ' + p.userType, p.users.size() + ' users · ' + p.missing.size() + ' assignments', changes, log.Preview_Token__c, null);
                res.nextStep = 'Show the Approval card. Only after the person says approve: call mode=commit with the same inputs and previewToken.';
                return res;
            }
            if (mode != 'commit') throw new CodeyCore.ToolException('Unknown mode "' + r.mode + '". Use preview or commit.');
            CodeyCore.guardProduction(r.confirmProduction);   // before the preview is used, so a refusal keeps the preview open
            log = CodeyCore.requireApproval(TOOL, inputs(r), r.previewToken);
            List<PermissionSetAssignment> rows = new List<PermissionSetAssignment>();
            for (Missing m : p.missing) rows.add(new PermissionSetAssignment(AssigneeId = m.userId, PermissionSetId = m.permissionSetId));
            List<Database.SaveResult> srs = rows.isEmpty() ? new List<Database.SaveResult>() : Database.insert(rows, false, AccessLevel.USER_MODE);
            List<Id> created = new List<Id>();
            List<String> errors = new List<String>();
            for (Integer i = 0; i < srs.size(); i++) {
                if (srs[i].isSuccess()) created.add(srs[i].getId());
                else errors.add(p.missing[i].userName + ' – ' + p.missing[i].permissionSetLabel + ': ' + srs[i].getErrors()[0].getMessage());
            }
            CodeyCore.markCommitted(log, new Map<String, Object>{ 'assigned' => created.size(), 'errors' => errors }, created);
            Plan check = plan(r);
            String msg = 'Assigned ' + created.size() + ' permission sets (' + p.userType + ').' + (errors.isEmpty() ? '' : ' ' + errors.size() + ' could not be assigned (often a missing permission set licence): ' + String.join(errors, '; ').left(1500))
                + ' Re-check: ' + (check.missing.isEmpty() ? 'all users OK.' : check.missing.size() + ' assignments still missing.');
            CodeyResult res = CodeyResult.ok('commit', msg, new Map<String, Object>{ 'assigned' => created.size(), 'errors' => errors, 'stillMissing' => check.missing.size() });
            res.changeLogId = log.Id;
            res.success = errors.isEmpty() || !created.isEmpty();
            res.card = CodeyCards.basic(res, 'Permission sets assigned');
            res.nextStep = check.missing.isEmpty() ? 'Done. Ask the users to log out and in again.' : 'Assign the missing permission set licences, then preview again.';
            return res;
        } catch (Exception e) {
            if (mode == 'commit' && log != null) CodeyCore.markFailed(log, e.getMessage());
            return CodeyResult.fail(mode, e);
        }
    }

    public class Missing { public Id userId; public String userName; public Id permissionSetId; public String permissionSetLabel; }

    public class Plan {
        public String userType;
        public List<User> users = new List<User>();
        public List<Missing> missing = new List<Missing>();
        public List<String> notInOrg = new List<String>();
        public List<String> recommended = new List<String>();
        public Integer usersMissing() { Set<Id> s = new Set<Id>(); for (Missing m : missing) s.add(m.userId); return s.size(); }
        public String notInOrgText() { return notInOrg.isEmpty() ? '' : ' Not in this org (deploy or skip): ' + String.join(notInOrg, ', ') + '.'; }
        public Map<String, Object> details() {
            Map<Id, List<String>> per = new Map<Id, List<String>>();
            for (Missing m : missing) { if (!per.containsKey(m.userId)) per.put(m.userId, new List<String>()); per.get(m.userId).add(m.permissionSetLabel); }
            List<Object> us = new List<Object>();
            for (User u : users) us.add(new Map<String, Object>{ 'userId' => u.Id, 'name' => u.Name, 'username' => u.Username, 'missing' => per.containsKey(u.Id) ? per.get(u.Id) : new List<String>(), 'status' => per.containsKey(u.Id) ? 'Missing' : 'OK' });
            return new Map<String, Object>{ 'userType' => userType, 'recommended' => recommended, 'notInOrg' => notInOrg, 'users' => us };
        }
    }

    public static Plan plan(Request r) {
        Plan p = new Plan();
        List<Codey_UserType_Permission__mdt> types = [SELECT User_Type__c, Permission_Sets__c FROM Codey_UserType_Permission__mdt WHERE Active__c = true];
        Codey_UserType_Permission__mdt t;
        List<String> names = new List<String>();
        for (Codey_UserType_Permission__mdt x : types) {
            names.add(x.User_Type__c);
            if (r.userType != null && x.User_Type__c.equalsIgnoreCase(r.userType.trim())) t = x;
        }
        if (t == null) throw new CodeyCore.ToolException('Unknown user type "' + r.userType + '". User types: ' + String.join(names, ', ') + '.');
        p.userType = t.User_Type__c;
        p.recommended = CodeyCore.splitList(t.Permission_Sets__c);

        // permission sets in the org
        Set<String> plain = new Set<String>();
        for (String n : p.recommended) plain.add(n.contains('.') ? n.substringAfter('.') : n);
        Map<String, PermissionSet> byKey = new Map<String, PermissionSet>();
        for (PermissionSet ps : [SELECT Id, Name, Label, NamespacePrefix FROM PermissionSet WHERE Name IN :plain AND IsOwnedByProfile = false]) {
            byKey.put(((ps.NamespacePrefix == null ? '' : ps.NamespacePrefix + '.') + ps.Name).toLowerCase(), ps);
        }
        List<PermissionSet> sets = new List<PermissionSet>();
        for (String n : p.recommended) {
            PermissionSet ps = byKey.get(n.toLowerCase());
            if (ps == null) p.notInOrg.add(n); else sets.add(ps);
        }

        // users
        p.users = findUsers(r);
        if (p.users.isEmpty()) throw new CodeyCore.ToolException('No active users found. Give usernames, names, e-mails or Ids, or a profile or role.');

        Set<Id> setIds = new Map<Id, PermissionSet>(sets).keySet();
        Set<String> have = new Set<String>();
        for (PermissionSetAssignment a : [SELECT AssigneeId, PermissionSetId FROM PermissionSetAssignment WHERE AssigneeId IN :p.users AND PermissionSetId IN :setIds]) {
            have.add(a.AssigneeId + ':' + a.PermissionSetId);
        }
        for (User u : p.users) for (PermissionSet ps : sets) {
            if (have.contains(u.Id + ':' + ps.Id)) continue;
            Missing m = new Missing();
            m.userId = u.Id; m.userName = u.Name + ' (' + u.Username + ')'; m.permissionSetId = ps.Id; m.permissionSetLabel = ps.Label + ' [' + ps.Name + ']';
            p.missing.add(m);
        }
        return p;
    }

    static List<User> findUsers(Request r) {
        Map<Id, User> out = new Map<Id, User>();
        if (String.isNotBlank(r.profile)) {
            String prof = r.profile.trim();
            for (User u : [SELECT Id, Name, Username FROM User WHERE IsActive = true AND Profile.Name = :prof ORDER BY Name LIMIT :MAX_USERS]) out.put(u.Id, u);
        }
        if (String.isNotBlank(r.role)) {
            String role = r.role.trim();
            for (User u : [SELECT Id, Name, Username FROM User WHERE IsActive = true AND UserRole.Name = :role ORDER BY Name LIMIT :MAX_USERS]) out.put(u.Id, u);
        }
        List<String> keys = CodeyCore.splitList(r.users);
        if (!keys.isEmpty()) {
            Set<String> ids = new Set<String>();
            for (String k : keys) if (k.startsWith('005') && (k.length() == 15 || k.length() == 18)) ids.add(k);
            for (User u : [SELECT Id, Name, Username FROM User WHERE IsActive = true AND (Username IN :keys OR Email IN :keys OR Name IN :keys OR Id IN :ids) ORDER BY Name LIMIT :MAX_USERS]) out.put(u.Id, u);
        }
        return out.values();
    }
}
