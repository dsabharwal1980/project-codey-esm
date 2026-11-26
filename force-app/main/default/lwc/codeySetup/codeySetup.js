import { LightningElement } from 'lwc';
import healthCheck from '@salesforce/apex/CodeySetupController.healthCheck';
import upgradeImpact from '@salesforce/apex/CodeySetupController.upgradeImpact';
import recent from '@salesforce/apex/CodeySetupController.recent';
import mapsStatus from '@salesforce/apex/CodeySecureSettingController.status';
import saveMapsKey from '@salesforce/apex/CodeySecureSettingController.saveGoogleMapsKey';

const SCOPES = ['all', 'prereq', 'quoting', 'assets', 'performance', 'console', 'permissions', 'adminjobs'];
const LOG_COLUMNS = [
    { label: 'Log', fieldName: 'name' }, { label: 'Tool', fieldName: 'tool' }, { label: 'Type', fieldName: 'type' },
    { label: 'Target', fieldName: 'target' }, { label: 'Status', fieldName: 'status' }, { label: 'Surface', fieldName: 'surface' },
    { label: 'By', fieldName: 'by' }, { label: 'When', fieldName: 'at' }
];
const JOB_COLUMNS = [
    { label: 'Job', fieldName: 'name' }, { label: 'Tool', fieldName: 'tool' }, { label: 'Status', fieldName: 'status' },
    { label: 'Step', fieldName: 'step' }, { label: 'Progress', fieldName: 'progress' }, { label: 'Started', fieldName: 'at' }
];

/** Codey Setup page: run the health check and upgrade check, enter the Google Maps key securely, see Codey activity. */
export default class CodeySetup extends LightningElement {
    scope = 'all';
    release = '';
    healthCard; healthMessage; upgradeCard; upgradeMessage;
    busy = false; error; hint;
    maps = {}; mapsKey = ''; mapsSaved = false;
    logs = []; jobs = [];
    logColumns = LOG_COLUMNS; jobColumns = JOB_COLUMNS;

    get scopeOptions() { return SCOPES.map((s) => ({ label: s, value: s })); }
    get mapsState() { return this.maps.isSet ? 'Set (hidden)' : 'Not set'; }
    get cannotEditMaps() { return !this.maps.canEdit; }

    connectedCallback() { this.loadMaps(); this.loadRecent(); }

    async run(fn) {
        this.busy = true; this.error = undefined;
        try { return await fn(); } catch (e) { this.error = (e && e.body && e.body.message) || 'Something went wrong'; return undefined; } finally { this.busy = false; }
    }
    handleScope(e) { this.scope = e.detail.value; }
    handleRelease(e) { this.release = e.detail.value; }
    async runHealth() {
        const r = await this.run(() => healthCheck({ scope: this.scope }));
        if (r) { this.healthCard = r.card; this.healthMessage = r.message; this.loadRecent(); }
    }
    async runUpgrade() {
        const r = await this.run(() => upgradeImpact({ targetRelease: this.release || null }));
        if (r) { this.upgradeCard = r.card; this.upgradeMessage = r.message; this.loadRecent(); }
    }
    handleCardAction(e) { this.hint = 'Ask your Codey agent (Slack, Claude, Agentforce or the Coworker): "' + e.detail.message + '"'; }
    async loadMaps() { const r = await this.run(() => mapsStatus()); if (r) this.maps = r; }
    handleMapsKey(e) { this.mapsKey = e.detail.value; }
    async saveMaps() {
        const r = await this.run(() => saveMapsKey({ value: this.mapsKey }));
        this.mapsKey = '';
        if (r) { this.maps = r; this.mapsSaved = true; this.loadRecent(); }
    }
    async loadRecent() { const r = await this.run(() => recent()); if (r) { this.logs = r.logs; this.jobs = r.jobs; } }
}
