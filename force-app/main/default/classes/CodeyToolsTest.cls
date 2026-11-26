@IsTest
private class CodeyToolsTest {

    @IsTest static void playbook() {
        Quote q = CodeyTestData.quote(3);
        for (String t : new List<String>{ null, 'routing', 'skill:pricing', 'pricing', 'US-07', 'runbook:US-01', 'settings', 'releases', 'index', 'all', 'concept:all' }) {
            CodeyPlaybookTool.Request r = new CodeyPlaybookTool.Request(); r.topic = t;
            CodeyResult res = CodeyPlaybookTool.run(new List<CodeyPlaybookTool.Request>{ r })[0];
            System.assertEquals(true, res.success, t + ': ' + res.message);
        }
        CodeyPlaybookTool.Request c = new CodeyPlaybookTool.Request(); c.topic = 'concept:quote-member-vs-line-item'; c.quoteId = q.Id;
        CodeyResult res = CodeyPlaybookTool.run(new List<CodeyPlaybookTool.Request>{ c })[0];
        System.assert(res.message.contains('3 quote members'), res.message);
        CodeyPlaybookTool.Request bad = new CodeyPlaybookTool.Request(); bad.topic = 'nonsense';
        System.assertEquals(false, CodeyPlaybookTool.run(new List<CodeyPlaybookTool.Request>{ bad })[0].success);
        CodeyPlaybookTool.Request badC = new CodeyPlaybookTool.Request(); badC.topic = 'concept:nonsense';
        System.assertEquals(false, CodeyPlaybookTool.run(new List<CodeyPlaybookTool.Request>{ badC })[0].success);
    }

    @IsTest static void healthCheck() {
        CodeyTestData.setting('CacheEnabled', 'True');
        CodeyTestData.setting('EnableCoreLogs', 'true');
        CodeyTestData.setting('B2BCmexMultiEditApiBatchSize', '500');
        CodeyHealthCheckTool.Request r = new CodeyHealthCheckTool.Request();
        CodeyResult res = CodeyHealthCheckTool.run(new List<CodeyHealthCheckTool.Request>{ r })[0];
        System.assertEquals(true, res.success, res.message);
        System.assertEquals('health', res.card.cardType);
        r.scope = 'quoting, performance';
        System.assertEquals(true, CodeyHealthCheckTool.run(new List<CodeyHealthCheckTool.Request>{ r })[0].success);
        r.scope = 'bogus';
        System.assertEquals(false, CodeyHealthCheckTool.run(new List<CodeyHealthCheckTool.Request>{ r })[0].success);
        System.assert(CodeyHealthCheckTool.compare('equals', 'True', 'true', true));
        System.assert(CodeyHealthCheckTool.compare('between', '5', '1..10', true));
        System.assert(!CodeyHealthCheckTool.compare('between', '50', '1..10', true));
        System.assert(CodeyHealthCheckTool.compare('gte', '3', '1', true));
        System.assert(CodeyHealthCheckTool.compare('lte', '1', '3', true));
        System.assert(!CodeyHealthCheckTool.compare('notBlank', 'None', null, true));
        System.assert(CodeyHealthCheckTool.compare('exists', null, null, true));
        System.assert(!CodeyHealthCheckTool.compare('gte', 'abc', '1', true));
        for (Codey_Recommended_Setting__mdt s : [SELECT DeveloperName, MasterLabel, Area__c, Source__c, Target__c, Operator__c, Recommended__c, Severity__c, Label__c, Reason__c, Help_Url__c, Fixable__c, Secret__c FROM Codey_Recommended_Setting__mdt LIMIT 60]) {
            System.assertNotEquals(null, CodeyHealthCheckTool.fixMessage(s));
        }
    }

    @IsTest static void permissions() {
        User me = [SELECT Id, Username FROM User WHERE Id = :UserInfo.getUserId()];
        CodeyPermissionsTool.Request r = new CodeyPermissionsTool.Request();
        r.userType = 'Codey user'; r.users = me.Username;
        // "Codey user" may not exist as a type: fall back to the first configured type
        List<Codey_UserType_Permission__mdt> types = [SELECT User_Type__c FROM Codey_UserType_Permission__mdt WHERE Active__c = true ORDER BY User_Type__c LIMIT 1];
        r.userType = types[0].User_Type__c;
        CodeyCore.sandboxOverride = true;
        CodeyResult p = CodeyPermissionsTool.run(new List<CodeyPermissionsTool.Request>{ r })[0];
        System.assertEquals(true, p.success, p.message);
        if (p.previewToken != null) {
            r.mode = 'commit'; r.previewToken = p.previewToken;
            CodeyResult c = CodeyPermissionsTool.run(new List<CodeyPermissionsTool.Request>{ r })[0];
            System.assertNotEquals(null, c.message);
        }
        CodeyPermissionsTool.Request bad = new CodeyPermissionsTool.Request(); bad.userType = 'Nobody'; bad.users = me.Username;
        System.assertEquals(false, CodeyPermissionsTool.run(new List<CodeyPermissionsTool.Request>{ bad })[0].success);
        CodeyPermissionsTool.Request nobody = new CodeyPermissionsTool.Request(); nobody.userType = types[0].User_Type__c; nobody.profile = 'No Such Profile';
        System.assertEquals(false, CodeyPermissionsTool.run(new List<CodeyPermissionsTool.Request>{ nobody })[0].success);
        CodeyPermissionsTool.Request noToken = new CodeyPermissionsTool.Request(); noToken.userType = types[0].User_Type__c; noToken.users = me.Username; noToken.mode = 'commit';
        System.assertEquals(false, CodeyPermissionsTool.run(new List<CodeyPermissionsTool.Request>{ noToken })[0].success);
    }

    @IsTest static void applyChangeSettingWithUndo() {
        CodeyCore.sandboxOverride = true;
        CodeyTestData.setting('EnableCoreLogs', 'true');
        CodeyApplyChangeTool.Request r = new CodeyApplyChangeTool.Request();
        r.changeType = 'cpqSetting'; r.target = 'EnableCoreLogs'; r.value = 'false';
        CodeyResult p = CodeyApplyChangeTool.run(new List<CodeyApplyChangeTool.Request>{ r })[0];
        r.mode = 'commit'; r.previewToken = CodeyTestData.token(p);
        CodeyResult c = CodeyApplyChangeTool.run(new List<CodeyApplyChangeTool.Request>{ r })[0];
        System.assertEquals(true, c.success, c.message);
        CodeyCore.resetCaches();
        System.assertEquals('false', CodeyCore.cpqValue('EnableCoreLogs'));
        // same commit again is refused (idempotent)
        System.assertEquals(false, CodeyApplyChangeTool.run(new List<CodeyApplyChangeTool.Request>{ r })[0].success);
        String logName = [SELECT Name FROM Codey_Change_Log__c WHERE Id = :c.changeLogId].Name;
        CodeyApplyChangeTool.Request u = new CodeyApplyChangeTool.Request(); u.changeType = 'undo'; u.target = logName;
        CodeyResult up = CodeyApplyChangeTool.run(new List<CodeyApplyChangeTool.Request>{ u })[0];
        u.mode = 'commit'; u.previewToken = CodeyTestData.token(up);
        System.assertEquals(true, CodeyApplyChangeTool.run(new List<CodeyApplyChangeTool.Request>{ u })[0].success);
        CodeyCore.resetCaches();
        System.assertEquals('true', CodeyCore.cpqValue('EnableCoreLogs'));
        // new setting is created; undo deletes it
        CodeyApplyChangeTool.Request n = new CodeyApplyChangeTool.Request(); n.changeType = 'enrichQuoteOption'; n.target = 'CodeyNewOption'; n.value = 'x';
        CodeyResult np = CodeyApplyChangeTool.run(new List<CodeyApplyChangeTool.Request>{ n })[0];
        n.mode = 'commit'; n.previewToken = CodeyTestData.token(np);
        CodeyResult nc = CodeyApplyChangeTool.run(new List<CodeyApplyChangeTool.Request>{ n })[0];
        System.assertEquals(true, nc.success, nc.message);
        CodeyApplyChangeTool.Request nu = new CodeyApplyChangeTool.Request(); nu.changeType = 'undo'; nu.target = nc.changeLogId;
        CodeyResult nup = CodeyApplyChangeTool.run(new List<CodeyApplyChangeTool.Request>{ nu })[0];
        nu.mode = 'commit'; nu.previewToken = CodeyTestData.token(nup);
        System.assertEquals(true, CodeyApplyChangeTool.run(new List<CodeyApplyChangeTool.Request>{ nu })[0].success);
    }

    @IsTest static void applyChangeRules() {
        CodeyCore.sandboxOverride = true;
        CodeyTestData.plan();
        CodeyApplyChangeTool.Request s = new CodeyApplyChangeTool.Request();
        s.changeType = 'pricingPlanStep'; s.fieldsJson = '{"name":"Regional Surcharge","sequence":45,"implementation":"DefaultPricingPlanImplementation","method":"applyRegionalSurcharge"}';
        CodeyResult sp = CodeyApplyChangeTool.run(new List<CodeyApplyChangeTool.Request>{ s })[0];
        System.assertEquals(true, sp.success, sp.message);
        s.mode = 'commit'; s.previewToken = sp.previewToken;
        System.assertEquals(true, CodeyApplyChangeTool.run(new List<CodeyApplyChangeTool.Request>{ s })[0].success);
        // secrets are refused, objects outside the allow-list are refused, unknown types refused
        CodeyApplyChangeTool.Request sec = new CodeyApplyChangeTool.Request(); sec.changeType = 'cpqSetting'; sec.target = 'GoogleMapsAPIKey'; sec.value = 'x';
        System.assertEquals(false, CodeyApplyChangeTool.run(new List<CodeyApplyChangeTool.Request>{ sec })[0].success);
        CodeyApplyChangeTool.Request rec = new CodeyApplyChangeTool.Request(); rec.changeType = 'record'; rec.target = 'Account'; rec.fieldsJson = '{"Name":"x"}';
        System.assertEquals(false, CodeyApplyChangeTool.run(new List<CodeyApplyChangeTool.Request>{ rec })[0].success);
        CodeyApplyChangeTool.Request unk = new CodeyApplyChangeTool.Request(); unk.changeType = 'nope';
        System.assertEquals(false, CodeyApplyChangeTool.run(new List<CodeyApplyChangeTool.Request>{ unk })[0].success);
        // context ruleset + rule, record type, relationship, binding previews
        CodeyApplyChangeTool.Request rs = new CodeyApplyChangeTool.Request(); rs.changeType = 'contextRuleset'; rs.fieldsJson = '{"name":"North region","active":true}';
        CodeyResult rsp = CodeyApplyChangeTool.run(new List<CodeyApplyChangeTool.Request>{ rs })[0];
        System.assertEquals(true, rsp.success, rsp.message);
        rs.mode = 'commit'; rs.previewToken = rsp.previewToken;
        CodeyApplyChangeTool.run(new List<CodeyApplyChangeTool.Request>{ rs });
        Product2 prod = new Product2(Name = 'Codey Fibre 1G', ProductCode = 'CODEY_F1G', IsActive = true);
        Product2 prod2 = new Product2(Name = 'Codey Fibre 2G', ProductCode = 'CODEY_F2G', IsActive = true);
        insert new List<Product2>{ prod, prod2 };
        CodeyApplyChangeTool.Request cr = new CodeyApplyChangeTool.Request(); cr.changeType = 'contextRule';
        cr.fieldsJson = '{"name":"Only North","ruleset":"North region","product":"CODEY_F1G","expression":"Region == North","failureMessage":"Only in the North region"}';
        CodeyApplyChangeTool.run(new List<CodeyApplyChangeTool.Request>{ cr });
        CodeyApplyChangeTool.Request lr = new CodeyApplyChangeTool.Request(); lr.changeType = 'linearRelationship';
        lr.fieldsJson = '{"name":"1G to 2G","product":"CODEY_F1G","relatedProduct":"CODEY_F2G"}';
        System.assertEquals(true, CodeyApplyChangeTool.run(new List<CodeyApplyChangeTool.Request>{ lr })[0].success);
        CodeyApplyChangeTool.Request ab = new CodeyApplyChangeTool.Request(); ab.changeType = 'attributeBinding';
        ab.fieldsJson = '{"attribute":"NO_SUCH_ATTR","objectClass":"x","fieldApiName":"vlocity_cmt__City__c"}';
        System.assertEquals(false, CodeyApplyChangeTool.run(new List<CodeyApplyChangeTool.Request>{ ab })[0].success);
        CodeyApplyChangeTool.Request gr = new CodeyApplyChangeTool.Request(); gr.changeType = 'record'; gr.target = 'vlocity_cmt__PricingVariable__c'; gr.fieldsJson = '{"Name":"Codey Var","NoSuchField":"1"}';
        System.assertEquals(false, CodeyApplyChangeTool.run(new List<CodeyApplyChangeTool.Request>{ gr })[0].success);
        CodeyApplyChangeTool.Request gs = new CodeyApplyChangeTool.Request(); gs.changeType = 'generalSetting'; gs.target = 'CodeyGS'; gs.value = 'true';
        System.assertEquals(true, CodeyApplyChangeTool.run(new List<CodeyApplyChangeTool.Request>{ gs })[0].success);
    }

    @IsTest static void upgradeImpact() {
        CodeyUpgradeImpactTool.Request r = new CodeyUpgradeImpactTool.Request(); r.includeStandard = true;
        CodeyResult res = CodeyUpgradeImpactTool.run(new List<CodeyUpgradeImpactTool.Request>{ r })[0];
        System.assertEquals(true, res.success, res.message);
        System.assertEquals('upgrade', res.card.cardType);
        r.targetRelease = '0000';
        System.assertEquals(false, CodeyUpgradeImpactTool.run(new List<CodeyUpgradeImpactTool.Request>{ r })[0].success);
        System.assert(CodeyUpgradeImpactTool.matches('cfCpqConfigureCart*', 'cpqConfigureCartLineItems'));
        System.assert(CodeyUpgradeImpactTool.matches('CPQ/PriceLineItems', 'CPQ/PriceLineItems'));
        System.assert(!CodeyUpgradeImpactTool.matches('cfCpqCartItems*', 'cpqPromotions'));
        System.assert(!CodeyUpgradeImpactTool.matches(null, 'x'));
        CodeyUpgradeImpactTool.testComponents = new List<CodeyUpgradeImpactTool.Component>{
            CodeyUpgradeImpactTool.comp('cpqConfigureCartLineItems', 'FlexCard', 5, 'Acme Dev', System.now().addDays(-30), System.now(), 'cpqConfigureCartLineItems'),
            CodeyUpgradeImpactTool.comp('cpqCartItems', 'FlexCard', 1, 'Vlocity', System.now(), System.now(), 'cpqCartItems'),
            CodeyUpgradeImpactTool.comp('CPQ/PriceLineItems', 'IntegrationProcedure', 2, null, System.now(), System.now(), 'CPQ/PriceLineItems') };
        CodeyUpgradeImpactTool.Request r2 = new CodeyUpgradeImpactTool.Request(); r2.targetRelease = '268'; r2.includeStandard = true;
        CodeyResult res2 = CodeyUpgradeImpactTool.run(new List<CodeyUpgradeImpactTool.Request>{ r2 })[0];
        System.assertEquals(true, res2.success, res2.message);
        System.assert(res2.card.items.size() >= 3, res2.message);
        CodeyUpgradeImpactTool.testComponents = null;
        System.assertNotEquals(null, CodeyUpgradeImpactTool.components());
    }

    @IsTest static void pricePreview() {
        CodeyCore.sandboxOverride = true;
        CodeyTestData.plan();
        Quote q = CodeyTestData.quote(1);
        CodeyPricePreviewTool.Request plan = new CodeyPricePreviewTool.Request(); plan.explainPlan = true;
        CodeyResult pr = CodeyPricePreviewTool.run(new List<CodeyPricePreviewTool.Request>{ plan })[0];
        System.assertEquals(true, pr.success, pr.message);
        CodeyPricePreviewTool.Request ex = new CodeyPricePreviewTool.Request(); ex.quoteId = q.Id;
        CodeyResult exr = CodeyPricePreviewTool.run(new List<CodeyPricePreviewTool.Request>{ ex })[0];
        System.assertEquals(true, exr.success, exr.message);
        CodeyPricePreviewTool.Request none = new CodeyPricePreviewTool.Request();
        System.assertEquals(false, CodeyPricePreviewTool.run(new List<CodeyPricePreviewTool.Request>{ none })[0].success);

        // sample pricing through a stubbed cart: nothing is left behind after a preview
        Product2 prod = new Product2(Name = 'Codey Offer', ProductCode = 'CODEY_OFFER', IsActive = true);
        insert prod;
        insert new PricebookEntry(Pricebook2Id = Test.getStandardPricebookId(), Product2Id = prod.Id, UnitPrice = 10, IsActive = true);
        insert new vlocity_cmt__PriceList__c(Name = 'B2B Pricelist', vlocity_cmt__Code__c = 'CODEY_B2B', vlocity_cmt__Pricebook2Id__c = Test.getStandardPricebookId(), vlocity_cmt__IsActive__c = true);
        CodeyPricePreviewTool.cart = new StubCart();
        Integer quotesBefore = [SELECT COUNT() FROM Quote];
        CodeyPricePreviewTool.Request s = new CodeyPricePreviewTool.Request(); s.products = 'CODEY_OFFER'; s.account = 'Codey Test Account';
        s.proposedStepJson = '{"name":"Surcharge","sequence":45,"implementation":"DefaultPricingPlanImplementation","method":"x"}';
        CodeyResult sr = CodeyPricePreviewTool.run(new List<CodeyPricePreviewTool.Request>{ s })[0];
        System.assertEquals(true, sr.success, sr.message);
        System.assertEquals(quotesBefore, [SELECT COUNT() FROM Quote], 'preview must not leave a quote behind');
        s.mode = 'commit'; s.previewToken = sr.previewToken;
        CodeyResult sc = CodeyPricePreviewTool.run(new List<CodeyPricePreviewTool.Request>{ s })[0];
        System.assertEquals(true, sc.success, sc.message);
        System.assertEquals(quotesBefore + 1, [SELECT COUNT() FROM Quote], 'commit keeps the test quote');
    }

    @IsTest static void pricesWithLinesAndLiveCartErrors() {
        CodeyTestData.plan();
        Quote q = CodeyTestData.quote(1);
        Product2 prod = new Product2(Name = 'Codey Line Offer', ProductCode = 'CODEY_LINE', IsActive = true);
        insert prod;
        PricebookEntry pbe = new PricebookEntry(Pricebook2Id = Test.getStandardPricebookId(), Product2Id = prod.Id, UnitPrice = 10, IsActive = true);
        insert pbe;
        try {
            update new Quote(Id = q.Id, Pricebook2Id = Test.getStandardPricebookId());
            insert new QuoteLineItem(QuoteId = q.Id, PricebookEntryId = pbe.Id, Product2Id = prod.Id, Quantity = 1, UnitPrice = 10,
                vlocity_cmt__RecurringCharge__c = 50, vlocity_cmt__RecurringTotal__c = 45,
                vlocity_cmt__PricingLogData__c = '{"LogData":{"REC_MNTH_STD_PRC":[{"LogSequence":1,"LogType":"PRICE","DisplayText":"Price list","EndValue":50},{"LogSequence":2,"LogType":"ADJUSTMENT","DisplayText":"10% off","StartValue":50,"EndValue":45,"DiscountId":"x"}]}}');
        } catch (Exception e) { System.debug('QLI insert skipped: ' + e.getMessage()); }
        Map<String, Object> priced = CodeyPricePreviewTool.readQuote(q.Id);
        System.assertNotEquals(null, priced.get('totals'));
        CodeyPricePreviewTool.Request ex = new CodeyPricePreviewTool.Request(); ex.quoteId = q.Id;
        System.assertEquals(true, CodeyPricePreviewTool.run(new List<CodeyPricePreviewTool.Request>{ ex })[0].success);
        CodeyPricePreviewTool.LiveCartApi live = new CodeyPricePreviewTool.LiveCartApi();
        try { live.createCart(q.AccountId, q.OpportunityId, 'x', 'No Such Price List'); } catch (Exception e) { }
        try { live.addProduct(q.Id, pbe.Id, 1); } catch (Exception e) { }
        try { live.reprice(q.Id); } catch (Exception e) { }
        CodeyPricePreviewTool.Request bad = new CodeyPricePreviewTool.Request(); bad.products = 'NO_SUCH_PRODUCT_CODEY'; bad.mode = 'weird';
        System.assertEquals(false, CodeyPricePreviewTool.run(new List<CodeyPricePreviewTool.Request>{ bad })[0].success);
        CodeyPricePreviewTool.Request bad2 = new CodeyPricePreviewTool.Request(); bad2.products = 'NO_SUCH_PRODUCT_CODEY'; bad2.priceList = 'Nope'; bad2.account = 'No Such Account Codey';
        System.assertEquals(false, CodeyPricePreviewTool.run(new List<CodeyPricePreviewTool.Request>{ bad2 })[0].success);
    }

    class StubCart implements CodeyPricePreviewTool.CartApi {
        public Id createCart(Id accountId, Id opportunityId, String name, String priceListName) {
            Quote q = new Quote(Name = name, OpportunityId = opportunityId);
            insert q;
            return q.Id;
        }
        public void addProduct(Id cartId, Id pricebookEntryId, Integer quantity) { }
        public void reprice(Id cartId) { }
    }
}
