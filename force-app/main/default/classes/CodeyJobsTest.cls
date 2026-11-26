@IsTest
private class CodeyJobsTest {

    class StubStarter implements CodeyAdminJobRunner.Starter {
        public Integer calls = 0;
        public Id start(String className, String mode, Integer batchSize, String arg) { calls++; if (className != null && className.contains('Fix')) throw new CodeyCore.ToolException('boom'); return null; }
    }

    @IsTest static void adminJobsPreviewCommitRunAndResume() {
        CodeyCore.sandboxOverride = true;
        CodeyAdminJobRunner.starter = new StubStarter();
        CodeyAdminJobsTool.Request r = new CodeyAdminJobsTool.Request(); r.jobs = 'default';
        CodeyResult p = CodeyAdminJobsTool.run(new List<CodeyAdminJobsTool.Request>{ r })[0];
        System.assertEquals(true, p.success, p.message);
        r.mode = 'commit'; r.previewToken = p.previewToken;
        Test.startTest();
        CodeyResult c = CodeyAdminJobsTool.run(new List<CodeyAdminJobsTool.Request>{ r })[0];
        Test.stopTest();
        System.assertEquals(true, c.success, c.message);
        Codey_Job__c job = [SELECT Id, Name, Status__c, Steps_JSON__c, Total__c, Done__c, Failed__c, Message__c, Cursor__c FROM Codey_Job__c WHERE Id = :c.jobId];
        // drive the chain by hand (no queue chaining in tests): started steps finish after 10 minutes without an Apex job
        for (Integer i = 0; i < 30 && job.Status__c != 'Completed' && job.Status__c != 'Failed'; i++) {
            List<Object> steps = (List<Object>) JSON.deserializeUntyped(job.Steps_JSON__c);
            for (Object o : steps) { Map<String, Object> s = (Map<String, Object>) o; if (s.get('status') == 'Running') s.put('startedAt', System.now().addMinutes(-11).getTime()); }
            job.Steps_JSON__c = JSON.serialize(steps);
            CodeyAdminJobRunner.step(job);
        }
        System.assertEquals('Completed', job.Status__c, job.Message__c);
        update job;
        // status through both tools
        CodeyAdminJobsTool.Request st = new CodeyAdminJobsTool.Request(); st.mode = 'status'; st.jobId = job.Id;
        System.assertEquals(true, CodeyAdminJobsTool.run(new List<CodeyAdminJobsTool.Request>{ st })[0].success);
        CodeyTrackJobTool.Request tr = new CodeyTrackJobTool.Request(); tr.jobId = job.Name;
        System.assertEquals(true, CodeyTrackJobTool.run(new List<CodeyTrackJobTool.Request>{ tr })[0].success);
        CodeyTrackJobTool.Request tr2 = new CodeyTrackJobTool.Request(); tr2.tool = CodeyAdminJobsTool.TOOL;
        System.assertEquals(true, CodeyTrackJobTool.run(new List<CodeyTrackJobTool.Request>{ tr2 })[0].success);
        CodeyTrackJobTool.Request tr3 = new CodeyTrackJobTool.Request(); tr3.jobId = 'CJ-999999';
        System.assertEquals(false, CodeyTrackJobTool.run(new List<CodeyTrackJobTool.Request>{ tr3 })[0].success);

        // a failing step stops the chain; resume restarts from it
        Codey_Job__c f = new Codey_Job__c(Tool__c = CodeyAdminJobsTool.TOOL, Status__c = 'Running', Total__c = 1, Done__c = 0,
            Steps_JSON__c = JSON.serialize(CodeyAdminJobsTool.steps('repair')));
        insert f;
        CodeyAdminJobRunner.step(f);
        System.assertEquals('Failed', f.Status__c);
        update f;
        CodeyAdminJobsTool.Request rs = new CodeyAdminJobsTool.Request(); rs.jobs = 'repair'; rs.jobId = f.Id;
        CodeyResult rp = CodeyAdminJobsTool.run(new List<CodeyAdminJobsTool.Request>{ rs })[0];
        System.assertEquals(true, rp.success, rp.message);
        rs.mode = 'commit'; rs.previewToken = rp.previewToken;
        CodeyResult rc = CodeyAdminJobsTool.run(new List<CodeyAdminJobsTool.Request>{ rs })[0];
        System.assertEquals(true, rc.success, rc.message);
        update new Codey_Job__c(Id = f.Id, Status__c = 'Completed');
        // unknown job key
        CodeyAdminJobsTool.Request bad = new CodeyAdminJobsTool.Request(); bad.jobs = 'nope';
        System.assertEquals(false, CodeyAdminJobsTool.run(new List<CodeyAdminJobsTool.Request>{ bad })[0].success);
        for (String m : new List<String>{ 'Apex CPU time limit exceeded', 'heap size', 'UNABLE_TO_LOCK_ROW', 'insufficient access', 'already running', null, 'other' }) {
            System.assertNotEquals(null, CodeyAdminJobRunner.plain(m, 'Failed', 1));
        }
    }

    @IsTest static void runnerQueueable() {
        CodeyAdminJobRunner.starter = new StubStarter();
        Codey_Job__c j = new Codey_Job__c(Tool__c = CodeyAdminJobsTool.TOOL, Status__c = 'Queued', Total__c = 1, Done__c = 0, Steps_JSON__c = JSON.serialize(CodeyAdminJobsTool.steps('catalog')));
        insert j;
        Test.startTest();
        CodeyAdminJobRunner.enqueue(j.Id, 0);
        Test.stopTest();
        System.assertEquals('Running', [SELECT Status__c FROM Codey_Job__c WHERE Id = :j.Id].Status__c);
    }

    @IsTest static void bulkPreviewLoadAndCheck() {
        CodeyCore.sandboxOverride = true;
        Quote q = CodeyTestData.quote(2);
        String csv = 'Site,Address,City,Postcode,Country\nNew A,10 Elm St,Austin,78701,US\nNew B,11 Elm St,Austin,78702,US\nBad,,Austin,,US\nSite 0,0 Main St,Springfield,12340,US\nNew A,10 Elm St,Austin,78701,US\n';
        CodeyBulkCheckTool.Request r = new CodeyBulkCheckTool.Request(); r.quoteId = q.Id; r.membersCsv = csv;
        CodeyResult p = CodeyBulkCheckTool.run(new List<CodeyBulkCheckTool.Request>{ r })[0];
        System.assertEquals(true, p.success, p.message);
        Map<String, Object> d = (Map<String, Object>) JSON.deserializeUntyped(p.resultJson);
        System.assertEquals(2, d.get('load'));
        System.assertEquals(2, d.get('duplicates'));
        System.assertEquals(1, ((List<Object>) d.get('errors')).size());
        r.mode = 'commit'; r.previewToken = p.previewToken;
        Test.startTest();
        CodeyResult c = CodeyBulkCheckTool.run(new List<CodeyBulkCheckTool.Request>{ r })[0];
        Test.stopTest();
        System.assertEquals(true, c.success, c.message);
        System.assertEquals(4, [SELECT COUNT() FROM vlocity_cmt__QuoteMember__c WHERE vlocity_cmt__QuoteId__c = :q.Id]);
        // status
        CodeyBulkCheckTool.Request s = new CodeyBulkCheckTool.Request(); s.mode = 'status'; s.quoteId = q.Id;
        System.assertEquals(true, CodeyBulkCheckTool.run(new List<CodeyBulkCheckTool.Request>{ s })[0].success);
        s.jobId = c.jobId;
        System.assertEquals(true, CodeyBulkCheckTool.run(new List<CodeyBulkCheckTool.Request>{ s })[0].success);
    }

    @IsTest static void bulkCheckPhaseWritesResults() {
        Quote q = CodeyTestData.quote(5);
        Codey_Job__c j = new Codey_Job__c(Tool__c = CodeyBulkCheckTool.TOOL, Quote__c = q.Id, Status__c = 'Queued', Total__c = 5, Done__c = 0, Failed__c = 0,
            Steps_JSON__c = '[{"key":"check","label":"Check","status":"Pending"}]',
            Input_JSON__c = JSON.serialize(new Map<String, Object>{ 'quoteId' => q.Id, 'doAddress' => true, 'doService' => true, 'onlyUnchecked' => true, 'startedAt' => System.now().addMinutes(-1).getTime() }));
        insert j;
        Test.startTest();
        CodeyBulkCheckBatch.start(j.Id, 'check');
        Test.stopTest();
        Codey_Job__c done = [SELECT Status__c, Done__c, Results_File_Id__c, Message__c FROM Codey_Job__c WHERE Id = :j.Id];
        System.assertEquals('Completed', done.Status__c, done.Message__c);
        System.assertEquals(5, done.Done__c);
        System.assertNotEquals(null, done.Results_File_Id__c);
        System.assertEquals(5, [SELECT COUNT() FROM vlocity_cmt__QuoteMember__c WHERE vlocity_cmt__QuoteId__c = :q.Id AND vlocity_cmt__AddressValidationResult__c != null]);
    }

    @IsTest static void bulkErrorsAndProviders() {
        Quote q = CodeyTestData.quote(1);
        CodeyBulkCheckTool.Request r = new CodeyBulkCheckTool.Request(); r.quoteId = q.Id; r.membersCsv = 'Foo,Bar\n1,2\n';
        System.assertEquals(false, CodeyBulkCheckTool.run(new List<CodeyBulkCheckTool.Request>{ r })[0].success);
        r.membersCsv = 'Site\n'; 
        System.assertEquals(false, CodeyBulkCheckTool.run(new List<CodeyBulkCheckTool.Request>{ r })[0].success);
        CodeyBulkCheckTool.Request onlyCheck = new CodeyBulkCheckTool.Request(); onlyCheck.quoteId = q.Id; onlyCheck.checks = 'address';
        CodeyResult p = CodeyBulkCheckTool.run(new List<CodeyBulkCheckTool.Request>{ onlyCheck })[0];
        System.assertEquals(true, p.success, p.message);
        vlocity_cmt__QuoteMember__c m = [SELECT Id FROM vlocity_cmt__QuoteMember__c WHERE vlocity_cmt__QuoteId__c = :q.Id LIMIT 1];
        m.vlocity_cmt__ServiceabilityData__c = '{"serviceQualificationItem":[{"qualificationResult":"unqualified","eligibilityUnavailabilityReason":[{"label":"No fibre"}]}]}';
        update m;
        CodeyBulkCheck.Config cfg = CodeyBulkCheck.config();
        List<CodeyBulkCheck.Result> res = new CodeyBulkCheck.BuiltinProvider(cfg).check(q.Id, new List<Id>{ m.Id }, true, true);
        System.assertEquals('No', res[0].serviceable);
        System.assertEquals('No fibre', res[0].reason);
        cfg.mode = 'ApexClass'; cfg.apexClass = 'NoSuchCodeyClass';
        try { CodeyBulkCheck.provider(cfg); System.assert(false); } catch (CodeyCore.ToolException e) { }
        cfg.mode = 'IntegrationProcedure';
        System.assert(CodeyBulkCheck.provider(cfg) instanceof CodeyBulkCheck.IpProvider);
    }

    public class NoopQueueable implements Queueable { public void execute(QueueableContext c) { } }

    @IsTest static void runnerTracksRealApexJobs() {
        Test.startTest();
        Id aj = System.enqueueJob(new NoopQueueable());
        Test.stopTest();
        // a running step whose Apex job finished -> completed; then nothing left -> job completed
        List<Map<String, Object>> steps = new List<Map<String, Object>>{
            new Map<String, Object>{ 'key' => 'a', 'label' => 'A', 'status' => 'Running', 'apexJobId' => (String) aj, 'startedAt' => System.now().getTime() },
            new Map<String, Object>{ 'key' => 'm', 'label' => 'Manual', 'status' => 'Manual', 'note' => 'do it' } };
        Codey_Job__c j = new Codey_Job__c(Tool__c = CodeyAdminJobsTool.TOOL, Status__c = 'Running', Total__c = 2, Done__c = 0, Steps_JSON__c = JSON.serialize(steps));
        insert j;
        System.assertEquals(false, CodeyAdminJobRunner.step(j));
        System.assertEquals('Completed', j.Status__c, j.Message__c);
        System.assert(j.Message__c.contains('manual'), j.Message__c);
        // a running step with a recent start and no job yet -> keep waiting (looks for the package's batch)
        List<Map<String, Object>> s2 = new List<Map<String, Object>>{ new Map<String, Object>{ 'key' => 'b', 'label' => 'B', 'status' => 'Running', 'startedAt' => System.now().getTime() } };
        Codey_Job__c j2 = new Codey_Job__c(Tool__c = CodeyAdminJobsTool.TOOL, Status__c = 'Running', Total__c = 1, Done__c = 0, Steps_JSON__c = JSON.serialize(s2));
        insert j2;
        System.assertEquals(true, CodeyAdminJobRunner.step(j2));
        // a job id that is not found -> keep waiting
        s2[0].put('apexJobId', '7071x000000AAAA');
        j2.Steps_JSON__c = JSON.serialize(s2);
        System.assertEquals(true, CodeyAdminJobRunner.step(j2));
    }

    @IsTest static void liveStarterGenericPaths() {
        CodeyAdminJobRunner.LiveStarter st = new CodeyAdminJobRunner.LiveStarter();
        try { st.start('NoSuchCodeyJobClass', 'batch', 10, null); System.assert(false); } catch (CodeyCore.ToolException e) { }
        try { st.start('CodeyCore', 'batch', 10, null); System.assert(false); } catch (Exception e) { }
    }
}
