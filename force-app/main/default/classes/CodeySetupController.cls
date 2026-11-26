/** Backs the Codey Setup Lightning page: health check and upgrade impact cards, recent Codey activity. Read-only. */
public with sharing class CodeySetupController {

    @AuraEnabled
    public static Map<String, Object> healthCheck(String scope) {
        CodeyHealthCheckTool.Request r = new CodeyHealthCheckTool.Request();
        r.scope = scope; r.surface = 'Lightning';
        return toMap(CodeyHealthCheckTool.run(new List<CodeyHealthCheckTool.Request>{ r })[0]);
    }

    @AuraEnabled
    public static Map<String, Object> upgradeImpact(String targetRelease) {
        CodeyUpgradeImpactTool.Request r = new CodeyUpgradeImpactTool.Request();
        r.targetRelease = targetRelease; r.surface = 'Lightning';
        return toMap(CodeyUpgradeImpactTool.run(new List<CodeyUpgradeImpactTool.Request>{ r })[0]);
    }

    @AuraEnabled
    public static Map<String, Object> recent() {
        List<Map<String, Object>> logs = new List<Map<String, Object>>();
        for (Codey_Change_Log__c l : [SELECT Id, Name, Tool__c, Change_Type__c, Target__c, Status__c, Surface__c, CreatedBy.Name, CreatedDate FROM Codey_Change_Log__c ORDER BY CreatedDate DESC LIMIT 25]) {
            logs.add(new Map<String, Object>{ 'id' => l.Id, 'name' => l.Name, 'tool' => l.Tool__c, 'type' => l.Change_Type__c, 'target' => l.Target__c, 'status' => l.Status__c,
                'surface' => l.Surface__c, 'by' => l.CreatedBy.Name, 'at' => l.CreatedDate.format('yyyy-MM-dd HH:mm') });
        }
        List<Map<String, Object>> jobs = new List<Map<String, Object>>();
        for (Codey_Job__c j : [SELECT Id, Name, Tool__c, Status__c, Step__c, Total__c, Done__c, CreatedDate FROM Codey_Job__c ORDER BY CreatedDate DESC LIMIT 10]) {
            jobs.add(new Map<String, Object>{ 'id' => j.Id, 'name' => j.Name, 'tool' => j.Tool__c, 'status' => j.Status__c, 'step' => j.Step__c,
                'progress' => (j.Total__c == null || j.Total__c == 0 ? 0 : (100 * (j.Done__c == null ? 0 : j.Done__c) / j.Total__c).setScale(0)) + '%', 'at' => j.CreatedDate.format('yyyy-MM-dd HH:mm') });
        }
        return new Map<String, Object>{ 'logs' => logs, 'jobs' => jobs };
    }

    static Map<String, Object> toMap(CodeyResult r) {
        return (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(r));
    }
}
