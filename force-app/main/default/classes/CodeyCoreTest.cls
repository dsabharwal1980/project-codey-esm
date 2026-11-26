@IsTest
private class CodeyCoreTest {

    @IsTest static void tokensAndApprovalGate() {
        Map<String, Object> inputs = new Map<String, Object>{ 'a' => '1', 'b' => 2, 'mode' => 'preview' };
        String t1 = CodeyCore.token('tool_x', inputs);
        System.assertEquals(t1, CodeyCore.token('tool_x', new Map<String, Object>{ 'b' => 2, 'a' => '1', 'mode' => 'commit', 'previewToken' => 'zzz' }), 'mode/token are not part of the hash');
        System.assertNotEquals(t1, CodeyCore.token('tool_x', new Map<String, Object>{ 'a' => '2', 'b' => 2 }));
        Codey_Change_Log__c l = CodeyCore.logPreview('tool_x', 'test', 'target', 'before', new Map<String, Object>{ 'x' => 1 }, inputs);
        System.assertEquals(t1, l.Preview_Token__c);
        try { CodeyCore.requireApproval('tool_x', inputs, null); System.assert(false); } catch (CodeyCore.ToolException e) { System.assert(e.getMessage().contains('No preview token')); }
        try { CodeyCore.requireApproval('tool_x', new Map<String, Object>{ 'a' => '9' }, t1); System.assert(false); } catch (CodeyCore.ToolException e) { System.assert(e.getMessage().contains('not the same')); }
        Codey_Change_Log__c ok = CodeyCore.requireApproval('tool_x', inputs, t1);
        CodeyCore.markCommitted(ok, 'after', new List<Id>{ ok.Id });
        try { CodeyCore.requireApproval('tool_x', inputs, t1); System.assert(false); } catch (CodeyCore.ToolException e) { System.assert(e.getMessage().contains('Already done')); }
        Codey_Change_Log__c l2 = CodeyCore.logPreview('tool_y', 'test', 't', null, null, inputs);
        l2.Expires_At__c = System.now().addMinutes(-1); update l2;
        try { CodeyCore.requireApproval('tool_y', inputs, l2.Preview_Token__c); System.assert(false); } catch (CodeyCore.ToolException e) { System.assert(e.getMessage().contains('expired')); }
        CodeyCore.markFailed(l2, 'boom');
        CodeyCore.markFailed(null, 'ignored');
        System.assertNotEquals(null, CodeyCore.logRead('tool_z', 'x', inputs).Id);
    }

    @IsTest static void productionGuardAndHelpers() {
        CodeyCore.sandboxOverride = false;
        try { CodeyCore.guardProduction(false); System.assert(false); } catch (CodeyCore.ToolException e) { System.assert(e.getMessage().contains('PRODUCTION')); }
        CodeyCore.guardProduction(true);
        System.assertNotEquals(null, CodeyCore.productionNote());
        CodeyCore.sandboxOverride = true;
        CodeyCore.guardProduction(null);
        System.assertEquals(null, CodeyCore.productionNote());
        System.assert(CodeyCore.isSecretName('GoogleMapsAPIKey'));
        System.assert(CodeyCore.isSecretName('CpqCachePvtKey'));
        System.assert(!CodeyCore.isSecretName('CacheEnabled'));
        System.assertEquals('(not set)', CodeyCore.mask('x', null, true));
        System.assertEquals('•••• (set)', CodeyCore.mask('MyApiKey', 'abc', false));
        System.assertEquals('v', CodeyCore.mask('Plain', 'v', false));
        System.assertEquals(3, CodeyCore.splitList('a, b;c').size());
        Map<String, String> sec = CodeyCore.sections('## one\nA\n## two\nB');
        System.assertEquals(2, sec.size());
        System.assertNotEquals(null, CodeyCore.money(12.5));
        for (String m : new List<String>{ 'INSUFFICIENT_ACCESS', 'preview expired', 'production', 'UNABLE_TO_LOCK_ROW', 'Too many SOQL', 'FIELD_CUSTOM_VALIDATION', 'already running', 'no quote', 'other' }) {
            System.assertNotEquals(null, CodeyCore.suggestFix(m));
        }
        CodeyTestData.setting('CodeyTestSetting', 'on');
        System.assertEquals('on', CodeyCore.cpqValue('codeytestsetting'));
        try { CodeyCore.staticText('Does_Not_Exist_Codey'); System.assert(false); } catch (CodeyCore.ToolException e) { }
    }

    @IsTest static void quoteLookup() {
        Quote q = CodeyTestData.quote(1);
        System.assertEquals(q.Id, CodeyCore.findQuote(q.Id).Id);
        System.assertEquals(q.Id, CodeyCore.findQuote('Codey Test Quote 1').Id);
        try { CodeyCore.findQuote(''); System.assert(false); } catch (CodeyCore.ToolException e) { }
        try { CodeyCore.findQuote('No such quote xyz'); System.assert(false); } catch (CodeyCore.ToolException e) { }
    }

    @IsTest static void cards() {
        List<CodeyCards.Change> ch = new List<CodeyCards.Change>();
        for (Integer i = 0; i < 30; i++) ch.add(new CodeyCards.Change('t' + i, Math.mod(i, 2) == 0 ? 'Create' : 'Update', 'b', 'a'));
        CodeyCore.sandboxOverride = false;
        CodeyCard a = CodeyCards.approval('Title', 'Sub', ch, 'tok', 'Summary');
        System.assertEquals('approval', a.cardType);
        System.assertEquals(2, a.buttons.size());
        System.assert(a.hasMore && a.hasCallout);
        List<CodeyCards.HealthRow> rows = new List<CodeyCards.HealthRow>();
        for (String s : new List<String>{ 'OK', 'Warning', 'Needs Fix' }) {
            CodeyCards.HealthRow h = new CodeyCards.HealthRow(); h.status = s; h.label = s; h.reason = 'r'; h.helpUrl = 'https://help'; h.fixMessage = s == 'OK' ? null : 'fix'; h.area = 'Quoting';
            rows.add(h);
        }
        CodeyCard h = CodeyCards.health('Health', 'sub', rows);
        System.assertEquals(3, h.stats.size());
        List<CodeyCards.StepRow> steps = new List<CodeyCards.StepRow>();
        for (String s : new List<String>{ 'Completed', 'Failed', 'Manual', 'Running' }) { CodeyCards.StepRow r = new CodeyCards.StepRow(); r.label = s; r.status = s; r.percent = 50; steps.add(r); }
        CodeyCard p = CodeyCards.progress('Jobs', 'sub', 'Failed', 40, steps, 'a00000000000001', 'resume here', 'https://file');
        System.assert(p.hasProgress && p.hasCallout);
        List<CodeyCards.ImpactRow> imp = new List<CodeyCards.ImpactRow>();
        for (String s : new List<String>{ 'High', 'Medium', 'Low' }) { CodeyCards.ImpactRow r = new CodeyCards.ImpactRow(); r.risk = s; r.screen = s; r.kind = 'FlexCard'; r.change = 'c'; r.action = 'a'; imp.add(r); }
        CodeyCard u = CodeyCards.upgrade('268', imp, 3);
        System.assertEquals(3, u.items.size());
        CodeyResult f = CodeyResult.fail('read', new CodeyCore.ToolException('boom'));
        System.assertEquals(false, f.success);
        System.assertNotEquals(null, f.card);
        CodeyResult f2 = CodeyResult.fail('read', new DmlException('dml'));
        System.assert(f2.message.contains('DmlException'));
        System.assertEquals(null, CodeyCards.recordUrl(null));
    }

    @IsTest static void csvAndAddressChecks() {
        List<List<String>> rows = CodeyCsv.parse('﻿Site Name,Street Address,City,Zip,Country\nA,"1 Main St, Unit 2",Austin,78701,US\n\nB,2 High St,London,SW1A 1AA,United Kingdom\n');
        System.assertEquals(3, rows.size());
        System.assertEquals('1 Main St, Unit 2', rows[1][1]);
        Map<String, Integer> h = CodeyCsv.mapHeader(rows[0]);
        System.assertEquals(0, h.get('name')); System.assertEquals(1, h.get('street')); System.assertEquals(3, h.get('postal'));
        System.assertEquals(2, CodeyCsv.parse('name;street\nA;B').size());
        System.assertEquals('"a,b"', CodeyCsv.esc('a,b'));
        System.assertEquals('x,"y""z"', CodeyCsv.line(new List<Object>{ 'x', 'y"z' }));
        System.assertEquals('Valid', CodeyBulkCheck.addressCheck('1 Main', 'Austin', 'TX', '78701', 'US')[0]);
        System.assertEquals('Invalid', CodeyBulkCheck.addressCheck('1 Main', 'Austin', 'TX', '7870', 'US')[0]);
        System.assertEquals('Invalid', CodeyBulkCheck.addressCheck(null, 'Austin', null, null, 'US')[0]);
        System.assertEquals('Partial', CodeyBulkCheck.addressCheck('1 Main', 'Austin', null, null, 'Narnia')[0]);
        System.assertEquals('GB', CodeyBulkCheck.countryCode('United Kingdom'));
        System.assertEquals(null, CodeyBulkCheck.countryCode(null));
    }

    @IsTest static void secureSettingAsAdmin() {
        Profile pr = [SELECT Id FROM Profile WHERE Name = 'System Administrator' LIMIT 1];
        User u = new User(Alias = 'codeyad', Email = 'codey.admin@example.com', EmailEncodingKey = 'UTF-8', LastName = 'Codey', LanguageLocaleKey = 'en_US',
            LocaleSidKey = 'en_US', ProfileId = pr.Id, TimeZoneSidKey = 'America/Los_Angeles', Username = 'codey.admin.' + System.currentTimeMillis() + '@example.com');
        insert u;
        insert new PermissionSetAssignment(AssigneeId = u.Id, PermissionSetId = [SELECT Id FROM PermissionSet WHERE Name = 'ESM_Codey_Admin'].Id);
        System.runAs(u) {
            Map<String, Object> s = CodeySecureSettingController.saveGoogleMapsKey('AIzaFakeKeyForCodeyTests123');
            System.assertEquals(true, s.get('isSet'));
            Map<String, Object> s2 = CodeySecureSettingController.saveGoogleMapsKey('AIzaFakeKeyForCodeyTests456');
            System.assertEquals(true, s2.get('isSet'));
        }
        Codey_Change_Log__c l = [SELECT After_JSON__c FROM Codey_Change_Log__c WHERE Tool__c = 'codey_setup_page' LIMIT 1];
        System.assert(!l.After_JSON__c.contains('AIza'), 'the key itself is never logged');
    }

    @IsTest static void secureSetting() {
        Map<String, Object> s = CodeySecureSettingController.status();
        System.assertEquals(false, s.get('isSet'));
        try { CodeySecureSettingController.saveGoogleMapsKey('short'); System.assert(false); } catch (AuraHandledException e) { }
    }

    @IsTest static void setupPage() {
        Map<String, Object> h = CodeySetupController.healthCheck('quoting');
        System.assertEquals(true, h.get('success'));
        Map<String, Object> u = CodeySetupController.upgradeImpact(null);
        System.assertEquals(true, u.get('success'));
        Map<String, Object> rec = CodeySetupController.recent();
        System.assert(((List<Object>) rec.get('logs')).size() >= 2);
    }
}
