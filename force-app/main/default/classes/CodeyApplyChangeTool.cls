/**
 * Codey tool apply_esm_change (preview / commit) - approved configuration changes for the Health check (Fix it),
 * Pricing and Customization skills, with undo.
 *
 * changeType:
 *   cpqSetting / enrichQuoteOption - CPQ Configuration Setup value (target = setting name, value = new value)
 *   generalSetting                 - Vlocity General Settings value (target = name, value)
 *   pricingPlanStep                - create or update a pricing plan step (fieldsJson: name, sequence, implementation, method, parameters, active, description, plan; recordId to update)
 *   contextRule / contextRuleset   - context rule (fieldsJson: name, ruleset, product, expression, adHocExpression, failureMessage, active, description) or ruleset (name, objectType, active)
 *   attributeBinding               - Quote Member Binding (fieldsJson: attribute, objectClass, fieldApiName)
 *   linearRelationship             - product relationship (fieldsJson: product, relatedProduct, relationshipType, minQuantity, maxQuantity, description)
 *   record                         - any allow-listed ESM configuration object (target = object API name, fieldsJson with field API names, recordId to update)
 *   undo                           - reverse a committed change (target = Codey Change Log Id or name)
 * Writes run in USER_MODE (the asking user's permissions). Secrets are refused: they go through the secure Codey Setup page.
 */
public with sharing class CodeyApplyChangeTool {

    public static final String TOOL = 'apply_esm_change';
    static final String NS = 'vlocity_cmt__';
    public static final Set<String> ALLOWED = new Set<String>{
        'vlocity_cmt__cpqconfigurationsetup__c', 'vlocity_cmt__generalsettings__c', 'vlocity_cmt__pricingplanstep__c', 'vlocity_cmt__pricingvariable__c',
        'vlocity_cmt__contextrule__c', 'vlocity_cmt__contextruleset__c', 'vlocity_cmt__attributebinding__c', 'vlocity_cmt__productrelationship__c',
        'vlocity_cmt__pricingelement__c', 'vlocity_cmt__pricelistentry__c' };

    public class Request {
        @InvocableVariable(label='Mode' description='preview (default) or commit. Commit only after the person approved the preview, with the same inputs and previewToken.')
        public String mode;
        @InvocableVariable(label='Change Type' description='cpqSetting, enrichQuoteOption, generalSetting, pricingPlanStep, contextRule, contextRuleset, attributeBinding, linearRelationship, record or undo.' required=true)
        public String changeType;
        @InvocableVariable(label='Target' description='Setting name (cpqSetting/generalSetting/enrichQuoteOption), object API name (record) or change log Id/name (undo).')
        public String target;
        @InvocableVariable(label='Value' description='New value for a setting.')
        public String value;
        @InvocableVariable(label='Fields JSON' description='JSON object with the fields for record-type changes, e.g. {"name":"Regional Surcharge","sequence":45,"implementation":"DefaultPricingPlanImplementation","method":"..."}')
        public String fieldsJson;
        @InvocableVariable(label='Record Id' description='Optional: existing record to update instead of creating one.')
        public String recordId;
        @InvocableVariable(label='Reason' description='Optional: why the change is made (stored in the log).')
        public String reason;
        @InvocableVariable(label='Preview Token' description='From the preview, for mode=commit.')
        public String previewToken;
        @InvocableVariable(label='Confirm Production' description='true only when the person confirmed the change in a production org.')
        public Boolean confirmProduction;
        @InvocableVariable(label='Surface' description='Optional: where the request comes from.')
        public String surface;
    }

    @InvocableMethod(label='apply_esm_change' description='Make an approved ESM configuration change: CPQ setting, Enrich Quote option, pricing plan step, context rule, Quote Member Binding, linear relationship, or undo of an earlier change. mode=preview shows Before/After (nothing saved); mode=commit applies it after the person approved, with the same inputs and previewToken.')
    public static List<CodeyResult> run(List<Request> requests) {
        List<CodeyResult> out = new List<CodeyResult>();
        for (Request r : requests) out.add(handle(r));
        return out;
    }

    static Map<String, Object> inputs(Request r) {
        return new Map<String, Object>{ 'changeType' => r.changeType, 'target' => r.target, 'value' => r.value, 'fieldsJson' => r.fieldsJson,
            'recordId' => r.recordId, 'reason' => r.reason, 'surface' => r.surface };
    }

    /** One planned change on one record. */
    public class Spec {
        public String objectApiName;
        public Id recordId;
        public String operation;              // create, update, delete
        public String label;
        public Map<String, Object> fields = new Map<String, Object>();
        public Map<String, Object> before = new Map<String, Object>();
        public List<Id> deleteIds = new List<Id>();
        public Id undoLogId;
    }

    public static CodeyResult handle(Request r) {
        String mode = String.isBlank(r.mode) ? 'preview' : r.mode.trim().toLowerCase();
        Codey_Change_Log__c log;
        try {
            Spec s = build(r);
            List<CodeyCards.Change> changes = describeChanges(s);
            if (mode == 'preview') {
                log = CodeyCore.logPreview(TOOL, r.changeType, s.label, s.before, afterJson(s), inputs(r));
                CodeyResult res = CodeyResult.ok('preview', 'Preview: ' + s.operation + ' ' + s.label + ' (' + changes.size() + ' field changes). Nothing has changed yet.', new Map<String, Object>{ 'object' => s.objectApiName,
                    'operation' => s.operation, 'recordId' => s.recordId, 'before' => s.before, 'after' => s.fields });
                res.previewToken = log.Preview_Token__c;
                res.changeLogId = log.Id;
                res.card = CodeyCards.approval(cap(s.operation) + ' ' + s.label, s.objectApiName.replace(NS, '').replace('__c', ''), changes, log.Preview_Token__c, r.reason);
                res.nextStep = 'Show the Approval card. Only after the person says approve: call mode=commit with the same inputs and previewToken.';
                return res;
            }
            if (mode != 'commit') throw new CodeyCore.ToolException('Unknown mode "' + r.mode + '". Use preview or commit.');
            CodeyCore.guardProduction(r.confirmProduction);   // before the preview is used, so a refusal keeps the preview open
            log = CodeyCore.requireApproval(TOOL, inputs(r), r.previewToken);
            List<Id> ids = apply(s);
            CodeyCore.markCommitted(log, afterJson(s), ids);
            if (s.undoLogId != null) update new Codey_Change_Log__c(Id = s.undoLogId, Status__c = 'Undone');
            CodeyCore.resetCaches();
            CodeyResult res = CodeyResult.ok('commit', 'Done: ' + s.operation + ' ' + s.label + '. Log ' + log.Name + (s.operation == 'delete' ? '' : ' (undo with changeType=undo target=' + log.Name + ').'),
                new Map<String, Object>{ 'recordIds' => ids, 'operation' => s.operation, 'object' => s.objectApiName });
            res.changeLogId = log.Id;
            res.card = CodeyCards.basic(res, 'Change applied');
            res.nextStep = nextCheck(r.changeType);
            return res;
        } catch (Exception e) {
            if (mode == 'commit' && log != null) CodeyCore.markFailed(log, e.getMessage());
            return CodeyResult.fail(mode, e);
        }
    }

    static String nextCheck(String changeType) {
        String t = changeType == null ? '' : changeType.toLowerCase();
        if (t == 'cpqsetting' || t == 'enrichquoteoption' || t == 'generalsetting') return 'Re-run check_esm_setup for this area and confirm the item is OK.';
        if (t == 'pricingplanstep') return 'Test on a sample: preview_esm_price with the same sample products; run run_esm_admin_jobs jobs=pricing if prices are cached.';
        if (t == 'contextrule' || t == 'contextruleset' || t == 'attributebinding') return 'Test on sample members (preview_esm_price with locations); context/attribute caches may need run_esm_admin_jobs jobs=catalog.';
        if (t == 'linearrelationship') return 'Check on a sample quote that the related product is offered as expected.';
        return 'Verify the result.';
    }

    // ------------------------------------------------------------------ build specs
    public static Spec build(Request r) {
        String t = r.changeType == null ? '' : r.changeType.trim().toLowerCase();
        Map<String, Object> f = String.isBlank(r.fieldsJson) ? new Map<String, Object>() : lowerKeys((Map<String, Object>) JSON.deserializeUntyped(r.fieldsJson));
        if (t == 'cpqsetting' || t == 'enrichquoteoption') return settingSpec(NS + 'CpqConfigurationSetup__c', NS + 'SetupValue__c', r.target, r.value, 'CPQ setting');
        if (t == 'generalsetting') return settingSpec(NS + 'GeneralSettings__c', NS + 'Value__c', r.target, r.value, 'General setting');
        if (t == 'pricingplanstep') return pricingStepSpec(f, r.recordId);
        if (t == 'contextrule') return contextRuleSpec(f, r.recordId);
        if (t == 'contextruleset') return recordSpec(NS + 'ContextRuleset__c', mapFields(f, new Map<String, String>{ 'name' => 'Name', 'objecttype' => NS + 'ObjectType__c', 'active' => NS + 'IsActive__c', 'expression' => NS + 'Expression__c' }), r.recordId, 'context ruleset');
        if (t == 'attributebinding') return bindingSpec(f, r.recordId);
        if (t == 'linearrelationship') return relationshipSpec(f, r.recordId);
        if (t == 'record') {
            if (String.isBlank(r.target) || !ALLOWED.contains(r.target.trim().toLowerCase())) throw new CodeyCore.ToolException('Object "' + r.target + '" is not allowed. Allowed: ' + String.join(new List<String>(ALLOWED), ', ') + '.');
            return recordSpec(r.target.trim(), f, r.recordId, r.target.trim().replace(NS, ''));
        }
        if (t == 'undo') return undoSpec(r.target);
        throw new CodeyCore.ToolException('Unknown changeType "' + r.changeType + '". Use cpqSetting, enrichQuoteOption, generalSetting, pricingPlanStep, contextRule, contextRuleset, attributeBinding, linearRelationship, record or undo.');
    }

    static Spec settingSpec(String obj, String valueField, String name, String value, String what) {
        if (String.isBlank(name)) throw new CodeyCore.ToolException('Give the setting name as target.');
        if (CodeyCore.isSecretName(name)) throw new CodeyCore.ToolException('"' + name + '" holds a secret. Secrets are never sent through chat or tools: ask the person to enter it on the secure page App Launcher → Codey Setup.');
        if (value == null) throw new CodeyCore.ToolException('Give the new value.');
        Spec s = new Spec();
        s.objectApiName = obj;
        s.label = what + ' ' + name.trim();
        List<SObject> existing = Database.query('SELECT Id, Name, ' + valueField + ' FROM ' + obj + ' WHERE Name = :name LIMIT 1');
        if (existing.isEmpty()) {
            s.operation = 'create';
            s.fields.put('Name', name.trim());
        } else {
            s.operation = 'update';
            s.recordId = existing[0].Id;
            s.before.put(valueField, existing[0].get(valueField));
            if (String.valueOf(existing[0].get(valueField)) == value) throw new CodeyCore.ToolException(what + ' ' + name + ' is already "' + value + '". Nothing to change.');
        }
        s.fields.put(valueField, value);
        return s;
    }

    static Spec pricingStepSpec(Map<String, Object> f, String recordId) {
        Map<String, Object> fields = mapFields(f, new Map<String, String>{ 'name' => 'Name', 'sequence' => NS + 'Sequence__c', 'implementation' => NS + 'ImplementationName__c',
            'implementationname' => NS + 'ImplementationName__c', 'method' => NS + 'MethodName__c', 'methodname' => NS + 'MethodName__c', 'parameters' => NS + 'Parameters__c',
            'active' => NS + 'IsActive__c', 'isactive' => NS + 'IsActive__c', 'description' => NS + 'Description__c' });
        if (String.isBlank(recordId)) {
            fields.put(NS + 'PricingPlanId__c', planId(f.get('plan') == null ? null : String.valueOf(f.get('plan'))));
            if (!fields.containsKey('Name') || !fields.containsKey(NS + 'Sequence__c')) throw new CodeyCore.ToolException('A new pricing plan step needs at least name and sequence (plus implementation and method).');
            if (!fields.containsKey(NS + 'IsActive__c')) fields.put(NS + 'IsActive__c', true);
        }
        return recordSpec(NS + 'PricingPlanStep__c', fields, recordId, 'pricing plan step ' + (fields.containsKey('Name') ? String.valueOf(fields.get('Name')) : recordId));
    }

    public static Id planId(String ref) {
        List<vlocity_cmt__PricingPlan__c> plans;
        if (String.isNotBlank(ref)) {
            plans = [SELECT Id FROM vlocity_cmt__PricingPlan__c WHERE Id = :(ref.length() >= 15 && ref.startsWith('a') ? ref : null) OR Name = :ref OR vlocity_cmt__Code__c = :ref LIMIT 2];
        } else {
            String code = CodeyCore.cpqValue('DefaultPricingPlan');
            plans = [SELECT Id FROM vlocity_cmt__PricingPlan__c WHERE vlocity_cmt__Code__c = :code OR Name = :code LIMIT 2];
            if (plans.isEmpty()) plans = [SELECT Id FROM vlocity_cmt__PricingPlan__c WHERE vlocity_cmt__IsActive__c = true LIMIT 2];
        }
        if (plans.size() != 1) throw new CodeyCore.ToolException('Could not find exactly one pricing plan' + (String.isBlank(ref) ? '' : ' for "' + ref + '"') + '. Give plan (name or code).');
        return plans[0].Id;
    }

    static Spec contextRuleSpec(Map<String, Object> f, String recordId) {
        Map<String, Object> fields = mapFields(f, new Map<String, String>{ 'name' => 'Name', 'expression' => NS + 'Expression__c', 'adhocexpression' => NS + 'AdHocExpression__c',
            'failuremessage' => NS + 'FailureMessage__c', 'active' => NS + 'IsActive__c', 'isactive' => NS + 'IsActive__c', 'description' => NS + 'Description__c',
            'objectapiname' => NS + 'ObjectApiName__c', 'negated' => NS + 'IsNegated__c' });
        if (f.containsKey('ruleset')) fields.put(NS + 'Ruleset__c', lookupId('vlocity_cmt__ContextRuleset__c', String.valueOf(f.get('ruleset')), null));
        if (f.containsKey('product')) {
            Id pid = productId(String.valueOf(f.get('product')));
            fields.put(NS + 'ObjectId__c', String.valueOf(pid));
            if (!fields.containsKey(NS + 'ObjectApiName__c')) fields.put(NS + 'ObjectApiName__c', 'Product2');
        }
        if (String.isBlank(recordId) && !fields.containsKey(NS + 'IsActive__c')) fields.put(NS + 'IsActive__c', false); // created inactive; turning on is a second approved change
        return recordSpec(NS + 'ContextRule__c', fields, recordId, 'context rule ' + (fields.containsKey('Name') ? String.valueOf(fields.get('Name')) : recordId));
    }

    static Spec bindingSpec(Map<String, Object> f, String recordId) {
        Map<String, Object> fields = mapFields(f, new Map<String, String>{ 'fieldapiname' => NS + 'FieldApiName__c', 'field' => NS + 'FieldApiName__c' });
        if (f.containsKey('attribute')) {
            String ref = String.valueOf(f.get('attribute'));
            List<vlocity_cmt__Attribute__c> at = [SELECT Id, vlocity_cmt__Code__c FROM vlocity_cmt__Attribute__c WHERE vlocity_cmt__Code__c = :ref OR Name = :ref OR Id = :(ref.length() >= 15 ? ref : null) LIMIT 2];
            if (at.size() != 1) throw new CodeyCore.ToolException('Attribute "' + ref + '" not found (or not unique). Give the attribute code.');
            fields.put(NS + 'AttributeId__c', at[0].Id);
            fields.put(NS + 'AttributeCode__c', at[0].vlocity_cmt__Code__c);
        }
        if (f.containsKey('objectclass')) fields.put(NS + 'ObjectClassId__c', lookupId('vlocity_cmt__ObjectClass__c', String.valueOf(f.get('objectclass')), null));
        return recordSpec(NS + 'AttributeBinding__c', fields, recordId, 'Quote Member Binding ' + String.valueOf(fields.get(NS + 'AttributeCode__c')) + ' ← ' + String.valueOf(fields.get(NS + 'FieldApiName__c')));
    }

    static Spec relationshipSpec(Map<String, Object> f, String recordId) {
        Map<String, Object> fields = mapFields(f, new Map<String, String>{ 'name' => 'Name', 'relationshiptype' => NS + 'RelationshipType__c', 'type' => NS + 'RelationshipType__c',
            'minquantity' => NS + 'MinQuantity__c', 'maxquantity' => NS + 'MaxQuantity__c', 'description' => NS + 'Description__c', 'context' => NS + 'Context__c' });
        if (f.containsKey('product')) fields.put(NS + 'Product2Id__c', productId(String.valueOf(f.get('product'))));
        if (f.containsKey('relatedproduct')) fields.put(NS + 'RelatedProductId__c', productId(String.valueOf(f.get('relatedproduct'))));
        if (String.isBlank(recordId) && !fields.containsKey('Name')) fields.put('Name', 'Codey linear relationship');
        return recordSpec(NS + 'ProductRelationship__c', fields, recordId, 'linear relationship ' + String.valueOf(fields.get('Name')));
    }

    static Spec recordSpec(String obj, Map<String, Object> rawFields, String recordId, String label) {
        Schema.SObjectType st = Schema.getGlobalDescribe().get(obj);
        if (st == null) throw new CodeyCore.ToolException('Object ' + obj + ' does not exist in this org.');
        Map<String, Schema.SObjectField> fm = st.getDescribe().fields.getMap();
        Spec s = new Spec();
        s.objectApiName = st.getDescribe().getName();
        s.label = label;
        for (String k : rawFields.keySet()) {
            String api = resolveField(fm, k);
            if (api == null) throw new CodeyCore.ToolException('Field "' + k + '" does not exist on ' + s.objectApiName + '.');
            if (CodeyCore.isSecretName(api)) throw new CodeyCore.ToolException('Field ' + api + ' looks like a secret; use the secure Codey Setup page.');
            s.fields.put(api, coerce(fm.get(api).getDescribe(), rawFields.get(k)));
        }
        if (s.fields.isEmpty()) throw new CodeyCore.ToolException('No fields given (fieldsJson).');
        if (String.isNotBlank(recordId)) {
            s.operation = 'update';
            s.recordId = recordId;
            List<String> names = new List<String>(s.fields.keySet());
            List<SObject> rows = Database.query('SELECT Id, ' + String.join(names, ', ') + ' FROM ' + s.objectApiName + ' WHERE Id = :recordId LIMIT 1');
            if (rows.isEmpty()) throw new CodeyCore.ToolException('Record ' + recordId + ' not found on ' + s.objectApiName + '.');
            for (String n : names) s.before.put(n, rows[0].get(n));
        } else {
            s.operation = 'create';
        }
        return s;
    }

    static Spec undoSpec(String ref) {
        if (String.isBlank(ref)) throw new CodeyCore.ToolException('Give the change log Id or name (CL-...) to undo.');
        String v = ref.trim();
        List<Codey_Change_Log__c> logs = [SELECT Id, Name, Status__c, Tool__c, Change_Type__c, Target__c, Before_JSON__c, After_JSON__c, Record_Ids__c FROM Codey_Change_Log__c
                                          WHERE (Name = :v OR Id = :(v.length() >= 15 && !v.startsWith('CL-') ? v : null)) LIMIT 1];
        if (logs.isEmpty()) throw new CodeyCore.ToolException('Change log ' + v + ' not found.');
        Codey_Change_Log__c l = logs[0];
        if (l.Tool__c != TOOL || l.Status__c != 'Committed' || l.Change_Type__c == 'undo') throw new CodeyCore.ToolException('Only committed apply_esm_change changes can be undone (' + l.Name + ' is ' + l.Status__c + ' / ' + l.Tool__c + ').');
        Map<String, Object> after = (Map<String, Object>) JSON.deserializeUntyped(l.After_JSON__c);
        Spec s = new Spec();
        s.objectApiName = String.valueOf(after.get('object'));
        s.undoLogId = l.Id;
        s.label = 'undo of ' + l.Name + ' (' + l.Target__c + ')';
        List<String> ids = CodeyCore.splitList(l.Record_Ids__c);
        if (after.get('operation') == 'create') {
            s.operation = 'delete';
            for (String i : ids) s.deleteIds.add(i);
            s.before.put('records', ids);
        } else {
            s.operation = 'update';
            s.recordId = ids.isEmpty() ? null : ids[0];
            Map<String, Object> before = String.isBlank(l.Before_JSON__c) ? new Map<String, Object>() : (Map<String, Object>) JSON.deserializeUntyped(l.Before_JSON__c);
            Map<String, Object> afterFields = (Map<String, Object>) after.get('fields');
            Schema.SObjectType st = Schema.getGlobalDescribe().get(s.objectApiName);
            Map<String, Schema.SObjectField> fm = st.getDescribe().fields.getMap();
            for (String k : before.keySet()) {
                s.fields.put(k, coerce(fm.get(k).getDescribe(), before.get(k)));
                s.before.put(k, afterFields == null ? null : afterFields.get(k));
            }
        }
        return s;
    }

    // ------------------------------------------------------------------ apply
    public static List<Id> apply(Spec s) {
        if (s.operation == 'delete') {
            if (s.deleteIds.isEmpty()) return new List<Id>();
            Database.delete(s.deleteIds, true, AccessLevel.USER_MODE);
            return s.deleteIds;
        }
        SObject rec = s.recordId == null ? Schema.getGlobalDescribe().get(s.objectApiName).newSObject() : Schema.getGlobalDescribe().get(s.objectApiName).newSObject(s.recordId);
        for (String k : s.fields.keySet()) rec.put(k, s.fields.get(k));
        if (s.recordId == null) Database.insert(rec, true, AccessLevel.USER_MODE);
        else Database.update(rec, true, AccessLevel.USER_MODE);
        return new List<Id>{ rec.Id };
    }

    static Map<String, Object> afterJson(Spec s) {
        return new Map<String, Object>{ 'object' => s.objectApiName, 'operation' => s.operation, 'recordId' => s.recordId, 'fields' => s.fields, 'delete' => s.deleteIds };
    }

    static List<CodeyCards.Change> describeChanges(Spec s) {
        List<CodeyCards.Change> out = new List<CodeyCards.Change>();
        if (s.operation == 'delete') {
            for (Id i : s.deleteIds) out.add(new CodeyCards.Change(s.objectApiName.replace(NS, '') + ' ' + i, 'Remove', 'exists', 'deleted'));
            return out;
        }
        for (String k : s.fields.keySet()) {
            Object b = s.before.get(k);
            out.add(new CodeyCards.Change(k.replace(NS, '').replace('__c', ''), s.operation == 'create' ? 'Create' : 'Update', s.operation == 'create' ? '(new)' : (b == null ? '(empty)' : String.valueOf(b)),
                s.fields.get(k) == null ? '(empty)' : String.valueOf(s.fields.get(k))));
        }
        return out;
    }

    // ------------------------------------------------------------------ helpers
    static Map<String, Object> lowerKeys(Map<String, Object> m) {
        Map<String, Object> out = new Map<String, Object>();
        for (String k : m.keySet()) out.put(k.toLowerCase(), m.get(k));
        return out;
    }

    /** Maps friendly keys to API names; unknown keys are passed through for resolveField. */
    static Map<String, Object> mapFields(Map<String, Object> f, Map<String, String> aliases) {
        Map<String, Object> out = new Map<String, Object>();
        Set<String> special = new Set<String>{ 'plan', 'ruleset', 'product', 'relatedproduct', 'attribute', 'objectclass' };
        for (String k : f.keySet()) {
            if (special.contains(k)) continue;
            out.put(aliases.containsKey(k) ? aliases.get(k) : k, f.get(k));
        }
        return out;
    }

    static String resolveField(Map<String, Schema.SObjectField> fm, String k) {
        for (String c : new List<String>{ k, NS + k, NS + k + '__c', k + '__c' }) {
            if (fm.containsKey(c.toLowerCase())) return fm.get(c.toLowerCase()).getDescribe().getName();
        }
        return null;
    }

    static Object coerce(Schema.DescribeFieldResult d, Object v) {
        if (v == null) return null;
        String s = String.valueOf(v);
        Schema.DisplayType t = d.getType();
        if (t == Schema.DisplayType.BOOLEAN) return v instanceof Boolean ? v : (Object) Boolean.valueOf(s);
        if (t == Schema.DisplayType.DOUBLE || t == Schema.DisplayType.CURRENCY || t == Schema.DisplayType.PERCENT) return Decimal.valueOf(s);
        if (t == Schema.DisplayType.INTEGER) return Integer.valueOf(s);
        if (t == Schema.DisplayType.DATE) return Date.valueOf(s);
        if (t == Schema.DisplayType.DATETIME) return (Datetime) JSON.deserialize('"' + s + '"', Datetime.class);
        if (t == Schema.DisplayType.REFERENCE) return (Id) s;
        return s;
    }

    public static Id productId(String ref) {
        if (String.isBlank(ref)) throw new CodeyCore.ToolException('Give a product name, code or Id.');
        String v = ref.trim();
        List<Product2> ps = [SELECT Id FROM Product2 WHERE (Id = :(v.startsWith('01t') && v.length() >= 15 ? v : null) OR ProductCode = :v OR Name = :v) AND IsActive = true LIMIT 2];
        if (ps.size() != 1) throw new CodeyCore.ToolException('Product "' + v + '" ' + (ps.isEmpty() ? 'not found' : 'is not unique (use the product code)') + '.');
        return ps[0].Id;
    }

    static Id lookupId(String obj, String ref, String codeField) {
        String v = ref == null ? '' : ref.trim();
        String q = 'SELECT Id FROM ' + obj + ' WHERE Name = :v' + (v.length() >= 15 && !v.contains(' ') ? ' OR Id = :v' : '') + ' LIMIT 2';
        List<SObject> rows = Database.query(q);
        if (rows.size() != 1) throw new CodeyCore.ToolException(obj.replace(NS, '').replace('__c', '') + ' "' + v + '" ' + (rows.isEmpty() ? 'not found' : 'is not unique') + '.');
        return rows[0].Id;
    }

    static String cap(String s) { return String.isBlank(s) ? s : s.substring(0, 1).toUpperCase() + s.substring(1); }
}
