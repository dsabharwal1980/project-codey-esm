/**
 * Codey tool preview_esm_price - PRD agent tool 2 "Price preview tool".
 * Prices a sample quote with the given products (and options) through the standard CPQ cart actions and shows the
 * total, the price per line, each pricing step and the promotions and discounts applied - WITHOUT saving anything:
 * the whole sample runs inside a savepoint that is rolled back (no test quotes left behind).
 * Also: explainPlan=true lists the pricing plan steps; quoteId explains an existing quote's prices (read-only);
 * proposedStepJson simulates a new pricing plan step (before vs after) for the Pricing skill;
 * mode=commit keeps the sample as a "Codey Test Quote" after approval (Fresh install: test Enterprise Quote).
 */
public with sharing class CodeyPricePreviewTool {

    public static final String TOOL = 'preview_esm_price';

    public class Request {
        @InvocableVariable(label='Mode' description='preview (default, nothing saved) or commit (keep the sample as a test quote, after approval with the same inputs and previewToken).')
        public String mode;
        @InvocableVariable(label='Products' description='Comma-separated product names, codes or Ids to price on a sample quote.')
        public String products;
        @InvocableVariable(label='Quantity' description='Quantity per product (default 1).')
        public Integer quantity;
        @InvocableVariable(label='Account' description='Account Id or name for the sample (default: the CPQ template account).')
        public String account;
        @InvocableVariable(label='Price List' description='Price list name (default: B2B Pricelist or the first active one).')
        public String priceList;
        @InvocableVariable(label='Quote' description='Explain the prices of this existing quote instead (read-only): lines, steps, promotions, discounts.')
        public String quoteId;
        @InvocableVariable(label='Explain Plan' description='true: list the pricing plan steps in order (read-only).')
        public Boolean explainPlan;
        @InvocableVariable(label='Proposed Step JSON' description='Optional pricing plan step to simulate on the sample: {"name","sequence","implementation","method","parameters"}. Shows before vs after; nothing saved.')
        public String proposedStepJson;
        @InvocableVariable(label='Preview Token' description='From the preview, for mode=commit.')
        public String previewToken;
        @InvocableVariable(label='Confirm Production' description='true only when the person confirmed keeping a test quote in a production org.')
        public Boolean confirmProduction;
        @InvocableVariable(label='Surface' description='Optional: where the request comes from.')
        public String surface;
    }

    @InvocableMethod(label='preview_esm_price' description='Price a sample quote and show every pricing step, promotions and discounts without saving anything (rolled back). Or explain the pricing plan (explainPlan=true) or an existing quote\'s prices (quoteId). mode=commit keeps the sample as a test quote after approval.')
    public static List<CodeyResult> run(List<Request> requests) {
        List<CodeyResult> out = new List<CodeyResult>();
        for (Request r : requests) out.add(handle(r));
        return out;
    }

    @TestVisible static CartApi cart = new LiveCartApi();

    static Map<String, Object> inputs(Request r) {
        return new Map<String, Object>{ 'products' => r.products, 'quantity' => r.quantity, 'account' => r.account, 'priceList' => r.priceList, 'proposedStepJson' => r.proposedStepJson, 'surface' => r.surface };
    }

    public static CodeyResult handle(Request r) {
        String mode = String.isBlank(r.mode) ? 'preview' : r.mode.trim().toLowerCase();
        try {
            if (r.explainPlan == true) return explainPlan();
            if (String.isNotBlank(r.quoteId) && String.isBlank(r.products)) return explainQuote(r.quoteId, r.surface);
            if (String.isBlank(r.products)) throw new CodeyCore.ToolException('Give products to price (names, codes or Ids), a quoteId to explain, or explainPlan=true.');
            Codey_Change_Log__c log;
            if (mode == 'commit') {
                CodeyCore.guardProduction(r.confirmProduction);   // before the preview is used, so a refusal keeps the preview open
                log = CodeyCore.requireApproval(TOOL, inputs(r), r.previewToken);
            } else if (mode != 'preview') {
                throw new CodeyCore.ToolException('Unknown mode "' + r.mode + '". Use preview or commit.');
            }
            Savepoint sp = Database.setSavepoint();
            Map<String, Object> priced;
            Map<String, Object> before;
            Id quoteId;
            try {
                quoteId = sampleQuote(r, mode == 'commit');
                priced = readQuote(quoteId);
                if (String.isNotBlank(r.proposedStepJson)) {
                    before = priced;
                    insertProposedStep(r.proposedStepJson);
                    cart.reprice(quoteId);
                    priced = readQuote(quoteId);
                }
            } finally {
                if (mode != 'commit') Database.rollback(sp);   // nothing is left behind
            }
            Map<String, Object> details = new Map<String, Object>{ 'saved' => mode == 'commit', 'priced' => priced, 'before' => before };
            String msg = summary(priced, before) + (mode == 'commit' ? ' Kept as test quote ' + priced.get('quoteName') + '.' : ' Nothing was saved.');
            CodeyResult res = CodeyResult.ok(mode, msg, details);
            if (mode == 'preview') {
                log = CodeyCore.logPreview(TOOL, 'pricePreview', r.products, before == null ? null : before.get('totals'), priced.get('totals'), inputs(r));
                res.previewToken = log.Preview_Token__c;
                res.changeLogId = log.Id;
                res.card = priceCard(priced, before, log.Preview_Token__c);
                res.nextStep = 'Explain the steps. If the person wants a test quote kept (fresh install), ask for approval and call mode=commit with the same inputs and previewToken.';
            } else {
                CodeyCore.markCommitted(log, priced.get('totals'), new List<Id>{ quoteId });
                res.changeLogId = log.Id;
                res.card = priceCard(priced, before, null);
                res.card.title = 'Test quote kept';
                res.nextStep = 'Run check_esm_setup to finish the fresh install.';
            }
            return res;
        } catch (Exception e) {
            return CodeyResult.fail(mode, e);
        }
    }

    // ------------------------------------------------------------------ sample quote
    static Id sampleQuote(Request r, Boolean keep) {
        Account acc = account(r.account);
        vlocity_cmt__PriceList__c pl = priceList(r.priceList);
        Opportunity o = new Opportunity(Name = (keep ? 'Codey Test ' : 'Codey price preview ') + Date.today().format(), AccountId = acc.Id, CloseDate = Date.today().addDays(30), StageName = firstStage());
        insert o;
        String name = (keep ? 'Codey Test Quote ' : 'Codey price preview ') + System.now().format('yyyy-MM-dd HH:mm');
        Id quoteId = cart.createCart(acc.Id, o.Id, name, pl.Name);
        Integer qty = r.quantity == null || r.quantity < 1 ? 1 : r.quantity;
        for (String ref : CodeyCore.splitList(r.products)) {
            Id pid = CodeyApplyChangeTool.productId(ref);
            List<PricebookEntry> pbes = [SELECT Id FROM PricebookEntry WHERE Product2Id = :pid AND Pricebook2Id = :pl.vlocity_cmt__Pricebook2Id__c AND IsActive = true LIMIT 1];
            if (pbes.isEmpty()) throw new CodeyCore.ToolException('Product "' + ref + '" has no active entry in price list ' + pl.Name + '.');
            cart.addProduct(quoteId, pbes[0].Id, qty);
        }
        return quoteId;
    }

    static Account account(String ref) {
        List<Account> as2;
        if (String.isNotBlank(ref)) {
            String v = ref.trim();
            as2 = [SELECT Id, Name FROM Account WHERE Id = :(v.startsWith('001') && v.length() >= 15 ? v : null) OR Name = :v LIMIT 2];
            if (as2.size() != 1) throw new CodeyCore.ToolException('Account "' + v + '" ' + (as2.isEmpty() ? 'not found' : 'is not unique') + '.');
            return as2[0];
        }
        String tmpl = CodeyCore.cpqValue('TEMPLATE_ACCOUNT_CONFIG_KEY');
        if (String.isNotBlank(tmpl) && tmpl.startsWith('001')) {
            as2 = [SELECT Id, Name FROM Account WHERE Id = :tmpl LIMIT 1];
            if (!as2.isEmpty()) return as2[0];
        }
        as2 = [SELECT Id, Name FROM Account ORDER BY CreatedDate ASC LIMIT 1];
        if (as2.isEmpty()) throw new CodeyCore.ToolException('No account to price with; give an account.');
        return as2[0];
    }

    static vlocity_cmt__PriceList__c priceList(String name) {
        List<vlocity_cmt__PriceList__c> pls;
        if (String.isNotBlank(name)) pls = [SELECT Id, Name, vlocity_cmt__Pricebook2Id__c FROM vlocity_cmt__PriceList__c WHERE Name = :name.trim() OR vlocity_cmt__Code__c = :name.trim() LIMIT 1];
        else {
            pls = [SELECT Id, Name, vlocity_cmt__Pricebook2Id__c FROM vlocity_cmt__PriceList__c WHERE Name = 'B2B Pricelist' LIMIT 1];
            if (pls.isEmpty()) pls = [SELECT Id, Name, vlocity_cmt__Pricebook2Id__c FROM vlocity_cmt__PriceList__c WHERE vlocity_cmt__IsActive__c = true ORDER BY Name LIMIT 1];
        }
        if (pls.isEmpty()) throw new CodeyCore.ToolException('Price list ' + (String.isBlank(name) ? '' : '"' + name + '" ') + 'not found.');
        return pls[0];
    }

    static String firstStage() {
        for (Schema.PicklistEntry e : Opportunity.StageName.getDescribe().getPicklistValues()) if (e.isActive()) return e.getValue();
        return 'Prospecting';
    }

    static void insertProposedStep(String json) {
        Map<String, Object> f = (Map<String, Object>) System.JSON.deserializeUntyped(json);
        Map<String, Object> l = new Map<String, Object>();
        for (String k : f.keySet()) l.put(k.toLowerCase(), f.get(k));
        vlocity_cmt__PricingPlanStep__c s = new vlocity_cmt__PricingPlanStep__c(
            Name = String.valueOf(l.get('name')),
            vlocity_cmt__PricingPlanId__c = CodeyApplyChangeTool.planId(l.get('plan') == null ? null : String.valueOf(l.get('plan'))),
            vlocity_cmt__Sequence__c = l.get('sequence') == null ? null : Decimal.valueOf(String.valueOf(l.get('sequence'))),
            vlocity_cmt__ImplementationName__c = (String) (l.containsKey('implementation') ? l.get('implementation') : l.get('implementationname')),
            vlocity_cmt__MethodName__c = (String) (l.containsKey('method') ? l.get('method') : l.get('methodname')),
            vlocity_cmt__Parameters__c = l.get('parameters') == null ? null : (l.get('parameters') instanceof String ? (String) l.get('parameters') : System.JSON.serialize(l.get('parameters'))),
            vlocity_cmt__IsActive__c = true);
        insert s;
    }

    // ------------------------------------------------------------------ read prices
    public static Map<String, Object> readQuote(Id quoteId) {
        Quote q = [SELECT Id, Name FROM Quote WHERE Id = :quoteId];
        List<QuoteLineItem> lines = [SELECT Id, Product2.Name, Product2.ProductCode, Quantity, vlocity_cmt__ParentItemId__c, vlocity_cmt__LineNumber__c,
                                     vlocity_cmt__OneTimeCharge__c, vlocity_cmt__OneTimeCalculatedPrice__c, vlocity_cmt__OneTimeManualDiscount__c, vlocity_cmt__OneTimeTotal__c, vlocity_cmt__EffectiveOneTimeTotal__c,
                                     vlocity_cmt__RecurringCharge__c, vlocity_cmt__RecurringCalculatedPrice__c, vlocity_cmt__RecurringManualDiscount__c, vlocity_cmt__RecurringTotal__c, vlocity_cmt__EffectiveRecurringTotal__c,
                                     vlocity_cmt__PricingLogData__c, vlocity_cmt__QuoteMemberId__r.Name, vlocity_cmt__QuoteGroupId__r.Name
                                     FROM QuoteLineItem WHERE QuoteId = :quoteId ORDER BY vlocity_cmt__LineNumber__c LIMIT 200];
        Set<String> promoIds = new Set<String>();
        List<Map<String, Object>> rows = new List<Map<String, Object>>();
        Decimal oneTime = 0, recurring = 0;
        for (QuoteLineItem l : lines) {
            Map<String, Object> ld = logData(l.vlocity_cmt__PricingLogData__c);
            List<Map<String, Object>> steps = new List<Map<String, Object>>();
            for (String code : ld.keySet()) {
                Object raw = ld.get(code);
                if (!(raw instanceof List<Object>)) continue;
                for (Object o : (List<Object>) raw) {
                    Map<String, Object> e = (Map<String, Object>) o;
                    if (e.get('PromotionId') != null) promoIds.add(String.valueOf(e.get('PromotionId')));
                    String kind = e.get('LogType') == 'PRICE' ? 'list price' : (e.get('PromotionId') != null ? 'promotion' : (e.get('DiscountId') != null ? 'discount' : (e.get('PricingAdjustmentId') != null ? 'manual adjustment' : 'rule')));
                    steps.add(new Map<String, Object>{ 'charge' => code, 'sequence' => e.get('LogSequence'), 'kind' => kind, 'text' => e.get('DisplayText'),
                        'start' => e.get('StartValue'), 'end' => e.get('EndValue'), 'promotionId' => e.get('PromotionId'), 'discountId' => e.get('DiscountId') });
                }
            }
            if (l.vlocity_cmt__ParentItemId__c == null) {
                oneTime += nz(l.vlocity_cmt__EffectiveOneTimeTotal__c != null ? l.vlocity_cmt__EffectiveOneTimeTotal__c : l.vlocity_cmt__OneTimeTotal__c);
                recurring += nz(l.vlocity_cmt__EffectiveRecurringTotal__c != null ? l.vlocity_cmt__EffectiveRecurringTotal__c : l.vlocity_cmt__RecurringTotal__c);
            }
            rows.add(new Map<String, Object>{ 'lineId' => l.Id, 'product' => l.Product2.Name, 'code' => l.Product2.ProductCode, 'quantity' => l.Quantity, 'isRoot' => l.vlocity_cmt__ParentItemId__c == null,
                'member' => l.vlocity_cmt__QuoteMemberId__r == null ? null : l.vlocity_cmt__QuoteMemberId__r.Name, 'group' => l.vlocity_cmt__QuoteGroupId__r == null ? null : l.vlocity_cmt__QuoteGroupId__r.Name,
                'oneTimeList' => l.vlocity_cmt__OneTimeCharge__c, 'oneTimeNet' => l.vlocity_cmt__OneTimeTotal__c, 'recurringList' => l.vlocity_cmt__RecurringCharge__c,
                'recurringNet' => l.vlocity_cmt__RecurringTotal__c, 'oneTimeManualDiscount' => l.vlocity_cmt__OneTimeManualDiscount__c, 'recurringManualDiscount' => l.vlocity_cmt__RecurringManualDiscount__c,
                'steps' => steps });
        }
        Map<String, String> promoNames = new Map<String, String>();
        if (!promoIds.isEmpty()) for (vlocity_cmt__Promotion__c p : [SELECT Id, Name FROM vlocity_cmt__Promotion__c WHERE Id IN :promoIds]) promoNames.put(String.valueOf(p.Id).left(15), p.Name);
        List<Map<String, Object>> promos = new List<Map<String, Object>>();
        for (vlocity_cmt__QuoteAppliedPromotion__c ap : [SELECT vlocity_cmt__PromotionId__r.Name, vlocity_cmt__Action__c, vlocity_cmt__QuoteLineItemId__r.Product2.Name FROM vlocity_cmt__QuoteAppliedPromotion__c WHERE vlocity_cmt__QuoteId__c = :quoteId LIMIT 50]) {
            promos.add(new Map<String, Object>{ 'promotion' => ap.vlocity_cmt__PromotionId__r == null ? null : ap.vlocity_cmt__PromotionId__r.Name, 'action' => ap.vlocity_cmt__Action__c,
                'line' => ap.vlocity_cmt__QuoteLineItemId__r == null ? null : ap.vlocity_cmt__QuoteLineItemId__r.Product2.Name });
        }
        List<Map<String, Object>> discounts = new List<Map<String, Object>>();
        for (vlocity_cmt__QuoteDiscount__c d : [SELECT Name, vlocity_cmt__Status__c, vlocity_cmt__ApprovalStatus__c, vlocity_cmt__DiscountType__c FROM vlocity_cmt__QuoteDiscount__c WHERE vlocity_cmt__QuoteId__c = :quoteId LIMIT 50]) {
            discounts.add(new Map<String, Object>{ 'name' => d.Name, 'status' => d.vlocity_cmt__Status__c, 'approval' => d.vlocity_cmt__ApprovalStatus__c, 'type' => d.vlocity_cmt__DiscountType__c });
        }
        for (Map<String, Object> row : rows) for (Object o : (List<Object>) row.get('steps')) {
            Map<String, Object> s = (Map<String, Object>) o;
            if (s.get('promotionId') != null && promoNames.containsKey(String.valueOf(s.get('promotionId')).left(15))) s.put('text', 'Promotion ' + promoNames.get(String.valueOf(s.get('promotionId')).left(15)) + ': ' + s.get('text'));
        }
        // Totals and counts always cover the WHOLE quote; the line-by-line detail above is capped at 200 lines for readability.
        Integer totalLines = [SELECT COUNT() FROM QuoteLineItem WHERE QuoteId = :quoteId];
        if (totalLines > lines.size()) {
            AggregateResult ar = [SELECT SUM(vlocity_cmt__EffectiveOneTimeTotal__c) eo, SUM(vlocity_cmt__EffectiveRecurringTotal__c) er,
                                  SUM(vlocity_cmt__OneTimeTotal__c) o, SUM(vlocity_cmt__RecurringTotal__c) r
                                  FROM QuoteLineItem WHERE QuoteId = :quoteId AND vlocity_cmt__ParentItemId__c = null];
            oneTime = ar.get('eo') != null ? (Decimal) ar.get('eo') : nz((Decimal) ar.get('o'));
            recurring = ar.get('er') != null ? (Decimal) ar.get('er') : nz((Decimal) ar.get('r'));
        }
        Integer promoCount = [SELECT COUNT() FROM vlocity_cmt__QuoteAppliedPromotion__c WHERE vlocity_cmt__QuoteId__c = :quoteId];
        Integer discountCount = [SELECT COUNT() FROM vlocity_cmt__QuoteDiscount__c WHERE vlocity_cmt__QuoteId__c = :quoteId];
        return new Map<String, Object>{ 'quoteId' => q.Id, 'quoteName' => q.Name, 'lines' => rows, 'promotions' => promos, 'discounts' => discounts,
            'totals' => new Map<String, Object>{ 'oneTime' => oneTime, 'recurring' => recurring, 'lines' => totalLines, 'linesShown' => rows.size(),
                'promotions' => promoCount, 'discounts' => discountCount }, 'planSteps' => planSteps() };
    }

    static Map<String, Object> logData(String raw) {
        if (String.isBlank(raw)) return new Map<String, Object>();
        try {
            Map<String, Object> pl = (Map<String, Object>) System.JSON.deserializeUntyped(raw);
            Object ld = pl.get('LogData');
            return ld instanceof Map<String, Object> ? (Map<String, Object>) ld : new Map<String, Object>();
        } catch (Exception e) { return new Map<String, Object>(); }
    }

    public static List<Map<String, Object>> planSteps() {
        List<Map<String, Object>> out = new List<Map<String, Object>>();
        Id plan;
        try { plan = CodeyApplyChangeTool.planId(null); } catch (Exception e) { return out; }
        for (vlocity_cmt__PricingPlanStep__c s : [SELECT Id, Name, vlocity_cmt__Sequence__c, vlocity_cmt__ImplementationName__c, vlocity_cmt__MethodName__c, vlocity_cmt__IsActive__c, vlocity_cmt__Description__c
                                                   FROM vlocity_cmt__PricingPlanStep__c WHERE vlocity_cmt__PricingPlanId__c = :plan ORDER BY vlocity_cmt__Sequence__c]) {
            out.add(new Map<String, Object>{ 'id' => s.Id, 'sequence' => s.vlocity_cmt__Sequence__c, 'name' => s.Name, 'implementation' => s.vlocity_cmt__ImplementationName__c,
                'method' => s.vlocity_cmt__MethodName__c, 'active' => s.vlocity_cmt__IsActive__c, 'description' => s.vlocity_cmt__Description__c });
        }
        return out;
    }

    static CodeyResult explainPlan() {
        List<Map<String, Object>> steps = planSteps();
        List<String> lines = new List<String>();
        List<CodeyCards.StepRow> rows = new List<CodeyCards.StepRow>();
        for (Map<String, Object> s : steps) {
            lines.add(seq(s.get('sequence')) + '. ' + s.get('name') + (s.get('active') == true ? '' : ' (inactive)') + ' – ' + s.get('implementation') + (s.get('method') == null ? '' : '.' + s.get('method')));
            CodeyCards.StepRow r = new CodeyCards.StepRow();
            r.label = seq(s.get('sequence')) + '. ' + s.get('name');
            r.status = s.get('active') == true ? 'Active' : 'Inactive';
            r.detail = String.valueOf(s.get('implementation')) + (s.get('method') == null ? '' : ' · ' + s.get('method'));
            rows.add(r);
        }
        CodeyResult res = CodeyResult.ok('read', 'Pricing plan (' + CodeyCore.cpqValue('DefaultPricingPlan') + '), ' + steps.size() + ' steps in order:\n' + String.join(lines, '\n'), new Map<String, Object>{ 'steps' => steps });
        res.card = CodeyCards.progress('Pricing plan steps', String.valueOf(CodeyCore.cpqValue('DefaultPricingPlan')), 'Completed', 100, rows, null, null, null);
        res.card.cardType = 'planSteps'; res.card.hasProgress = false; res.card.badgeLabel = steps.size() + ' steps';
        res.nextStep = 'Explain each step in one line (concept:pricing-plan). For a change, use apply_esm_change changeType=pricingPlanStep with a preview.';
        return res;
    }

    static CodeyResult explainQuote(String ref, String surface) {
        Quote q = CodeyCore.findQuote(ref);
        Map<String, Object> priced = readQuote(q.Id);
        CodeyResult res = CodeyResult.ok('read', summary(priced, null) + ' (existing quote, read-only)', new Map<String, Object>{ 'priced' => priced });
        res.card = priceCard(priced, null, null);
        res.card.title = 'Prices on ' + q.Name;
        res.nextStep = 'Explain which promotions and discounts applied, at which step, and why (concept:promotions-vs-discounts).';
        CodeyCore.logRead(TOOL, q.Name, new Map<String, Object>{ 'quoteId' => q.Id, 'surface' => surface });
        return res;
    }

    static String summary(Map<String, Object> priced, Map<String, Object> before) {
        Map<String, Object> t = (Map<String, Object>) priced.get('totals');
        Integer shown = t.get('linesShown') == null ? null : (Integer) t.get('linesShown');
        String s = 'Priced ' + t.get('lines') + ' lines' + (shown != null && shown < (Integer) t.get('lines') ? ' (step detail for the first ' + shown + ')' : '')
            + ': one-time ' + CodeyCore.money((Decimal) t.get('oneTime')) + ', recurring ' + CodeyCore.money((Decimal) t.get('recurring')) + ' per month; '
            + count(t, 'promotions', priced) + ' promotions, ' + count(t, 'discounts', priced) + ' discounts.';
        if (before != null) {
            Map<String, Object> b = (Map<String, Object>) before.get('totals');
            s += ' Before the proposed step: one-time ' + CodeyCore.money((Decimal) b.get('oneTime')) + ', recurring ' + CodeyCore.money((Decimal) b.get('recurring')) + ' (simulated; a cached pricing plan may only show the new step after the change and the pricing admin jobs).';
        }
        return s;
    }

    static CodeyCard priceCard(Map<String, Object> priced, Map<String, Object> before, String token) {
        List<CodeyCards.Change> ch = new List<CodeyCards.Change>();
        for (Object o : (List<Object>) priced.get('lines')) {
            Map<String, Object> l = (Map<String, Object>) o;
            if (l.get('isRoot') != true && ch.size() > 15) continue;
            List<String> trail = new List<String>();
            for (Object so : (List<Object>) l.get('steps')) {
                Map<String, Object> s = (Map<String, Object>) so;
                if (s.get('kind') != 'list price') trail.add(s.get('kind') + ' ' + s.get('start') + '→' + s.get('end'));
            }
            CodeyCards.Change c = new CodeyCards.Change(String.valueOf(l.get('product')) + (l.get('quantity') == null ? '' : ' ×' + l.get('quantity')), token == null ? 'Priced' : 'Preview',
                'list ' + fmt(l.get('recurringList')) + '/mo · ' + fmt(l.get('oneTimeList')) + ' one-time',
                'net ' + fmt(l.get('recurringNet')) + '/mo · ' + fmt(l.get('oneTimeNet')) + ' one-time');
            c.detail = trail.isEmpty() ? null : String.join(trail, '; ');
            ch.add(c);
        }
        Map<String, Object> t = (Map<String, Object>) priced.get('totals');
        CodeyCard card = CodeyCards.approval(token == null ? 'Price breakdown' : 'Price preview (not saved)', 'Recurring ' + CodeyCore.money((Decimal) t.get('recurring')) + '/mo · one-time ' + CodeyCore.money((Decimal) t.get('oneTime')), ch, token,
            count(t, 'promotions', priced) + ' promotions, ' + count(t, 'discounts', priced) + ' discounts applied' + (t.get('linesShown') != null && (Integer) t.get('linesShown') < (Integer) t.get('lines') ? '; totals cover all ' + t.get('lines') + ' lines.' : '.'));
        card.cardType = 'price';
        card.badgeLabel = token == null ? 'Read only' : 'Not saved';
        card.badgeVariant = 'info';
        if (token != null && !card.buttons.isEmpty()) { card.buttons[0].label = 'Keep as test quote'; card.buttons[0].message = 'Approve – keep this sample as a test quote (preview token ' + token + ').'; card.buttons[1].label = 'Done'; card.buttons[1].message = 'No need to keep the sample quote.'; }
        if (before != null) {
            Map<String, Object> b = (Map<String, Object>) before.get('totals');
            CodeyCards.callout(card, 'Price effect of the proposed step', 'Recurring ' + CodeyCore.money((Decimal) b.get('recurring')) + ' → ' + CodeyCore.money((Decimal) t.get('recurring'))
                + ' · one-time ' + CodeyCore.money((Decimal) b.get('oneTime')) + ' → ' + CodeyCore.money((Decimal) t.get('oneTime')), 'info');
        }
        return card;
    }

    static String seq(Object o) { if (o == null) return '-'; Decimal d = Decimal.valueOf(String.valueOf(o)); return d == d.round() ? String.valueOf(d.intValue()) : String.valueOf(d.stripTrailingZeros()); }
    static Integer count(Map<String, Object> totals, String key, Map<String, Object> priced) {
        return totals.get(key) != null ? (Integer) totals.get(key) : ((List<Object>) priced.get(key)).size();
    }
    static String fmt(Object o) { return o == null ? '0.00' : CodeyCore.money(Decimal.valueOf(String.valueOf(o))); }
    static Decimal nz(Decimal d) { return d == null ? 0 : d; }

    // ------------------------------------------------------------------ CPQ cart actions (standard, from the package)
    public interface CartApi {
        Id createCart(Id accountId, Id opportunityId, String name, String priceListName);
        void addProduct(Id cartId, Id pricebookEntryId, Integer quantity);
        void reprice(Id cartId);
    }

    public class LiveCartApi implements CartApi {
        public Id createCart(Id accountId, Id opportunityId, String name, String priceListName) {
            Map<String, Object> out = invoke('CpqCartCreateCartInvocable', new Map<String, Object>{ 'AccountId' => String.valueOf(accountId), 'OpportunityId' => String.valueOf(opportunityId),
                'Name' => name, 'objectType' => 'Quote', 'priceListName' => priceListName });
            Object id = out.get('Id');
            if (id == null) throw new CodeyCore.ToolException('The CPQ cart was not created: ' + String.valueOf(out.get('error') != null ? out.get('error') : out.get('messages')));
            return (Id) String.valueOf(id);
        }
        public void addProduct(Id cartId, Id pricebookEntryId, Integer quantity) {
            Map<String, Object> out = invoke('CpqCartAddProductInvocable', new Map<String, Object>{ 'cartId' => String.valueOf(cartId), 'itemId' => String.valueOf(pricebookEntryId),
                'quantity' => quantity, 'price' => true, 'validate' => false });
            if (out.get('error') != null && String.valueOf(out.get('error')) != 'OK' && String.isNotBlank(String.valueOf(out.get('error')))) throw new CodeyCore.ToolException('Adding the product failed: ' + out.get('error'));
        }
        public void reprice(Id cartId) {
            invoke('CpqCartGetCartItemsInvocable', new Map<String, Object>{ 'cartId' => String.valueOf(cartId), 'price' => true, 'validate' => false });
        }
        Map<String, Object> invoke(String action, Map<String, Object> params) {
            Invocable.Action a = Invocable.Action.createCustomAction('apex', 'vlocity_cmt', action);
            for (String k : params.keySet()) if (params.get(k) != null) a.setInvocationParameter(k, params.get(k));
            List<Invocable.Action.Result> rs = a.invoke();
            if (rs == null || rs.isEmpty()) throw new CodeyCore.ToolException(action + ' returned nothing.');
            if (!rs[0].isSuccess()) {
                List<String> errs = new List<String>();
                for (Invocable.Action.Error e : rs[0].getErrors()) errs.add(e.getMessage());
                throw new CodeyCore.ToolException(action + ' failed: ' + String.join(errs, '; '));
            }
            return rs[0].getOutputParameters() == null ? new Map<String, Object>() : rs[0].getOutputParameters();
        }
    }
}
