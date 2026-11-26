/** Test data for Project Codey tests. */
@IsTest
public class CodeyTestData {
    public static Quote quote(Integer members) {
        Account a = new Account(Name = 'Codey Test Account');
        insert a;
        Opportunity o = new Opportunity(Name = 'Codey Test Opp', AccountId = a.Id, CloseDate = Date.today().addDays(10), StageName = firstStage());
        insert o;
        Quote q = new Quote(Name = 'Codey Test Quote 1', OpportunityId = o.Id);
        insert q;
        List<vlocity_cmt__QuoteMember__c> ms = new List<vlocity_cmt__QuoteMember__c>();
        for (Integer i = 0; i < members; i++) {
            ms.add(new vlocity_cmt__QuoteMember__c(Name = 'Site ' + i, vlocity_cmt__QuoteId__c = q.Id, vlocity_cmt__StreetAddress__c = i + ' Main St',
                vlocity_cmt__City__c = 'Springfield', vlocity_cmt__PostalCode__c = '1234' + Math.mod(i, 10), vlocity_cmt__Country__c = 'US'));
        }
        insert ms;
        return q;
    }

    public static String firstStage() {
        for (Schema.PicklistEntry e : Opportunity.StageName.getDescribe().getPicklistValues()) if (e.isActive()) return e.getValue();
        return 'Prospecting';
    }

    public static vlocity_cmt__CpqConfigurationSetup__c setting(String name, String value) {
        vlocity_cmt__CpqConfigurationSetup__c s = new vlocity_cmt__CpqConfigurationSetup__c(Name = name, vlocity_cmt__SetupValue__c = value);
        insert s;
        CodeyCore.resetCaches();
        return s;
    }

    public static Id plan() {
        vlocity_cmt__PricingPlan__c p = new vlocity_cmt__PricingPlan__c(Name = 'DEFAULT_PRICING_PLAN', vlocity_cmt__Code__c = 'DEFAULT_PRICING_PLAN', vlocity_cmt__IsActive__c = true);
        insert p;
        insert new vlocity_cmt__PricingPlanStep__c(Name = 'Load Price List Entries', vlocity_cmt__PricingPlanId__c = p.Id, vlocity_cmt__Sequence__c = 20,
            vlocity_cmt__ImplementationName__c = 'DefaultPricingPlanImplementation', vlocity_cmt__MethodName__c = 'loadPriceListEntries', vlocity_cmt__IsActive__c = true);
        setting('DefaultPricingPlan', 'DEFAULT_PRICING_PLAN');
        return p.Id;
    }

    /** Approves a preview the way a person would: same inputs, token from the preview. */
    public static String token(CodeyResult preview) {
        System.assertEquals(true, preview.success, preview.message);
        System.assertNotEquals(null, preview.previewToken, 'preview must return a token');
        return preview.previewToken;
    }
}
