/**
 * Codey tool track_codey_job (read-only) - Progress tracker for long jobs (admin jobs, bulk member checks):
 * overall progress, each step, plain-language errors and where a failed job can resume.
 */
public with sharing class CodeyTrackJobTool {

    public static final String TOOL = 'track_codey_job';

    public class Request {
        @InvocableVariable(label='Job Id' description='Codey job id (from run_esm_admin_jobs or check_quote_members_bulk) or its name CJ-...')
        public String jobId;
        @InvocableVariable(label='Quote' description='Optional quote Id or name: shows the latest Codey job for this quote.')
        public String quoteId;
        @InvocableVariable(label='Tool' description='Optional: latest job of run_esm_admin_jobs or check_quote_members_bulk.')
        public String tool;
        @InvocableVariable(label='Surface' description='Optional: where the request comes from.')
        public String surface;
    }

    @InvocableMethod(label='track_codey_job' description='Read-only progress of a Project Codey background job (admin jobs, bulk address and serviceability checks): percent done, each step, errors in plain words, results file, and whether it can resume.')
    public static List<CodeyResult> run(List<Request> requests) {
        List<CodeyResult> out = new List<CodeyResult>();
        for (Request r : requests) {
            try {
                Codey_Job__c job;
                if (String.isNotBlank(r.jobId)) job = loadJob(r.jobId, null);
                else {
                    Id qid = String.isBlank(r.quoteId) ? null : CodeyCore.findQuote(r.quoteId).Id;
                    String tool = r.tool;
                    String q = 'SELECT Id, Name, Tool__c, Status__c, Step__c, Steps_JSON__c, Total__c, Done__c, Failed__c, Message__c, Results_File_Id__c, Quote__c, Cursor__c, CreatedDate FROM Codey_Job__c WHERE CreatedById != null'
                        + (qid == null ? '' : ' AND Quote__c = :qid') + (String.isBlank(tool) ? '' : ' AND Tool__c = :tool') + ' ORDER BY CreatedDate DESC LIMIT 1';
                    List<Codey_Job__c> js = Database.query(q);
                    if (js.isEmpty()) throw new CodeyCore.ToolException('No Codey job found' + (qid == null ? '' : ' for this quote') + '.');
                    job = js[0];
                }
                out.add(forJob(job));
            } catch (Exception e) {
                out.add(CodeyResult.fail('read', e));
            }
        }
        return out;
    }

    public static Codey_Job__c loadJob(String ref, String tool) {
        if (String.isBlank(ref)) throw new CodeyCore.ToolException('Give the Codey job id (or CJ-... name).');
        String v = ref.trim();
        List<Codey_Job__c> js = [SELECT Id, Name, Tool__c, Status__c, Step__c, Steps_JSON__c, Total__c, Done__c, Failed__c, Message__c, Results_File_Id__c, Quote__c, Cursor__c, CreatedDate
                                 FROM Codey_Job__c WHERE Name = :v OR Id = :(v.length() >= 15 && !v.startsWith('CJ-') ? v : null) LIMIT 1];
        if (js.isEmpty()) throw new CodeyCore.ToolException('Codey job ' + v + ' not found.');
        if (tool != null && js[0].Tool__c != tool) throw new CodeyCore.ToolException('Job ' + v + ' belongs to ' + js[0].Tool__c + ', not ' + tool + '.');
        return js[0];
    }

    public static CodeyResult forJob(Codey_Job__c job) {
        List<CodeyCards.StepRow> rows = new List<CodeyCards.StepRow>();
        List<Object> steps = String.isBlank(job.Steps_JSON__c) ? new List<Object>() : (List<Object>) JSON.deserializeUntyped(job.Steps_JSON__c);
        Integer manual = 0;
        for (Object o : steps) {
            Map<String, Object> s = (Map<String, Object>) o;
            CodeyCards.StepRow row = new CodeyCards.StepRow();
            row.label = String.valueOf(s.get('label'));
            row.status = String.valueOf(s.get('status'));
            row.percent = s.get('percent') == null ? null : Decimal.valueOf(String.valueOf(s.get('percent')));
            row.detail = s.get('status') == 'Manual' ? 'Do this in CMT Administration: ' + s.get('note') : (s.get('detail') == null ? '' : String.valueOf(s.get('detail')));
            if (row.status == 'Manual') manual++;
            rows.add(row);
        }
        Decimal total = job.Total__c == null || job.Total__c == 0 ? 0 : job.Total__c;
        Decimal done = job.Done__c == null ? 0 : job.Done__c;
        Decimal pct;
        if (job.Status__c == 'Completed') pct = 100;
        else if (total == 0) pct = 0;
        else {
            Decimal denom = job.Tool__c == CodeyAdminJobsTool.TOOL ? total - manual : total;
            if (denom < 1) denom = 1;
            pct = 100 * done / denom;
        }
        if (pct > 100) pct = 100;
        String resultsUrl = String.isBlank(job.Results_File_Id__c) ? null : URL.getOrgDomainUrl().toExternalForm() + '/lightning/r/ContentDocument/' + job.Results_File_Id__c + '/view';
        String title = job.Tool__c == CodeyAdminJobsTool.TOOL ? 'ESM admin jobs' : (job.Tool__c == CodeyBulkCheckTool.TOOL ? 'Quote member checks' : 'Codey job');
        String subtitle = job.Name + ' · started ' + job.CreatedDate.format('yyyy-MM-dd HH:mm') + (String.isBlank(job.Step__c) ? '' : ' · ' + job.Step__c);
        String msg = title + ' ' + job.Name + ': ' + job.Status__c + ', ' + pct.setScale(0) + '% done.' + (String.isBlank(job.Message__c) ? '' : ' ' + job.Message__c);
        CodeyResult res = CodeyResult.ok('status', msg, new Map<String, Object>{ 'jobId' => job.Id, 'name' => job.Name, 'tool' => job.Tool__c, 'status' => job.Status__c,
            'percent' => pct.setScale(0), 'total' => job.Total__c, 'done' => job.Done__c, 'failed' => job.Failed__c, 'steps' => steps, 'resultsFileId' => job.Results_File_Id__c, 'resumeAt' => job.Cursor__c });
        res.jobId = job.Id;
        res.card = CodeyCards.progress(title, subtitle, job.Status__c, pct, rows, job.Id,
            job.Status__c == 'Failed' ? 'Finished work is kept. Resume restarts from ' + (String.isBlank(job.Cursor__c) ? 'where it stopped' : job.Cursor__c) + ' (preview + approval first).' : null, resultsUrl);
        res.nextStep = job.Status__c == 'Completed' ? (resultsUrl == null ? 'Done. Summarise the result.' : 'Done. Share the results file and summarise the counts.')
            : (job.Status__c == 'Failed' ? 'Explain the error in plain words and offer Resume (mode=preview with jobId, then approval).' : 'Still running; check again in about a minute.');
        return res;
    }
}
