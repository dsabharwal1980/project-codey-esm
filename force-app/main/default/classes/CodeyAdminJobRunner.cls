/**
 * Runs the ESM admin jobs of a Codey_Job__c one after another, in the documented order.
 * Each run: checks the running step's Apex job; when it finished, starts the next pending step; then re-queues itself
 * (one-minute delay) until every step is done. A failed step stops the chain (later jobs depend on earlier ones) and
 * keeps the finished ones, so "Resume" restarts from the failed step only. Manual steps are left for the person.
 */
public with sharing class CodeyAdminJobRunner implements Queueable {

    @TestVisible static Boolean chain = !Test.isRunningTest();
    @TestVisible static Starter starter = new LiveStarter();
    final Id jobId;

    public CodeyAdminJobRunner(Id jobId) { this.jobId = jobId; }

    public static void enqueue(Id jobId, Integer delayMinutes) {
        if (delayMinutes == null || delayMinutes <= 0) System.enqueueJob(new CodeyAdminJobRunner(jobId));
        else System.enqueueJob(new CodeyAdminJobRunner(jobId), delayMinutes);
    }

    public void execute(QueueableContext ctx) {
        Codey_Job__c job = [SELECT Id, Name, Status__c, Steps_JSON__c, Total__c, Done__c, Failed__c, Message__c, Cursor__c FROM Codey_Job__c WHERE Id = :jobId FOR UPDATE];
        if (job.Status__c == 'Completed' || job.Status__c == 'Cancelled' || job.Status__c == 'Failed') return;
        Boolean again = step(job);
        update job;
        if (again && chain) enqueue(job.Id, 1);
    }

    /** One pass. Returns true when the runner must look again later. */
    public static Boolean step(Codey_Job__c job) {
        List<Map<String, Object>> steps = new List<Map<String, Object>>();
        for (Object o : (List<Object>) JSON.deserializeUntyped(job.Steps_JSON__c)) steps.add((Map<String, Object>) o);
        job.Status__c = 'Running';

        // 1. a step is running: is its Apex job finished?
        for (Map<String, Object> s : steps) {
            if (s.get('status') != 'Running') continue;
            String aj = (String) s.get('apexJobId');
            if (String.isBlank(aj)) aj = findStartedJob(s);
            if (String.isBlank(aj)) {
                if (minutesSince(s) > 10) { s.put('status', 'Completed'); s.put('detail', 'Started; no background job reported (the package ran it directly).'); }
                else { save(job, steps); return true; }
            } else {
                s.put('apexJobId', aj);
                List<AsyncApexJob> a = [SELECT Status, NumberOfErrors, JobItemsProcessed, TotalJobItems, ExtendedStatus FROM AsyncApexJob WHERE Id = :aj LIMIT 1];
                if (a.isEmpty()) { save(job, steps); return true; }
                AsyncApexJob x = a[0];
                Decimal pct = x.TotalJobItems == null || x.TotalJobItems == 0 ? 0 : (100.0 * x.JobItemsProcessed / x.TotalJobItems);
                s.put('percent', pct.setScale(0));
                if (x.Status == 'Completed' && (x.NumberOfErrors == null || x.NumberOfErrors == 0)) {
                    s.put('status', 'Completed'); s.put('percent', 100); s.put('detail', 'Finished (' + x.TotalJobItems + ' batches).');
                } else if (x.Status == 'Completed' || x.Status == 'Failed' || x.Status == 'Aborted') {
                    s.put('status', 'Failed');
                    s.put('error', plain(x.ExtendedStatus, x.Status, x.NumberOfErrors));
                    s.put('detail', String.valueOf(s.get('error')));
                    job.Status__c = 'Failed';
                    job.Cursor__c = String.valueOf(s.get('key'));
                    job.Message__c = s.get('label') + ' failed: ' + s.get('error') + ' Finished steps are kept; Resume restarts from this step.';
                    save(job, steps);
                    return false;
                } else {
                    s.put('detail', x.Status + ' · ' + x.JobItemsProcessed + ' of ' + x.TotalJobItems + ' batches');
                    save(job, steps);
                    return true;
                }
            }
        }

        // 2. start the next pending step (documented order)
        for (Map<String, Object> s : steps) {
            if (s.get('status') != 'Pending') continue;
            try {
                s.put('startedAt', System.now().getTime());
                Id aj = starter.start(String.valueOf(s.get('className')), String.valueOf(s.get('mode')), s.get('batchSize') == null ? 200 : Integer.valueOf(s.get('batchSize')), (String) s.get('arg'));
                s.put('status', 'Running');
                if (aj != null) s.put('apexJobId', aj);
                s.put('detail', 'Started');
                job.Step__c = String.valueOf(s.get('label'));
            } catch (Exception e) {
                s.put('status', 'Failed');
                s.put('error', plain(e.getMessage(), 'Not started', null));
                s.put('detail', String.valueOf(s.get('error')));
                job.Status__c = 'Failed';
                job.Cursor__c = String.valueOf(s.get('key'));
                job.Message__c = s.get('label') + ' could not start: ' + s.get('error');
                save(job, steps);
                return false;
            }
            save(job, steps);
            return true;
        }

        // 3. nothing left to run
        Integer manual = 0;
        for (Map<String, Object> s : steps) if (s.get('status') == 'Manual') manual++;
        job.Status__c = 'Completed';
        job.Step__c = 'Done';
        job.Message__c = 'All automatic admin jobs finished.' + (manual > 0 ? ' ' + manual + ' manual step(s) to do in CMT Administration (see the steps).' : '');
        save(job, steps);
        return false;
    }

    static void save(Codey_Job__c job, List<Map<String, Object>> steps) {
        Integer done = 0, failed = 0;
        for (Map<String, Object> s : steps) { if (s.get('status') == 'Completed') done++; if (s.get('status') == 'Failed') failed++; }
        job.Done__c = done; job.Failed__c = failed; job.Total__c = steps.size();
        job.Steps_JSON__c = JSON.serialize(steps);
    }

    static Long minutesSince(Map<String, Object> s) {
        Object t = s.get('startedAt');
        return t == null ? 999 : (System.now().getTime() - Long.valueOf(String.valueOf(t))) / 60000;
    }

    /** Service-style jobs (the package starts its own batch): find the batch it started. */
    static String findStartedJob(Map<String, Object> s) {
        Object t = s.get('startedAt');
        if (t == null) return null;
        Datetime since = Datetime.newInstance(Long.valueOf(String.valueOf(t))).addSeconds(-5);
        List<AsyncApexJob> js = [SELECT Id FROM AsyncApexJob WHERE CreatedDate >= :since AND CreatedById = :UserInfo.getUserId()
                                 AND ApexClass.NamespacePrefix = 'vlocity_cmt' AND JobType = 'BatchApex' ORDER BY CreatedDate ASC LIMIT 1];
        return js.isEmpty() ? null : js[0].Id;
    }

    /** Plain words for common failures. */
    public static String plain(String raw, String status, Integer errors) {
        String m = raw == null ? '' : raw;
        String l = m.toLowerCase();
        if (l.contains('cpu time')) return 'The job ran out of processing time for a batch. Lower the batch size in the Codey admin job settings and resume.';
        if (l.contains('heap')) return 'A batch used too much memory (large product hierarchies). Lower the batch size and resume.';
        if (l.contains('unable_to_lock_row')) return 'Records were locked by another process. Resume in a few minutes.';
        if (l.contains('insufficient') || l.contains('access')) return 'The user running the jobs is missing access (CMT admin permission set). Assign it and resume.';
        if (l.contains('already') && l.contains('running')) return 'The same job is already running (started elsewhere). Wait for it, then resume.';
        if (String.isBlank(m)) return 'The job ended with status ' + status + (errors == null ? '' : ' and ' + errors + ' failed batches') + '. See Setup → Apex Jobs for details, then resume.';
        return m.left(400);
    }

    public interface Starter { Id start(String className, String mode, Integer batchSize, String arg); }

    /** Starts the CMT jobs through their global classes. */
    public class LiveStarter implements Starter {
        public Id start(String className, String mode, Integer batchSize, String arg) {
            String c = className == null ? '' : className.trim();
            Integer size = batchSize == null || batchSize <= 0 ? 200 : batchSize;
            if (mode == 'service' && c == 'vlocity_cmt.CMTAdminJobService.startProductHierarchyMaintenanceJob') {
                vlocity_cmt.CMTAdminJobService.startProductHierarchyMaintenanceJob(null);
                return null;
            }
            if (c == 'vlocity_cmt.UpdateAllProdAttribJSONBatchJob') return Database.executeBatch(new vlocity_cmt.UpdateAllProdAttribJSONBatchJob(), size);
            if (c == 'vlocity_cmt.FixProductAttribJSONBatchJob') return Database.executeBatch(new vlocity_cmt.FixProductAttribJSONBatchJob(), size);
            if (c == 'vlocity_cmt.ProductAttributesCacheBatchJob') return Database.executeBatch(new vlocity_cmt.ProductAttributesCacheBatchJob(), size);
            if (c == 'vlocity_cmt.PromotionExpirationBatch') return Database.executeBatch(new vlocity_cmt.PromotionExpirationBatch(), size);
            if (c == 'vlocity_cmt.UpdateAttributeConfigurableBatchJob') return Database.executeBatch(new vlocity_cmt.UpdateAttributeConfigurableBatchJob(Datetime.newInstance(2000, 1, 1)), size);
            // any other global batch class with a no-argument constructor (e.g. added to the Codey admin job settings for a new release)
            List<String> p = c.split('\\.');
            Type t = p.size() == 2 ? Type.forName(p[0], p[1]) : Type.forName(c);
            if (t == null) throw new CodeyCore.ToolException('Job class ' + c + ' not found or not global.');
            Object o = t.newInstance();
            if (o instanceof Database.Batchable<SObject>) return Database.executeBatch((Database.Batchable<SObject>) o, size);
            if (o instanceof Queueable) return System.enqueueJob((Queueable) o);
            throw new CodeyCore.ToolException('Job class ' + c + ' is not a batch or queueable job.');
        }
    }
}
