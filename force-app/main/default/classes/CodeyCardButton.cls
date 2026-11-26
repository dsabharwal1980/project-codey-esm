/** Project Codey HXL card button: opens a link or sends a message back to the agent (which then follows preview -> approve -> commit). */
global class CodeyCardButton {
    @AuraEnabled global String label;
    @AuraEnabled global String variant;
    @AuraEnabled global Boolean isLink = false;
    @AuraEnabled global Boolean isMessage = false;
    @AuraEnabled global String url;
    @AuraEnabled global String message;
}
