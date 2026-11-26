import { LightningElement, api } from 'lwc';

const BADGE = { success: 'slds-theme_success', warning: 'slds-theme_warning', error: 'slds-theme_error', info: 'slds-theme_info' };

/** Renders a Project Codey card (Approval, Health check report, Progress tracker, Upgrade impact) in Lightning. */
export default class CodeyCard extends LightningElement {
    @api card;

    get c() { return this.card || {}; }
    get badgeClass() { return 'slds-badge ' + (BADGE[this.c.badgeVariant] || ''); }
    get items() {
        return (this.c.items || []).map((it, i) => ({
            ...it,
            key: 'i' + i,
            badgeClass: 'slds-badge ' + (BADGE[it.badgeVariant] || ''),
            iconName: it.iconColor === 'success' ? 'utility:success' : it.iconColor === 'error' ? 'utility:error' : it.iconColor === 'warning' ? 'utility:warning' : 'utility:info'
        }));
    }
    get stats() { return (this.c.stats || []).map((s, i) => ({ ...s, key: 's' + i })); }
    get buttons() { return (this.c.buttons || []).map((b, i) => ({ ...b, key: 'b' + i, brand: b.variant === 'primary' ? 'brand' : 'neutral' })); }
    get calloutClass() {
        const v = this.c.calloutVariant;
        return 'slds-scoped-notification slds-m-top_small ' + (v === 'warning' ? 'slds-theme_warning' : v === 'error' ? 'slds-theme_error' : 'slds-theme_info');
    }

    handleAction(event) {
        const message = event.currentTarget.dataset.message;
        const url = event.currentTarget.dataset.url;
        if (url) { window.open(url, '_blank'); return; }
        // In Lightning the agent is not on this page: hand the message to the parent (shown as "ask your Codey agent")
        this.dispatchEvent(new CustomEvent('cardaction', { detail: { message } }));
    }
}
