/**
 * Secure entry of secrets for Codey setup (Google Maps key) from the "Codey Setup" page - never through chat or agent tools.
 * The value is written straight to the CPQ setting named in the Recommended settings pack (key Q_GOOGLE_MAPS) and only
 * "set / not set" is ever shown or logged. Needs the Codey_Admin custom permission.
 */
public with sharing class CodeySecureSettingController {

    public static final String MAPS_RULE = 'Q_GOOGLE_MAPS';

    @AuraEnabled(cacheable=false)
    public static Map<String, Object> status() {
        String target = settingName();
        String v = CodeyCore.cpqValue(target);
        return new Map<String, Object>{ 'setting' => target, 'isSet' => String.isNotBlank(v) && v != 'None', 'canEdit' => FeatureManagement.checkPermission('Codey_Admin'), 'isSandbox' => CodeyCore.isSandbox() };
    }

    @AuraEnabled
    public static Map<String, Object> saveGoogleMapsKey(String value) {
        if (!FeatureManagement.checkPermission('Codey_Admin')) throw new AuraHandledException('You need the ESM Codey Admin permission set to enter keys.');
        if (String.isBlank(value) || value.trim().length() < 10) throw new AuraHandledException('Enter the full key.');
        String target = settingName();
        List<vlocity_cmt__CpqConfigurationSetup__c> rows = [SELECT Id, vlocity_cmt__SetupValue__c FROM vlocity_cmt__CpqConfigurationSetup__c WHERE Name = :target LIMIT 1];
        Boolean wasSet = !rows.isEmpty() && String.isNotBlank(rows[0].vlocity_cmt__SetupValue__c) && rows[0].vlocity_cmt__SetupValue__c != 'None';
        vlocity_cmt__CpqConfigurationSetup__c rec = rows.isEmpty() ? new vlocity_cmt__CpqConfigurationSetup__c(Name = target) : rows[0];
        rec.vlocity_cmt__SetupValue__c = value.trim();
        if (rec.Id == null) Database.insert(rec, true, AccessLevel.USER_MODE); else Database.update(rec, true, AccessLevel.USER_MODE);
        insert new Codey_Change_Log__c(Tool__c = 'codey_setup_page', Change_Type__c = 'secureSetting', Target__c = target, Status__c = 'Committed',
            Committed_At__c = System.now(), Approved_By__c = UserInfo.getUserId(), Before_JSON__c = wasSet ? '"set"' : '"not set"', After_JSON__c = '"set"',
            Record_Ids__c = rec.Id, Is_Production__c = !CodeyCore.isSandbox(), Surface__c = 'Lightning');
        CodeyCore.resetCaches();
        return status();
    }

    static String settingName() {
        List<Codey_Recommended_Setting__mdt> s = [SELECT Target__c FROM Codey_Recommended_Setting__mdt WHERE DeveloperName = :MAPS_RULE LIMIT 1];
        return s.isEmpty() || String.isBlank(s[0].Target__c) ? 'GoogleMapsAPIKey' : s[0].Target__c;
    }
}
