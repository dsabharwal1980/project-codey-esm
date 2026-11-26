/**
 * Codey tool check_quote_members_bulk (preview / commit / status) - PRD agent tool 3 "Bulk address and serviceability tool".
 * Checks a member spreadsheet before loading (columns, missing data, duplicates), loads the valid new rows after approval,
 * and runs address verification and serviceability in background batches (CodeyBulkCheckBatch) with progress, one retry
 * per batch and resume. Returns a results file (CSV on the quote) with each member's result and the reason for any failure.
 * Member data stays in the org.
 */
public with sharing class CodeyBulkCheckTool {

    public static final String TOOL = 'check_quote_members_bulk';
    public static final Integer MAX_ERRORS_SHOWN = 200;

    public class Request {
        @InvocableVariable(label='Mode' description='preview (default), commit (after approval: load and/or check in the background), status.')
        public String mode;
        @InvocableVariable(label='Quote' description='Enterprise Quote Id or name.' required=true)
        public String quoteId;
        @InvocableVariable(label='Members CSV' description='Optional CSV text with a header row: name/site, street/address, city, state, postal code/zip, country. Read the attached spreadsheet and pass its rows.')
        public String membersCsv;
        @InvocableVariable(label='File' description='Optional ContentDocument Id (069...) of a CSV file attached in Salesforce, instead of membersCsv.')
        public String contentDocumentId;
        @InvocableVariable(label='Checks' description='address, serviceability (default: both), or none to only load.')
        public String checks;
        @InvocableVariable(label='Only Unchecked' description='true (default): check only members without an earlier result; false: re-check all members on the quote.')
        public Boolean onlyUnchecked;
        @InvocableVariable(label='Job Id' description='Codey job id for status, or to resume a stopped job with mode=commit.')
        public String jobId;
        @InvocableVariable(label='Preview Token' description='From the preview, for mode=commit.')
        public String previewToken;
        @InvocableVariable(label='Confirm Production' description='true only when the person confirmed the load in a production org.')
        public Boolean confirmProduction;
        @InvocableVariable(label='Surface' description='Optional: where the request comes from.')
        public String surface;
    }

    @InvocableMethod(label='check_quote_members_bulk' description='Load many quote members from a spreadsheet and check addresses and serviceability in the background. mode=preview validates the file and shows what will load and be checked (nothing saved); mode=commit runs it after approval (same inputs + previewToken); mode=status shows progress and the results file.')
    public static List<CodeyResult> run(List<Request> requests) {
        List<CodeyResult> out = new List<CodeyResult>();
        for (Request r : requests) out.add(handle(r));
        return out;
    }

    static Map<String, Object> inputs(Request r) {
        return new Map<String, Object>{ 'quoteId' => r.quoteId, 'membersCsv' => r.membersCsv, 'contentDocumentId' => r.contentDocumentId, 'checks' => r.checks,
            'onlyUnchecked' => r.onlyUnchecked, 'resumeJob' => r.jobId, 'surface' => r.surface };
    }

    public class Plan {
        public Quote quote;
        public Integer rows = 0;
        public List<Map<String, Object>> valid = new List<Map<String, Object>>();
        public List<Map<String, Object>> errors = new List<Map<String, Object>>();
        public Integer duplicates = 0;
        public Map<String, Integer> header = new Map<String, Integer>();
        public Integer existing = 0;
        public Integer toCheck = 0;
        public Boolean doAddress = true;
        public Boolean doService = true;
        public String csv;
    }

    public static CodeyResult handle(Request r) {
        String mode = String.isBlank(r.mode) ? 'preview' : r.mode.trim().toLowerCase();
        Codey_Change_Log__c log;
        try {
            if (mode == 'status') {
                if (String.isNotBlank(r.jobId)) return CodeyTrackJobTool.forJob(CodeyTrackJobTool.loadJob(r.jobId, TOOL));
                CodeyTrackJobTool.Request tr = new CodeyTrackJobTool.Request();
                tr.quoteId = r.quoteId; tr.tool = TOOL;
                return CodeyTrackJobTool.run(new List<CodeyTrackJobTool.Request>{ tr })[0];
            }
            Plan p = plan(r);
            Codey_Job__c running = activeJob(p.quote.Id);
            Boolean resume = String.isNotBlank(r.jobId);
            if (mode == 'preview') {
                if (running != null && (!resume || running.Id != r.jobId)) {
                    CodeyResult busy = CodeyTrackJobTool.forJob(running);
                    busy.message = 'A member job is already running on this quote (' + running.Name + '); not starting another. ' + busy.message;
                    return busy;
                }
                List<CodeyCards.Change> ch = new List<CodeyCards.Change>();
                if (p.rows > 0) ch.add(new CodeyCards.Change('Load ' + p.valid.size() + ' new quote members', 'Load', p.existing + ' members on the quote', (p.existing + p.valid.size()) + ' members'));
                if (p.duplicates > 0) ch.add(new CodeyCards.Change('Skip ' + p.duplicates + ' duplicates (already on the quote or repeated in the file)', 'Skip', null, 'not loaded'));
                if (!p.errors.isEmpty()) ch.add(new CodeyCards.Change('Skip ' + p.errors.size() + ' rows with errors (listed in the details)', 'Skip', null, 'not loaded'));
                if (p.doAddress || p.doService) ch.add(new CodeyCards.Change('Check ' + p.toCheck + ' members: ' + (p.doAddress ? 'address' : '') + (p.doAddress && p.doService ? ' + ' : '') + (p.doService ? 'serviceability' : ''), 'Start', 'not checked', 'checked in the background'));
                Integer shown = 0;
                for (Map<String, Object> v : p.valid) { if (shown++ >= 8) break; ch.add(new CodeyCards.Change(String.valueOf(v.get('name')), 'Load', null, String.valueOf(v.get('addressText')))); }
                for (Map<String, Object> e : p.errors) { if (shown++ >= 16) break; CodeyCards.Change c = new CodeyCards.Change('Row ' + e.get('row') + ': ' + e.get('name'), 'Skip', null, 'not loaded'); c.detail = String.valueOf(e.get('reason')); ch.add(c); }
                log = CodeyCore.logPreview(TOOL, resume ? 'resume' : 'loadAndCheck', p.quote.Name, new Map<String, Object>{ 'existingMembers' => p.existing },
                    new Map<String, Object>{ 'load' => p.valid.size(), 'skipDuplicates' => p.duplicates, 'skipErrors' => p.errors.size(), 'check' => p.toCheck }, inputs(r));
                String msg = 'Preview for quote ' + p.quote.Name + ': ' + (p.rows == 0 ? '' : p.rows + ' rows read, ' + p.valid.size() + ' to load, ' + p.duplicates + ' duplicates, ' + p.errors.size() + ' with errors. ')
                    + (p.doAddress || p.doService ? p.toCheck + ' members to check in the background.' : 'No checks requested.') + ' Nothing has changed yet.'
                    + (p.rows > 0 && !p.header.containsKey('street') ? ' No street/address column was recognised.' : '');
                CodeyResult res = CodeyResult.ok('preview', msg, new Map<String, Object>{ 'columns' => p.header.keySet(), 'rows' => p.rows, 'load' => p.valid.size(), 'duplicates' => p.duplicates,
                    'errors' => slice(p.errors), 'check' => p.toCheck, 'existingMembers' => p.existing });
                res.previewToken = log.Preview_Token__c;
                res.changeLogId = log.Id;
                res.card = CodeyCards.approval('Load and check quote members', p.quote.Name, ch, log.Preview_Token__c, 'Checks run in batches of ' + CodeyBulkCheck.config().batchSize + ' in the background; a results file is attached to the quote.');
                res.nextStep = 'Show the Approval card (fix rows with errors first if the person wants). Only after approve: mode=commit with the same inputs and previewToken.';
                return res;
            }
            if (mode != 'commit') throw new CodeyCore.ToolException('Unknown mode "' + r.mode + '". Use preview, commit or status.');
            CodeyCore.guardProduction(r.confirmProduction);   // before the preview is used, so a refusal keeps the preview open
            log = CodeyCore.requireApproval(TOOL, inputs(r), r.previewToken);
            Codey_Job__c job;
            if (resume) {
                job = CodeyTrackJobTool.loadJob(r.jobId, TOOL);
                if (job.Status__c != 'Failed' && job.Status__c != 'Paused') throw new CodeyCore.ToolException('Job ' + job.Name + ' is ' + job.Status__c + '; only failed or paused jobs resume.');
                job.Status__c = 'Queued'; job.Message__c = 'Resumed after ' + job.Cursor__c + '.';
                update job;
                Map<String, Object> in2 = (Map<String, Object>) JSON.deserializeUntyped(job.Input_JSON__c);
                CodeyBulkCheckBatch.start(job.Id, in2.get('phaseAtFailure') == 'load' ? 'load' : 'check');
            } else {
                if (running != null) throw new CodeyCore.ToolException('A member job is already running on this quote (' + running.Name + '). Track it with track_codey_job.');
                List<Map<String, Object>> steps = new List<Map<String, Object>>();
                if (p.rows > 0) steps.add(new Map<String, Object>{ 'key' => 'load', 'label' => 'Load ' + p.valid.size() + ' members', 'status' => 'Pending', 'percent' => 0 });
                if (p.doAddress || p.doService) steps.add(new Map<String, Object>{ 'key' => 'check', 'label' => 'Check ' + (p.doAddress ? 'address' : '') + (p.doAddress && p.doService ? ' + ' : '') + (p.doService ? 'serviceability' : ''), 'status' => 'Pending', 'percent' => 0 });
                if (steps.isEmpty()) throw new CodeyCore.ToolException('Nothing to do: no rows to load and no checks requested.');
                job = new Codey_Job__c(Tool__c = TOOL, Quote__c = p.quote.Id, Status__c = 'Queued', Total__c = p.rows > 0 ? p.valid.size() : p.toCheck, Done__c = 0, Failed__c = 0,
                    Steps_JSON__c = JSON.serialize(steps), Change_Log__c = log.Id, Step__c = 'Waiting to start',
                    Input_JSON__c = JSON.serialize(new Map<String, Object>{ 'quoteId' => p.quote.Id, 'doAddress' => p.doAddress, 'doService' => p.doService, 'onlyUnchecked' => r.onlyUnchecked != false, 'startedAt' => System.now().getTime() }));
                insert job;
                if (p.rows > 0) {
                    ContentVersion cv = new ContentVersion(Title = 'Codey member load ' + job.Id, PathOnClient = 'codey-members-' + job.Id + '.csv', VersionData = Blob.valueOf(p.csv), FirstPublishLocationId = job.Id);
                    insert cv;
                    Map<String, Object> in2 = (Map<String, Object>) JSON.deserializeUntyped(job.Input_JSON__c);
                    in2.put('csvVersionId', cv.Id);
                    job.Input_JSON__c = JSON.serialize(in2);
                    update job;
                }
                CodeyBulkCheckBatch.start(job.Id, p.rows > 0 ? 'load' : 'check');
            }
            CodeyCore.markCommitted(log, new Map<String, Object>{ 'jobId' => job.Id }, new List<Id>{ job.Id });
            CodeyResult res = CodeyTrackJobTool.forJob(CodeyTrackJobTool.loadJob(job.Id, TOOL));
            res.mode = 'commit';
            res.changeLogId = log.Id;
            res.message = 'Started in the background (' + job.Id + '). ' + res.message;
            res.nextStep = 'Track with track_codey_job jobId=' + job.Id + '; when completed, share the results file and summarise valid / partial / invalid and serviceable counts.';
            return res;
        } catch (Exception e) {
            if (mode == 'commit' && log != null) CodeyCore.markFailed(log, e.getMessage());
            return CodeyResult.fail(mode, e);
        }
    }

    static List<Map<String, Object>> slice(List<Map<String, Object>> l) {
        List<Map<String, Object>> out = new List<Map<String, Object>>();
        for (Map<String, Object> m : l) { if (out.size() >= MAX_ERRORS_SHOWN) break; out.add(m); }
        return out;
    }

    public static Codey_Job__c activeJob(Id quoteId) {
        List<Codey_Job__c> js = [SELECT Id, Name, Tool__c, Status__c, Step__c, Steps_JSON__c, Total__c, Done__c, Failed__c, Message__c, Results_File_Id__c, Quote__c, Cursor__c, CreatedDate
                                 FROM Codey_Job__c WHERE Tool__c = :TOOL AND Quote__c = :quoteId AND Status__c IN ('Queued', 'Running') AND CreatedDate = LAST_N_DAYS:2 ORDER BY CreatedDate DESC LIMIT 1];
        return js.isEmpty() ? null : js[0];
    }

    public static String key(String name, String street, String postal) {
        return ((name == null ? '' : name) + '|' + (street == null ? '' : street) + '|' + (postal == null ? '' : postal)).toLowerCase().replaceAll('[^a-z0-9|]', '');
    }

    public static Plan plan(Request r) {
        Plan p = new Plan();
        p.quote = CodeyCore.findQuote(r.quoteId);
        Set<String> checks = new Set<String>();
        for (String c : CodeyCore.splitList(String.isBlank(r.checks) ? 'address,serviceability' : r.checks)) checks.add(c.toLowerCase());
        p.doAddress = checks.contains('address');
        p.doService = checks.contains('serviceability') || checks.contains('service');
        p.csv = r.membersCsv;
        if (String.isBlank(p.csv) && String.isNotBlank(r.contentDocumentId)) {
            List<ContentVersion> cvs = [SELECT VersionData FROM ContentVersion WHERE ContentDocumentId = :r.contentDocumentId.trim() AND IsLatest = true LIMIT 1];
            if (cvs.isEmpty()) throw new CodeyCore.ToolException('File ' + r.contentDocumentId + ' not found or not shared with you.');
            p.csv = cvs[0].VersionData.toString();
        }
        p.existing = [SELECT COUNT() FROM vlocity_cmt__QuoteMember__c WHERE vlocity_cmt__QuoteId__c = :p.quote.Id];
        if (String.isNotBlank(p.csv)) {
            List<List<String>> rows = CodeyCsv.parse(p.csv);
            if (rows.size() < 2) throw new CodeyCore.ToolException('The spreadsheet needs a header row and at least one data row.');
            p.header = CodeyCsv.mapHeader(rows[0]);
            if (!p.header.containsKey('name') && !p.header.containsKey('street')) throw new CodeyCore.ToolException('No name or address column recognised. Headers found: ' + String.join(rows[0], ', ') + '. Use name/site, street/address, city, state, postal code, country.');
            Set<String> seen = new Set<String>();
            for (vlocity_cmt__QuoteMember__c m : [SELECT Name, vlocity_cmt__StreetAddress__c, vlocity_cmt__PostalCode__c FROM vlocity_cmt__QuoteMember__c WHERE vlocity_cmt__QuoteId__c = :p.quote.Id LIMIT 50000]) {
                seen.add(key(m.Name, m.vlocity_cmt__StreetAddress__c, m.vlocity_cmt__PostalCode__c));
            }
            for (Integer i = 1; i < rows.size(); i++) {
                List<String> row = rows[i];
                p.rows++;
                Map<String, Object> v = new Map<String, Object>{ 'row' => i + 1 };
                for (String col : new List<String>{ 'name', 'street', 'city', 'state', 'postal', 'country' }) {
                    Integer idx = p.header.get(col);
                    v.put(col, idx == null || idx >= row.size() ? null : row[idx]);
                }
                String name = (String) v.get('name');
                if (String.isBlank(name)) { name = (String) v.get('street'); v.put('name', name); }
                List<String> a = CodeyBulkCheck.addressCheck((String) v.get('street'), (String) v.get('city'), (String) v.get('state'), (String) v.get('postal'), (String) v.get('country'));
                if (String.isBlank(name)) { v.put('reason', 'No name and no street'); p.errors.add(v); continue; }
                if (name.length() > 80) v.put('name', name.left(80));
                if (a[0] == 'Invalid') { v.put('reason', a[1]); p.errors.add(v); continue; }
                String k = key((String) v.get('name'), (String) v.get('street'), (String) v.get('postal'));
                if (seen.contains(k)) { p.duplicates++; continue; }
                seen.add(k);
                List<String> parts = new List<String>();
                for (String col : new List<String>{ 'street', 'city', 'state', 'postal', 'country' }) if (String.isNotBlank((String) v.get(col))) parts.add((String) v.get(col));
                v.put('addressText', String.join(parts, ', '));
                p.valid.add(v);
            }
        }
        if (p.doAddress || p.doService) {
            Boolean only = r.onlyUnchecked != false;
            Integer existingToCheck = only
                ? [SELECT COUNT() FROM vlocity_cmt__QuoteMember__c WHERE vlocity_cmt__QuoteId__c = :p.quote.Id AND vlocity_cmt__AddressValidationResult__c = null AND vlocity_cmt__ServiceabilityLastCheckedDate__c = null]
                : p.existing;
            p.toCheck = existingToCheck + p.valid.size();
        }
        return p;
    }
}
