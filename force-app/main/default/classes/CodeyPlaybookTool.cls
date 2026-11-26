/**
 * Codey tool get_codey_playbook (read-only).
 * Serves the playbook, the 8 skills, the 11 runbooks and the 3 knowledge packs to any AI surface, so every agent
 * (Claude, ChatGPT, Slack, Vibes, Agentforce, ESM Coworker) follows the same instructions as the repo.
 * With a quoteId, concept answers get real examples from the org (members, groups, lines, orders).
 */
public with sharing class CodeyPlaybookTool {

    public static final String TOOL = 'get_codey_playbook';

    public class Request {
        @InvocableVariable(label='Topic' description='overview (default), routing, rules, tools, cards, skill:<name> (fresh-install, settings-health-check, permissions, upgrade-check, concepts-guide, pricing, customization, bulk-members), runbook:US-01..US-11, concept:<key> or concept:all, settings, releases, index or all.')
        public String topic;
        @InvocableVariable(label='Quote' description='Optional Enterprise Quote Id or name: adds real examples from this quote to concept answers.')
        public String quoteId;
        @InvocableVariable(label='Surface' description='Optional: where the request comes from (Claude, ChatGPT, Slack, Agentforce, Coworker).')
        public String surface;
    }

    @InvocableMethod(label='get_codey_playbook' description='Read-only. Project Codey ESM playbook, skills, runbooks and knowledge packs (concepts, recommended settings, release changes). Call FIRST in a new conversation, then follow the skill it routes to.')
    public static List<CodeyResult> run(List<Request> requests) {
        List<CodeyResult> out = new List<CodeyResult>();
        for (Request r : requests) out.add(handle(r));
        return out;
    }

    public static CodeyResult handle(Request r) {
        try {
            String topic = String.isBlank(r.topic) ? 'overview' : r.topic.trim().toLowerCase().replace(' ', '');
            Map<String, String> playbook = CodeyCore.sections(CodeyCore.staticText('Codey_Playbook'));
            Map<String, String> concepts = CodeyCore.sections(CodeyCore.staticText('Codey_Concepts_Pack'));
            List<String> parts = new List<String>();
            Map<String, Object> details = new Map<String, Object>();

            if (topic == 'index') {
                List<String> keys = new List<String>(playbook.keySet());
                for (String k : concepts.keySet()) keys.add('concept:' + k);
                keys.add('settings'); keys.add('releases');
                details.put('topics', keys);
                parts.add('Available topics: ' + String.join(keys, ', '));
            } else if (topic == 'all') {
                parts.addAll(playbook.values());
            } else if (topic == 'settings') {
                parts.add(settingsText());
            } else if (topic == 'releases') {
                parts.add(CodeyCore.staticText('Codey_Release_Change_List'));
            } else if (topic.startsWith('concept:')) {
                String key = topic.substringAfter('concept:');
                if (key == 'all' || String.isBlank(key)) parts.addAll(concepts.values());
                else if (concepts.containsKey(key)) parts.add(concepts.get(key));
                else throw new CodeyCore.ToolException('Unknown concept "' + key + '". Concepts: ' + String.join(new List<String>(concepts.keySet()), ', ') + '.');
                if (String.isNotBlank(r.quoteId)) {
                    Map<String, Object> ex = orgExample(r.quoteId);
                    details.put('orgExample', ex);
                    parts.add('### Example from your org\n' + String.valueOf(ex.get('text')));
                }
            } else {
                if (!playbook.containsKey(topic)) {
                    // allow "pricing" for "skill:pricing" and "US-07" for "runbook:US-07"
                    if (playbook.containsKey('skill:' + topic)) topic = 'skill:' + topic;
                    else if (playbook.containsKey('runbook:' + topic)) topic = 'runbook:' + topic;
                    else throw new CodeyCore.ToolException('Unknown topic "' + r.topic + '". Call with topic=index to list topics.');
                }
                parts.add(playbook.get(topic));
                if (topic.startsWith('skill:') || topic.startsWith('runbook:')) {
                    // golden rules travel with every skill
                    if (playbook.containsKey('rules')) parts.add(playbook.get('rules'));
                }
            }
            String text = String.join(parts, '\n\n');
            details.put('topic', topic);
            details.put('content', text);
            CodeyCore.logRead(TOOL, topic, new Map<String, Object>{ 'topic' => topic, 'quoteId' => r.quoteId, 'surface' => r.surface });
            CodeyResult res = CodeyResult.ok('read', text.left(30000), details);
            res.nextStep = topic == 'overview' ? 'Pick the skill from the routing table (topic=routing) and load it with topic=skill:<name>.' : 'Follow the steps; every change is preview -> explicit approval -> commit.';
            return res;
        } catch (Exception e) {
            return CodeyResult.fail('read', e);
        }
    }

    /** Recommended settings, permission sets per user type and admin jobs, from Custom Metadata (what the org actually uses). */
    public static String settingsText() {
        List<String> lines = new List<String>{ '## recommended-settings', '| Area | Setting | Rule | Severity | Why |', '|---|---|---|---|---|' };
        for (Codey_Recommended_Setting__mdt s : [SELECT Area__c, Label__c, Target__c, Operator__c, Recommended__c, Severity__c, Reason__c FROM Codey_Recommended_Setting__mdt WHERE Active__c = true ORDER BY Area__c, DeveloperName]) {
            lines.add('| ' + s.Area__c + ' | ' + s.Label__c + ' | ' + s.Operator__c + (String.isBlank(s.Recommended__c) ? '' : ' ' + s.Recommended__c) + ' | ' + s.Severity__c + ' | ' + s.Reason__c + ' |');
        }
        lines.add('\n## permission-sets-per-user-type');
        for (Codey_UserType_Permission__mdt u : [SELECT User_Type__c, Permission_Sets__c, Note__c FROM Codey_UserType_Permission__mdt WHERE Active__c = true ORDER BY User_Type__c]) {
            lines.add('- ' + u.User_Type__c + ': ' + u.Permission_Sets__c + (String.isBlank(u.Note__c) ? '' : ' (' + u.Note__c + ')'));
        }
        lines.add('\n## admin-jobs (documented order)');
        for (Codey_Admin_Job__mdt j : [SELECT Order__c, Label__c, Mode__c, Groups__c, Note__c FROM Codey_Admin_Job__mdt WHERE Active__c = true ORDER BY Order__c]) {
            lines.add(String.valueOf(j.Order__c.intValue()) + '. ' + j.Label__c + ' – ' + j.Mode__c + ' (' + j.Groups__c + ')' + (String.isBlank(j.Note__c) ? '' : ' – ' + j.Note__c));
        }
        return String.join(lines, '\n');
    }

    /** Real numbers from a quote so explanations use the customer's own data. */
    public static Map<String, Object> orgExample(String quoteRef) {
        Quote q = CodeyCore.findQuote(quoteRef);
        Integer members = [SELECT COUNT() FROM vlocity_cmt__QuoteMember__c WHERE vlocity_cmt__QuoteId__c = :q.Id];
        Integer groups = [SELECT COUNT() FROM vlocity_cmt__QuoteGroup__c WHERE vlocity_cmt__QuoteId__c = :q.Id];
        Integer lines = [SELECT COUNT() FROM QuoteLineItem WHERE QuoteId = :q.Id];
        Integer groupLines = [SELECT COUNT() FROM QuoteLineItem WHERE QuoteId = :q.Id AND vlocity_cmt__QuoteGroupId__c != null AND vlocity_cmt__QuoteMemberId__c = null];
        Integer memberLines = [SELECT COUNT() FROM QuoteLineItem WHERE QuoteId = :q.Id AND vlocity_cmt__QuoteMemberId__c != null];
        Integer orders = [SELECT COUNT() FROM Order WHERE QuoteId = :q.Id];
        List<String> groupInfo = new List<String>();
        for (AggregateResult ar : [SELECT vlocity_cmt__QuoteGroupId__r.Name g, COUNT(Id) c FROM vlocity_cmt__QuoteMember__c
                                   WHERE vlocity_cmt__QuoteId__c = :q.Id AND vlocity_cmt__QuoteGroupId__c != null
                                   GROUP BY vlocity_cmt__QuoteGroupId__r.Name ORDER BY COUNT(Id) DESC LIMIT 5]) {
            groupInfo.add(String.valueOf(ar.get('g')) + ' (' + String.valueOf(ar.get('c')) + ' members)');
        }
        String text = 'Quote "' + q.Name + '" (' + (q.RecordType == null ? 'Quote' : q.RecordType.DeveloperName) + ') for ' + (q.Account == null ? 'no account' : q.Account.Name) + ': '
            + members + ' quote members, ' + groups + ' quote groups, ' + lines + ' quote line items (' + groupLines + ' group-level, ' + memberLines + ' member-level), '
            + orders + ' orders.' + (groupInfo.isEmpty() ? '' : ' Largest groups: ' + String.join(groupInfo, ', ') + '.');
        return new Map<String, Object>{ 'quoteId' => q.Id, 'quoteName' => q.Name, 'members' => members, 'groups' => groups, 'lines' => lines,
            'groupLines' => groupLines, 'memberLines' => memberLines, 'orders' => orders, 'largestGroups' => groupInfo, 'text' => text };
    }
}
