/**
 * Address verification and serviceability providers for Codey bulk member checks (Codey_Check_Provider__mdt):
 *   Builtin              - address completeness and postal-code format per country; serviceability from data already on the member
 *   IntegrationProcedure - the ESM Integration Procedures (default ESM_checkAddressValidation / ESM_checkServiceQualificationV2) that call
 *                          the customer's address and qualification services, then reads the results from the members
 *   ApexClass            - any class implementing CodeyBulkCheck.Provider (other orgs plug in their own service)
 */
public with sharing class CodeyBulkCheck {

    public interface Provider {
        List<Result> check(Id quoteId, List<Id> memberIds, Boolean doAddress, Boolean doService);
    }

    public class Result {
        public Id memberId; public String name; public String address;
        public String addressStatus; public String addressMessage;
        public String serviceable; public String technology; public String maxDownload; public String reason;
        public Boolean failed = false;
    }

    public class Config {
        public String mode = 'Builtin'; public String addressIp; public String serviceIp; public String serviceName; public String apexClass;
        public Integer batchSize = 200; public Boolean writeBack = true;
    }

    public static Config config() {
        Config c = new Config();
        List<Codey_Check_Provider__mdt> ps = [SELECT Mode__c, Address_IP__c, Serviceability_IP__c, Service_Name__c, Apex_Class__c, Batch_Size__c, Write_Back__c
                                              FROM Codey_Check_Provider__mdt WHERE Active__c = true ORDER BY DeveloperName LIMIT 1];
        if (!ps.isEmpty()) {
            Codey_Check_Provider__mdt p = ps[0];
            c.mode = String.isBlank(p.Mode__c) ? 'Builtin' : p.Mode__c;
            c.addressIp = p.Address_IP__c; c.serviceIp = p.Serviceability_IP__c; c.serviceName = p.Service_Name__c; c.apexClass = p.Apex_Class__c;
            c.batchSize = p.Batch_Size__c == null ? 200 : p.Batch_Size__c.intValue();
            c.writeBack = p.Write_Back__c;
        }
        return c;
    }

    @TestVisible static Provider providerOverride;

    public static Provider provider(Config c) {
        if (providerOverride != null) return providerOverride;
        if (c.mode == 'IntegrationProcedure') return new IpProvider(c);
        if (c.mode == 'ApexClass') {
            Type t = Type.forName(c.apexClass);
            if (t == null) throw new CodeyCore.ToolException('Check provider class ' + c.apexClass + ' not found.');
            return (Provider) t.newInstance();
        }
        return new BuiltinProvider(c);
    }

    // ------------------------------------------------------------------ Builtin
    static final Map<String, String> POSTAL_FORMATS = new Map<String, String>{
        'US' => '^\\d{5}(-\\d{4})?$', 'GB' => '^[A-Z]{1,2}\\d[A-Z\\d]? ?\\d[A-Z]{2}$', 'UK' => '^[A-Z]{1,2}\\d[A-Z\\d]? ?\\d[A-Z]{2}$', 'CA' => '^[A-Z]\\d[A-Z] ?\\d[A-Z]\\d$',
        'DE' => '^\\d{5}$', 'FR' => '^\\d{5}$', 'ES' => '^\\d{5}$', 'IT' => '^\\d{5}$', 'NL' => '^\\d{4} ?[A-Z]{2}$', 'BE' => '^\\d{4}$', 'AU' => '^\\d{4}$',
        'IN' => '^\\d{6}$', 'IE' => '^[A-Z]\\d{2} ?[A-Z\\d]{4}$', 'JP' => '^\\d{3}-?\\d{4}$', 'BR' => '^\\d{5}-?\\d{3}$', 'SE' => '^\\d{3} ?\\d{2}$', 'CH' => '^\\d{4}$', 'AT' => '^\\d{4}$' };
    static final Map<String, String> COUNTRY_CODES = new Map<String, String>{
        'united states' => 'US', 'usa' => 'US', 'united states of america' => 'US', 'united kingdom' => 'GB', 'great britain' => 'GB', 'england' => 'GB', 'scotland' => 'GB', 'wales' => 'GB',
        'canada' => 'CA', 'germany' => 'DE', 'deutschland' => 'DE', 'france' => 'FR', 'spain' => 'ES', 'italy' => 'IT', 'netherlands' => 'NL', 'belgium' => 'BE', 'australia' => 'AU',
        'india' => 'IN', 'ireland' => 'IE', 'japan' => 'JP', 'brazil' => 'BR', 'sweden' => 'SE', 'switzerland' => 'CH', 'austria' => 'AT' };

    public static String countryCode(String c) {
        if (String.isBlank(c)) return null;
        String v = c.trim();
        if (v.length() == 2) return v.toUpperCase();
        return COUNTRY_CODES.get(v.toLowerCase());
    }

    /** Address quality without an external service: Valid / Partial / Invalid with the reason. */
    public static List<String> addressCheck(String street, String city, String state, String postal, String country) {
        List<String> missing = new List<String>();
        if (String.isBlank(street)) missing.add('street');
        if (String.isBlank(city) && String.isBlank(postal)) missing.add('city or postal code');
        if (!missing.isEmpty()) return new List<String>{ 'Invalid', 'Missing ' + String.join(missing, ' and ') };
        String cc = countryCode(country);
        if (String.isNotBlank(postal) && cc != null && POSTAL_FORMATS.containsKey(cc) && !Pattern.matches(POSTAL_FORMATS.get(cc), postal.trim().toUpperCase())) {
            return new List<String>{ 'Invalid', 'Postal code "' + postal + '" is not a valid ' + cc + ' format' };
        }
        List<String> soft = new List<String>();
        if (String.isBlank(postal)) soft.add('postal code');
        if (String.isBlank(city)) soft.add('city');
        if (String.isBlank(country)) soft.add('country');
        else if (cc == null) soft.add('a recognised country');
        if (!soft.isEmpty()) return new List<String>{ 'Partial', 'Missing ' + String.join(soft, ', ') };
        return new List<String>{ 'Valid', 'Complete address' };
    }

    public class BuiltinProvider implements Provider {
        Config c;
        public BuiltinProvider(Config c) { this.c = c; }
        public List<Result> check(Id quoteId, List<Id> memberIds, Boolean doAddress, Boolean doService) {
            List<Result> out = new List<Result>();
            for (vlocity_cmt__QuoteMember__c m : members(memberIds)) {
                Result r = base(m);
                if (doAddress) {
                    List<String> a = addressCheck(m.vlocity_cmt__StreetAddress__c, m.vlocity_cmt__City__c, m.vlocity_cmt__State__c, m.vlocity_cmt__PostalCode__c, m.vlocity_cmt__Country__c);
                    r.addressStatus = a[0]; r.addressMessage = a[1];
                }
                if (doService) readService(m, r, 'No serviceability service configured (Codey provider Builtin); set the provider to IntegrationProcedure to call your qualification service.');
                if (r.addressStatus == 'Invalid') r.reason = r.addressMessage;
                out.add(r);
            }
            return out;
        }
    }

    public class IpProvider implements Provider {
        Config c;
        public IpProvider(Config c) { this.c = c; }
        public List<Result> check(Id quoteId, List<Id> memberIds, Boolean doAddress, Boolean doService) {
            List<String> ids = new List<String>();
            for (Id i : memberIds) ids.add(i);
            if (doAddress && String.isNotBlank(c.addressIp)) runIp(c.addressIp, new Map<String, Object>{ 'QuotememberIds' => ids, 'QuoteId' => String.valueOf(quoteId) });
            if (doService && String.isNotBlank(c.serviceIp)) runIp(c.serviceIp, new Map<String, Object>{ 'ObjectType' => 'Quote', 'QuoteId' => String.valueOf(quoteId), 'QuotememberIds' => ids, 'SelectedServiceName' => c.serviceName });
            List<Result> out = new List<Result>();
            for (vlocity_cmt__QuoteMember__c m : members(memberIds)) {
                Result r = base(m);
                r.addressStatus = m.vlocity_cmt__AddressValidationResult__c;
                r.addressMessage = m.vlocity_cmt__AddressValidationMessage__c;
                if (doService) readService(m, r, 'The qualification service returned no result for this member.');
                if (r.addressStatus == 'Invalid' || r.addressStatus == 'Fails') r.reason = r.addressMessage;
                out.add(r);
            }
            return out;
        }
        void runIp(String name, Map<String, Object> input) {
            Object res = vlocity_cmt.IntegrationProcedureService.runIntegrationService(name, input, new Map<String, Object>());
            if (res instanceof Map<String, Object> && ((Map<String, Object>) res).get('success') == false) {
                throw new CodeyCore.ToolException(name + ' failed: ' + String.valueOf(((Map<String, Object>) res).get('result')).left(300));
            }
        }
    }

    static List<vlocity_cmt__QuoteMember__c> members(List<Id> ids) {
        return [SELECT Id, Name, vlocity_cmt__StreetAddress__c, vlocity_cmt__City__c, vlocity_cmt__State__c, vlocity_cmt__PostalCode__c, vlocity_cmt__Country__c,
                vlocity_cmt__AddressValidationResult__c, vlocity_cmt__AddressValidationMessage__c, vlocity_cmt__ServiceabilityData__c,
                vlocity_cmt__BroadbandConnectionType__c, vlocity_cmt__MaxDownloadSpeed__c
                FROM vlocity_cmt__QuoteMember__c WHERE Id IN :ids ORDER BY Id];
    }

    static Result base(vlocity_cmt__QuoteMember__c m) {
        Result r = new Result();
        r.memberId = m.Id; r.name = m.Name;
        List<String> parts = new List<String>();
        for (String p : new List<String>{ m.vlocity_cmt__StreetAddress__c, m.vlocity_cmt__City__c, m.vlocity_cmt__State__c, m.vlocity_cmt__PostalCode__c, m.vlocity_cmt__Country__c }) if (String.isNotBlank(p)) parts.add(p);
        r.address = String.join(parts, ', ');
        return r;
    }

    /** Reads the TMF-style serviceability payload ESM stores on the member. */
    static void readService(vlocity_cmt__QuoteMember__c m, Result r, String noData) {
        r.technology = m.vlocity_cmt__BroadbandConnectionType__c;
        r.maxDownload = m.vlocity_cmt__MaxDownloadSpeed__c;
        if (String.isBlank(m.vlocity_cmt__ServiceabilityData__c)) { r.serviceable = 'Unknown'; if (r.reason == null) r.reason = noData; return; }
        try {
            Map<String, Object> p = (Map<String, Object>) JSON.deserializeUntyped(m.vlocity_cmt__ServiceabilityData__c);
            List<Object> items = (List<Object>) p.get('serviceQualificationItem');
            Boolean anyQualified = false;
            List<String> reasons = new List<String>();
            for (Object o : items == null ? new List<Object>() : items) {
                Map<String, Object> it = (Map<String, Object>) o;
                if (it.get('qualificationResult') == 'qualified') anyQualified = true;
                Object rs = it.get('eligibilityUnavailabilityReason');
                if (rs instanceof List<Object>) for (Object x : (List<Object>) rs) if (x instanceof Map<String, Object>) reasons.add(String.valueOf(((Map<String, Object>) x).get('label')));
            }
            r.serviceable = anyQualified ? 'Yes' : 'No';
            if (!anyQualified && r.reason == null) r.reason = reasons.isEmpty() ? 'Not serviceable' : String.join(reasons, '; ');
        } catch (Exception e) {
            r.serviceable = 'Unknown';
            if (r.reason == null) r.reason = 'Serviceability data could not be read';
        }
    }
}
