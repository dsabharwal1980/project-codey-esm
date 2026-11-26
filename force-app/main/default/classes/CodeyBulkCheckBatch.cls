/**
 * Background work for check_quote_members_bulk.
 * phase "load": creates the validated new quote members from the stored spreadsheet (skips duplicates, safe to run again).
 * phase "check": address verification and serviceability through the configured provider, in batches, with one retry per batch;
 *                remembers the last member done (Cursor__c) so a stopped job resumes there. Writes the results CSV to the quote.
 */
public with sharing class CodeyBulkCheckBatch implements Database.Batchable<Object>, Database.Stateful, Database.AllowsCallouts {

    final Id jobId;
    final String phase;
    Id quoteId;
    Boolean doAddress = true, doService = true, onlyUnchecked = true;
    Integer done = 0, failed = 0, loaded = 0;
    Long startedAt;
    List<String> lines = new List<String>();
    Map<String, Integer> counts = new Map<String, Integer>();

    public CodeyBulkCheckBatch(Id jobId, String phase) { this.jobId = jobId; this.phase = phase; }

    public static Id start(Id jobId, String phase) {
        Integer size = phase == 'load' ? 200 : CodeyBulkCheck.config().batchSize;
        return Database.executeBatch(new CodeyBulkCheckBatch(jobId, phase), size <= 0 ? 200 : size);
    }

    Codey_Job__c job() {
        return [SELECT Id, Name, Status__c, Steps_JSON__c, Input_JSON__c, Total__c, Done__c, Failed__c, Cursor__c, Quote__c, Results_File_Id__c FROM Codey_Job__c WHERE Id = :jobId];
    }

    public Iterable<Object> start(Database.BatchableContext bc) {
        Codey_Job__c j = job();
        Map<String, Object> in1 = (Map<String, Object>) JSON.deserializeUntyped(j.Input_JSON__c);
        quoteId = j.Quote__c;
        doAddress = in1.get('doAddress') != false;
        doService = in1.get('doService') != false;
        onlyUnchecked = in1.get('onlyUnchecked') != false;
        startedAt = in1.get('startedAt') == null ? System.now().getTime() : Long.valueOf(String.valueOf(in1.get('startedAt')));
        j.Status__c = 'Running';
        j.Apex_Job_Id__c = bc.getJobId();
        setStep(j, phase, 'Running', null, null);
        List<Object> work = new List<Object>();
        if (phase == 'load') {
            String cvId = String.valueOf(in1.get('csvVersionId'));
            CodeyBulkCheckTool.Request r = new CodeyBulkCheckTool.Request();
            r.quoteId = quoteId; r.membersCsv = [SELECT VersionData FROM ContentVersion WHERE Id = :cvId].VersionData.toString(); r.checks = 'none';
            CodeyBulkCheckTool.Plan p = CodeyBulkCheckTool.plan(r);   // re-validated now: duplicates loaded since the preview are skipped
            for (Map<String, Object> v : p.valid) work.add(v);
            j.Total__c = p.valid.size();
            j.Step__c = 'Loading members';
        } else {
            String cursor = j.Cursor__c != null && j.Cursor__c.startsWith('a') ? j.Cursor__c : null;
            Datetime since = Datetime.newInstance(startedAt);
            String q = 'SELECT Id FROM vlocity_cmt__QuoteMember__c WHERE vlocity_cmt__QuoteId__c = :quoteId'
                + (cursor == null ? '' : ' AND Id > :cursor')
                + (onlyUnchecked ? ' AND ((vlocity_cmt__AddressValidationResult__c = null AND vlocity_cmt__ServiceabilityLastCheckedDate__c = null) OR CreatedDate >= :since)' : '')
                + ' ORDER BY Id LIMIT 50000';
            for (SObject m : Database.query(q)) work.add(String.valueOf(m.Id));
            j.Total__c = work.size() + (cursor == null ? 0 : (j.Done__c == null ? 0 : j.Done__c.intValue()));
            if (cursor == null) { j.Done__c = 0; j.Failed__c = 0; }
            done = j.Done__c == null ? 0 : j.Done__c.intValue();
            failed = j.Failed__c == null ? 0 : j.Failed__c.intValue();
            j.Step__c = 'Checking members';
        }
        update j;
        return work;
    }

    public void execute(Database.BatchableContext bc, List<Object> scope) {
        if (phase == 'load') { load(scope); return; }
        List<Id> ids = new List<Id>();
        for (Object o : scope) ids.add((Id) String.valueOf(o));
        CodeyBulkCheck.Config cfg = CodeyBulkCheck.config();
        List<CodeyBulkCheck.Result> results;
        String error;
        for (Integer attempt = 0; attempt < 2 && results == null; attempt++) {   // one retry per batch
            try { results = CodeyBulkCheck.provider(cfg).check(quoteId, ids, doAddress, doService); }
            catch (Exception e) { error = e.getMessage(); }
        }
        if (results == null) {
            results = new List<CodeyBulkCheck.Result>();
            for (vlocity_cmt__QuoteMember__c m : [SELECT Id, Name FROM vlocity_cmt__QuoteMember__c WHERE Id IN :ids]) {
                CodeyBulkCheck.Result r = new CodeyBulkCheck.Result();
                r.memberId = m.Id; r.name = m.Name; r.failed = true; r.reason = 'Check failed after a retry: ' + error;
                results.add(r);
            }
        }
        List<vlocity_cmt__QuoteMember__c> updates = new List<vlocity_cmt__QuoteMember__c>();
        for (CodeyBulkCheck.Result r : results) {
            if (r.failed) failed++; else done++;
            bump('address:' + (r.addressStatus == null ? 'not checked' : r.addressStatus));
            bump('serviceable:' + (r.serviceable == null ? 'not checked' : r.serviceable));
            lines.add(CodeyCsv.line(new List<Object>{ r.memberId, r.name, r.address, r.addressStatus, r.addressMessage, r.serviceable, r.technology, r.maxDownload, r.failed ? 'Failed' : 'Checked', r.reason }));
            if (cfg.writeBack && cfg.mode != 'IntegrationProcedure' && doAddress && !r.failed && r.addressStatus != null) {
                updates.add(new vlocity_cmt__QuoteMember__c(Id = r.memberId, vlocity_cmt__AddressValidationResult__c = r.addressStatus, vlocity_cmt__AddressValidationMessage__c = r.addressMessage == null ? null : r.addressMessage.left(255)));
            }
        }
        if (!updates.isEmpty()) Database.update(updates, false, AccessLevel.USER_MODE);
        Codey_Job__c j = job();
        j.Done__c = done; j.Failed__c = failed;
        j.Cursor__c = ids[ids.size() - 1];
        Decimal pct = j.Total__c == null || j.Total__c == 0 ? 0 : 100 * (done + failed) / j.Total__c;
        setStep(j, 'check', 'Running', pct, (done + failed) + ' of ' + j.Total__c.intValue() + ' members');
        update j;
    }

    void load(List<Object> scope) {
        List<vlocity_cmt__QuoteMember__c> ms = new List<vlocity_cmt__QuoteMember__c>();
        for (Object o : scope) {
            Map<String, Object> v = (Map<String, Object>) o;
            ms.add(new vlocity_cmt__QuoteMember__c(vlocity_cmt__QuoteId__c = quoteId, Name = String.valueOf(v.get('name')).left(80),
                vlocity_cmt__StreetAddress__c = s(v.get('street'), 255), vlocity_cmt__City__c = s(v.get('city'), 40), vlocity_cmt__State__c = s(v.get('state'), 80),
                vlocity_cmt__PostalCode__c = s(v.get('postal'), 20), vlocity_cmt__Country__c = s(v.get('country'), 80)));
        }
        Integer i = 0;
        for (Database.SaveResult sr : Database.insert(ms, false, AccessLevel.USER_MODE)) {
            Map<String, Object> v = (Map<String, Object>) scope[i++];
            if (sr.isSuccess()) loaded++;
            else { failed++; lines.add(CodeyCsv.line(new List<Object>{ '', v.get('name'), v.get('addressText'), '', '', '', '', '', 'Not loaded', sr.getErrors()[0].getMessage() })); }
        }
        Codey_Job__c j = job();
        j.Done__c = loaded; j.Failed__c = failed;
        setStep(j, 'load', 'Running', j.Total__c == null || j.Total__c == 0 ? 0 : 100 * (loaded + failed) / j.Total__c, loaded + ' loaded');
        update j;
    }

    public void finish(Database.BatchableContext bc) {
        Codey_Job__c j = job();
        AsyncApexJob a = [SELECT Status, NumberOfErrors, ExtendedStatus FROM AsyncApexJob WHERE Id = :bc.getJobId()];
        if (a.NumberOfErrors != null && a.NumberOfErrors > 0) {
            j.Status__c = 'Failed';
            Map<String, Object> in1 = (Map<String, Object>) JSON.deserializeUntyped(j.Input_JSON__c);
            in1.put('phaseAtFailure', phase);
            j.Input_JSON__c = JSON.serialize(in1);
            j.Message__c = 'Stopped: ' + CodeyAdminJobRunner.plain(a.ExtendedStatus, a.Status, a.NumberOfErrors) + ' Work done so far is kept; Resume continues from member ' + j.Cursor__c + '.';
            setStep(j, phase, 'Failed', null, j.Message__c);
            writeResults(j, true);
            update j;
            return;
        }
        if (phase == 'load') {
            setStep(j, 'load', 'Completed', 100, loaded + ' loaded' + (failed > 0 ? ', ' + failed + ' not loaded' : ''));
            Map<String, Object> in1 = (Map<String, Object>) JSON.deserializeUntyped(j.Input_JSON__c);
            if (in1.get('doAddress') != false || in1.get('doService') != false) {
                j.Done__c = 0; j.Failed__c = 0; j.Cursor__c = null;
                update j;
                CodeyBulkCheckBatch next = new CodeyBulkCheckBatch(jobId, 'check');
                next.lines = lines;   // keep "not loaded" rows for the results file
                Database.executeBatch(next, CodeyBulkCheck.config().batchSize);
                return;
            }
        } else {
            setStep(j, 'check', 'Completed', 100, summary());
        }
        writeResults(j, false);
        j.Status__c = 'Completed';
        j.Step__c = 'Done';
        j.Message__c = (phase == 'load' ? loaded + ' members loaded. ' : '') + summary();
        update j;
    }

    void writeResults(Codey_Job__c j, Boolean partial) {
        if (lines.isEmpty()) return;
        String csv = 'Member Id,Name,Address,Address result,Address message,Serviceable,Technology,Max download,Status,Reason\n' + String.join(lines, '\n') + '\n';
        ContentVersion cv = new ContentVersion(Title = 'Codey member check results ' + j.Name + (partial ? ' (partial)' : ''), PathOnClient = 'codey-member-results-' + j.Name + '.csv',
            VersionData = Blob.valueOf(csv), FirstPublishLocationId = quoteId);
        insert cv;
        j.Results_File_Id__c = [SELECT ContentDocumentId FROM ContentVersion WHERE Id = :cv.Id].ContentDocumentId;
    }

    String summary() {
        List<String> parts = new List<String>();
        for (String k : counts.keySet()) parts.add(k.replace('address:', 'address ').replace('serviceable:', 'serviceable ') + ' ' + counts.get(k));
        parts.sort();
        return 'Checked ' + done + ' members' + (failed > 0 ? ', ' + failed + ' failed' : '') + (parts.isEmpty() ? '.' : ': ' + String.join(parts, ', ') + '.');
    }

    void bump(String k) { counts.put(k, (counts.containsKey(k) ? counts.get(k) : 0) + 1); }

    static String s(Object v, Integer len) { return v == null ? null : String.valueOf(v).left(len); }

    static void setStep(Codey_Job__c j, String key, String status, Decimal pct, String detail) {
        if (String.isBlank(j.Steps_JSON__c)) return;
        List<Object> steps = (List<Object>) JSON.deserializeUntyped(j.Steps_JSON__c);
        for (Object o : steps) {
            Map<String, Object> s = (Map<String, Object>) o;
            if (s.get('key') != key) continue;
            s.put('status', status);
            if (pct != null) s.put('percent', pct.setScale(0));
            if (detail != null) s.put('detail', detail);
        }
        j.Steps_JSON__c = JSON.serialize(steps);
    }
}
