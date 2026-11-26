/**
 * Codey tool run_esm_admin_jobs (preview / commit / status) - PRD agent tool 1 "Admin jobs tool".
 * Starts the ESM admin (maintenance) jobs in the documented order (Codey_Admin_Job__mdt) and reports their status.
 * Jobs that agents cannot start (not exposed by the package) are shown as manual steps with where to run them.
 * The chain runs in CodeyAdminJobRunner (Queueable) as the asking user; state lives on Codey_Job__c so a failed
 * job can resume from the failed step without re-running the finished ones.
 */
public with sharing class CodeyAdminJobsTool {

    public static final String TOOL = 'run_esm_admin_jobs';

    public class Request {
        @InvocableVariable(label='Mode' description='preview (default), commit (start or resume, after approval) or status.')
        public String mode;
        @InvocableVariable(label='Jobs' description='default (recommended set, documented order), catalog, pricing, promotions, repair, or comma-separated job keys.')
        public String jobs;
        @InvocableVariable(label='Job Id' description='Codey job id (for status, or to resume a failed run with mode=commit).')
        public String jobId;
        @InvocableVariable(label='Preview Token' description='From the preview, for mode=commit.')
        public String previewToken;
        @InvocableVariable(label='Confirm Production' description='true only when the person confirmed running the jobs in a production org.')
        public Boolean confirmProduction;
        @InvocableVariable(label='Surface' description='Optional: where the request comes from.')
        public String surface;
    }

    @InvocableMethod(label='run_esm_admin_jobs' description='ESM admin (maintenance) jobs in the documented order with progress. mode=preview lists the jobs (nothing runs); mode=commit starts them after the person approved (same inputs + previewToken) or resumes a failed run (jobId); mode=status shows progress and plain-language errors.')
    public static List<CodeyResult> run(List<Request> requests) {
        List<CodeyResult> out = new List<CodeyResult>();
        for (Request r : requests) out.add(handle(r));
        return out;
    }

    static Map<String, Object> inputs(Request r) {
        return new Map<String, Object>{ 'jobs' => String.isBlank(r.jobs) ? 'default' : r.jobs, 'resumeJob' => r.jobId,'surface' => r.surface };
    }

    public static CodeyResult handle(Request r) {
        String mode = String.isBlank(r.mode) ? 'preview' : r.mode.trim().toLowerCase();
        Codey_Change_Log__c log;
        try {
            if (mode == 'status') return CodeyTrackJobTool.forJob(CodeyTrackJobTool.loadJob(r.jobId, TOOL));
            Codey_Job__c running = activeJob();
            Boolean resume = String.isNotBlank(r.jobId);
            if (mode == 'preview') {
                if (running != null && (!resume || running.Id != r.jobId)) {
                    CodeyResult busy = CodeyTrackJobTool.forJob(running);
                    busy.message = 'Admin jobs are already running (' + running.Name + '). Not starting another. ' + busy.message;
                    return busy;
                }
                List<Map<String, Object>> steps = resume ? resumeSteps(CodeyTrackJobTool.loadJob(r.jobId, TOOL)) : steps(r.jobs);
                List<CodeyCards.Change> changes = new List<CodeyCards.Change>();
                Integer auto = 0, manual = 0;
                for (Map<String, Object> s : steps) {
                    Boolean isManual = s.get('mode') == 'manual';
                    if (isManual) manual++; else auto++;
                    CodeyCards.Change c = new CodeyCards.Change(String.valueOf(s.get('order')) + '. ' + s.get('label'), isManual ? 'Manual' : 'Start',
                        String.valueOf(s.get('status')), isManual ? 'you run it: ' + s.get('note') : 'agent starts it');
                    changes.add(c);
                }
                log = CodeyCore.logPreview(TOOL, resume ? 'resume' : 'start', resume ? 'resume ' + r.jobId : (String.isBlank(r.jobs) ? 'default' : r.jobs), null, steps, inputs(r));
                CodeyResult res = CodeyResult.ok('preview', 'Preview: ' + (resume ? 'resume ' : 'run ') + steps.size() + ' admin jobs in the documented order (' + auto + ' started by the agent, ' + manual + ' manual). Nothing runs until you approve.', new Map<String, Object>{ 'steps' => steps });
                res.previewToken = log.Preview_Token__c;
                res.changeLogId = log.Id;
                res.card = CodeyCards.approval((resume ? 'Resume' : 'Run') + ' ESM admin jobs', auto + ' automatic · ' + manual + ' manual', changes, log.Preview_Token__c, 'Jobs run in the background and can take a while.');
                res.nextStep = 'Show the Approval card. Only after the person says approve: call mode=commit with the same inputs and previewToken.';
                return res;
            }
            if (mode != 'commit') throw new CodeyCore.ToolException('Unknown mode "' + r.mode + '". Use preview, commit or status.');
            CodeyCore.guardProduction(r.confirmProduction);   // before the preview is used, so a refusal keeps the preview open
            log = CodeyCore.requireApproval(TOOL, inputs(r), r.previewToken);
            Codey_Job__c job;
            if (resume) {
                job = CodeyTrackJobTool.loadJob(r.jobId, TOOL);
                if (job.Status__c != 'Failed' && job.Status__c != 'Paused') throw new CodeyCore.ToolException('Job ' + job.Name + ' is ' + job.Status__c + '; only failed or paused jobs can resume.');
                job.Steps_JSON__c = JSON.serialize(resumeSteps(job));
                job.Status__c = 'Queued';
                job.Message__c = 'Resumed from the failed step.';
                update job;
            } else {
                if (running != null) throw new CodeyCore.ToolException('Admin jobs are already running (' + running.Name + '). Track it with track_codey_job; not starting another.');
                List<Map<String, Object>> steps = steps(r.jobs);
                job = new Codey_Job__c(Tool__c = TOOL, Status__c = 'Queued', Steps_JSON__c = JSON.serialize(steps), Total__c = steps.size(), Done__c = 0, Failed__c = 0,
                    Input_JSON__c = JSON.serialize(inputs(r)), Change_Log__c = log.Id, Step__c = 'Waiting to start');
                insert job;
            }
            CodeyAdminJobRunner.enqueue(job.Id, 0);
            CodeyCore.markCommitted(log, new Map<String, Object>{ 'jobId' => job.Id }, new List<Id>{ job.Id });
            CodeyResult res = CodeyTrackJobTool.forJob([SELECT Id, Name, Tool__c, Status__c, Step__c, Steps_JSON__c, Total__c, Done__c, Failed__c, Message__c, Results_File_Id__c, Quote__c, Cursor__c, CreatedDate FROM Codey_Job__c WHERE Id = :job.Id]);
            res.mode = 'commit';
            res.changeLogId = log.Id;
            res.message = 'Started: admin jobs ' + job.Id + ' run in the background in the documented order. ' + res.message;
            res.nextStep = 'Check progress with track_codey_job jobId=' + job.Id + ' about every minute, or when the person asks.';
            return res;
        } catch (Exception e) {
            if (mode == 'commit' && log != null) CodeyCore.markFailed(log, e.getMessage());
            return CodeyResult.fail(mode, e);
        }
    }

    public static Codey_Job__c activeJob() {
        List<Codey_Job__c> js = [SELECT Id, Name, Tool__c, Status__c, Step__c, Steps_JSON__c, Total__c, Done__c, Failed__c, Message__c, Results_File_Id__c, Quote__c, Cursor__c, CreatedDate
                                 FROM Codey_Job__c WHERE Tool__c = :TOOL AND Status__c IN ('Queued', 'Running') AND CreatedDate = LAST_N_DAYS:2 ORDER BY CreatedDate DESC LIMIT 1];
        return js.isEmpty() ? null : js[0];
    }

    /** The planned steps for a jobs selection, in the documented order. */
    public static List<Map<String, Object>> steps(String selection) {
        String sel = String.isBlank(selection) ? 'default' : selection.trim().toLowerCase();
        Set<String> keys = new Set<String>();
        for (String k : CodeyCore.splitList(sel)) keys.add(k.toLowerCase());
        List<Map<String, Object>> out = new List<Map<String, Object>>();
        Set<String> known = new Set<String>();
        for (Codey_Admin_Job__mdt j : [SELECT Order__c, Job_Key__c, Label__c, Mode__c, Class_Name__c, Batch_Size__c, Groups__c, Arg__c, Note__c FROM Codey_Admin_Job__mdt WHERE Active__c = true ORDER BY Order__c]) {
            known.add(j.Job_Key__c.toLowerCase());
            Set<String> groups = new Set<String>(CodeyCore.splitList(j.Groups__c == null ? '' : j.Groups__c.toLowerCase()));
            Boolean pick = keys.contains(j.Job_Key__c.toLowerCase());
            for (String k : keys) if (groups.contains(k)) pick = true;
            if (!pick) continue;
            out.add(new Map<String, Object>{ 'order' => j.Order__c.intValue(), 'key' => j.Job_Key__c, 'label' => j.Label__c, 'mode' => j.Mode__c, 'className' => j.Class_Name__c,
                'batchSize' => j.Batch_Size__c == null ? 200 : j.Batch_Size__c.intValue(), 'arg' => j.Arg__c, 'note' => j.Note__c,
                'status' => j.Mode__c == 'manual' ? 'Manual' : 'Pending' });
        }
        for (String k : keys) {
            if (!known.contains(k) && !new Set<String>{ 'default', 'catalog', 'pricing', 'promotions', 'repair' }.contains(k)) throw new CodeyCore.ToolException('Unknown admin job "' + k + '". Use default, catalog, pricing, promotions, repair or job keys: ' + String.join(new List<String>(known), ', ') + '.');
        }
        if (out.isEmpty()) throw new CodeyCore.ToolException('No admin jobs selected for "' + selection + '".');
        return out;
    }

    /** For a resume: finished steps stay finished, the failed step and the ones after it run again. */
    public static List<Map<String, Object>> resumeSteps(Codey_Job__c job) {
        List<Map<String, Object>> out = new List<Map<String, Object>>();
        for (Object o : (List<Object>) JSON.deserializeUntyped(job.Steps_JSON__c)) {
            Map<String, Object> s = (Map<String, Object>) o;
            if (s.get('status') == 'Failed' || s.get('status') == 'Running') { s.put('status', 'Pending'); s.remove('apexJobId'); s.remove('error'); }
            out.add(s);
        }
        return out;
    }
}
