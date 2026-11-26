/**
 * Project Codey HXL experience card (one shared data type for the four screens):
 * Approval (Before/After + Approve/Reject), Health check report (OK/Warning/Needs Fix + Fix it + help),
 * Progress tracker (overall bar + steps + Resume) and Upgrade impact report (screen, change, risk, action).
 * cardType tells clients without HXL rendering which layout to imitate. Built by CodeyCards.
 */
global class CodeyCard {
    @AuraEnabled global String cardType;
    @AuraEnabled global String title;
    @AuraEnabled global String subtitle;
    @AuraEnabled global String icon;
    @AuraEnabled global Boolean hasBadge = false;
    @AuraEnabled global String badgeLabel;
    @AuraEnabled global String badgeVariant;
    @AuraEnabled global Boolean hasStats = false;
    @AuraEnabled global List<CodeyCardStat> stats = new List<CodeyCardStat>();
    @AuraEnabled global Boolean hasProgress = false;
    @AuraEnabled global String progressLabel;
    @AuraEnabled global Decimal progressValue;
    @AuraEnabled global String progressColor;
    @AuraEnabled global Boolean hasItems = false;
    @AuraEnabled global String itemsTitle;
    @AuraEnabled global List<CodeyCardItem> items = new List<CodeyCardItem>();
    @AuraEnabled global Boolean hasMore = false;
    @AuraEnabled global String moreLabel;
    @AuraEnabled global Boolean hasCallout = false;
    @AuraEnabled global String calloutTitle;
    @AuraEnabled global String calloutText;
    @AuraEnabled global String calloutVariant;
    @AuraEnabled global Boolean hasNote = false;
    @AuraEnabled global String note;
    @AuraEnabled global Boolean hasButtons = false;
    @AuraEnabled global List<CodeyCardButton> buttons = new List<CodeyCardButton>();
}
