/** Common output of every Project Codey tool, so every surface gets the same shape (text + structured details + HXL card). */
public class CodeyResult {
    @InvocableVariable(label='Success' description='True when the request worked. A preview or check that found problems still returns true with the problems listed.')
    public Boolean success;
    @InvocableVariable(label='Mode' description='read, preview, commit, status or undo')
    public String mode;
    @InvocableVariable(label='Message' description='Plain-language summary to show the person')
    public String message;
    @InvocableVariable(label='Preview Token' description='Returned by a preview. After the person explicitly approves, call again with mode=commit, this token and the SAME inputs.')
    public String previewToken;
    @InvocableVariable(label='Result JSON' description='Structured details (rows, steps, prices, members) as JSON')
    public String resultJson;
    @InvocableVariable(label='Job Id' description='Codey job id when work continues in the background. Track it with track_codey_job.')
    public String jobId;
    @InvocableVariable(label='Change Log Id' description='Codey Change Log record for this preview or commit (audit, undo).')
    public String changeLogId;
    @InvocableVariable(label='Next Step' description='Suggested next action')
    public String nextStep;
    @InvocableVariable(label='Fix' description='How to resolve the problem when success is false')
    public String fix;
    @InvocableVariable(label='Card' description='HXL experience card (Approval, Health check report, Progress tracker or Upgrade impact report) with the same information as the message.')
    public CodeyCard card;

    public static CodeyResult ok(String mode, String message, Object details) {
        CodeyResult r = new CodeyResult();
        r.success = true;
        r.mode = mode;
        r.message = message;
        r.resultJson = details == null ? null : JSON.serialize(details, true);
        return r;
    }

    public static CodeyResult fail(String mode, Exception e) {
        String msg = e.getMessage();
        if (!(e instanceof CodeyCore.ToolException)) msg = e.getTypeName().replace('System.', '') + ': ' + msg;
        return fail(mode, msg);
    }

    public static CodeyResult fail(String mode, String message) {
        CodeyResult r = new CodeyResult();
        r.success = false;
        r.mode = mode;
        r.message = message;
        r.fix = CodeyCore.suggestFix(message);
        r.card = CodeyCards.basic(r, 'Could not complete the request');
        return r;
    }
}
