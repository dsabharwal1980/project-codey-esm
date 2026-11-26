/** Project Codey HXL card row: a setting, a change, a job step or a screen - with status badge, optional bar, action and help link. */
global class CodeyCardItem {
    @AuraEnabled global String icon;
    @AuraEnabled global String iconColor;
    @AuraEnabled global String title;
    @AuraEnabled global String subtitle;
    @AuraEnabled global String value;
    @AuraEnabled global String detail;
    @AuraEnabled global Boolean hasBar = false;
    @AuraEnabled global Decimal percent;
    @AuraEnabled global String barColor;
    @AuraEnabled global Boolean hasBadge = false;
    @AuraEnabled global String badgeLabel;
    @AuraEnabled global String badgeVariant;
    @AuraEnabled global Boolean hasBefore = false;
    @AuraEnabled global String beforeValue;
    @AuraEnabled global String afterValue;
    @AuraEnabled global Boolean hasAction = false;
    @AuraEnabled global String actionLabel;
    @AuraEnabled global String actionMessage;
    @AuraEnabled global Boolean hasLink = false;
    @AuraEnabled global String linkLabel;
    @AuraEnabled global String linkUrl;
}
