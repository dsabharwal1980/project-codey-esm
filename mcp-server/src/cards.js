// Renders a Project Codey HXL card (the "card" every Codey tool returns) for surfaces without HXL rendering, so the four
// experience screens look the same everywhere: Slack (Block Kit), Microsoft Teams (Adaptive Card), Markdown (Claude, ChatGPT, Vibes).
const EMOJI = { success: ':white_check_mark:', warning: ':warning:', error: ':x:', info: ':information_source:' };

function parts(card) {
  const items = (card.items || []).map((it) => ({
    title: it.title, subtitle: it.subtitle, value: it.value, detail: it.detail,
    badge: it.hasBadge ? it.badgeLabel : null, badgeVariant: it.badgeVariant,
    before: it.hasBefore ? it.beforeValue : null, after: it.hasBefore ? it.afterValue : null,
    action: it.hasAction ? { label: it.actionLabel, message: it.actionMessage } : null,
    link: it.hasLink ? { label: it.linkLabel, url: it.linkUrl } : null,
    percent: it.hasBar ? it.percent : null
  }));
  return { items, stats: card.hasStats ? card.stats || [] : [], buttons: card.hasButtons ? card.buttons || [] : [] };
}
const blank = (s) => !s || !String(s).trim();

export function toMarkdown(card) {
  const { items, stats, buttons } = parts(card);
  const out = [`### ${card.title}${card.hasBadge ? `  \`${card.badgeLabel}\`` : ''}`];
  if (!blank(card.subtitle)) out.push(`_${card.subtitle.trim()}_`);
  if (stats.length) out.push(stats.map((s) => `**${s.label}:** ${s.value}`).join(' · '));
  if (card.hasProgress) out.push(`Progress: ${card.progressValue}% (${card.progressLabel})`);
  if (items.length) {
    out.push(`\n**${card.itemsTitle || 'Items'}**`);
    for (const it of items) {
      let l = `- ${it.badge ? `[${it.badge}] ` : ''}**${it.title}**`;
      if (it.before !== null) l += ` — ${it.before} → **${it.after}**`;
      else if (!blank(it.subtitle)) l += ` — ${it.subtitle.trim()}`;
      if (!blank(it.value)) l += ` (${it.value.trim()})`;
      if (it.percent !== null && it.percent !== undefined) l += ` ${it.percent}%`;
      if (it.link) l += ` [${it.link.label}](${it.link.url})`;
      if (it.action) l += `\n  - reply: _${it.action.message}_`;
      out.push(l);
    }
  }
  if (card.hasMore) out.push(`_${card.moreLabel}_`);
  if (card.hasCallout) out.push(`> **${card.calloutTitle}:** ${card.calloutText}`);
  if (card.hasNote) out.push(`_${card.note}_`);
  if (buttons.length) out.push(buttons.map((b) => (b.isLink ? `[${b.label}](${b.url})` : `**${b.label}** → reply "${b.message}"`)).join('\n'));
  return out.join('\n');
}

export function toSlackBlocks(card) {
  const { items, stats, buttons } = parts(card);
  const blocks = [{ type: 'header', text: { type: 'plain_text', text: String(card.title).slice(0, 150) } }];
  const ctx = [!blank(card.subtitle) && card.subtitle.trim(), card.hasBadge && `${EMOJI[card.badgeVariant] || ''} ${card.badgeLabel}`].filter(Boolean);
  if (ctx.length) blocks.push({ type: 'context', elements: ctx.map((t) => ({ type: 'mrkdwn', text: t })) });
  if (stats.length) blocks.push({ type: 'section', fields: stats.slice(0, 10).map((s) => ({ type: 'mrkdwn', text: `*${s.label}*\n${s.value}` })) });
  if (card.hasProgress) {
    const n = Math.max(0, Math.min(10, Math.round((card.progressValue || 0) / 10)));
    blocks.push({ type: 'section', text: { type: 'mrkdwn', text: `*Progress:* ${'█'.repeat(n)}${'░'.repeat(10 - n)} ${card.progressValue}%` } });
  }
  if (items.length) {
    blocks.push({ type: 'divider' });
    for (const it of items.slice(0, 20)) {
      const t = `${it.badge ? `${EMOJI[it.badgeVariant] || ''} *${it.badge}*  ` : ''}*${it.title}*\n` +
        (it.before !== null ? `${it.before} → *${it.after}*` : it.subtitle || '') + (!blank(it.value) ? `  _${it.value.trim()}_` : '');
      const sec = { type: 'section', text: { type: 'mrkdwn', text: t.slice(0, 2900) } };
      if (it.action) sec.accessory = { type: 'button', text: { type: 'plain_text', text: it.action.label }, value: String(it.action.message).slice(0, 2000), action_id: 'codey_item_action' };
      else if (it.link) sec.accessory = { type: 'button', text: { type: 'plain_text', text: it.link.label }, url: it.link.url, action_id: 'codey_item_link' };
      blocks.push(sec);
    }
  }
  if (card.hasMore) blocks.push({ type: 'context', elements: [{ type: 'mrkdwn', text: card.moreLabel }] });
  if (card.hasCallout) blocks.push({ type: 'section', text: { type: 'mrkdwn', text: `${EMOJI[card.calloutVariant] || ''} *${card.calloutTitle}*\n${card.calloutText}` } });
  if (card.hasNote) blocks.push({ type: 'context', elements: [{ type: 'mrkdwn', text: card.note }] });
  if (buttons.length) {
    blocks.push({ type: 'actions', elements: buttons.slice(0, 5).map((b, i) => (b.isLink
      ? { type: 'button', text: { type: 'plain_text', text: b.label }, url: b.url, action_id: 'codey_link_' + i }
      : { type: 'button', text: { type: 'plain_text', text: b.label }, value: String(b.message).slice(0, 2000), action_id: 'codey_msg_' + i, ...(b.variant === 'primary' ? { style: 'primary' } : {}) })) });
  }
  return { blocks };
}

export function toAdaptiveCard(card) {
  const { items, stats, buttons } = parts(card);
  const body = [
    { type: 'TextBlock', text: card.title, weight: 'Bolder', size: 'Large', wrap: true },
    ...(!blank(card.subtitle) ? [{ type: 'TextBlock', text: card.subtitle, isSubtle: true, wrap: true, spacing: 'None' }] : []),
    ...(card.hasBadge ? [{ type: 'TextBlock', text: card.badgeLabel, color: { success: 'Good', warning: 'Warning', error: 'Attention' }[card.badgeVariant] || 'Accent', weight: 'Bolder' }] : [])
  ];
  if (stats.length) body.push({ type: 'FactSet', facts: stats.map((s) => ({ title: s.label, value: String(s.value) })) });
  if (card.hasProgress) body.push({ type: 'TextBlock', text: `Progress: ${card.progressValue}%`, weight: 'Bolder' });
  for (const it of items.slice(0, 25)) {
    body.push({ type: 'Container', separator: true, items: [
      { type: 'TextBlock', text: `${it.badge ? `[${it.badge}] ` : ''}${it.title}`, weight: 'Bolder', wrap: true },
      { type: 'TextBlock', text: it.before !== null ? `${it.before} → ${it.after}` : it.subtitle || ' ', isSubtle: true, wrap: true, spacing: 'None' }
    ], ...(it.action ? { selectAction: { type: 'Action.Submit', title: it.action.label, data: { codeyMessage: it.action.message } } } : {}) });
  }
  if (card.hasCallout) body.push({ type: 'TextBlock', text: `${card.calloutTitle}: ${card.calloutText}`, wrap: true, color: card.calloutVariant === 'warning' ? 'Warning' : 'Default' });
  if (card.hasNote) body.push({ type: 'TextBlock', text: card.note, isSubtle: true, wrap: true, size: 'Small' });
  const actions = buttons.map((b) => (b.isLink ? { type: 'Action.OpenUrl', title: b.label, url: b.url }
    : { type: 'Action.Submit', title: b.label, data: { codeyMessage: b.message }, ...(b.variant === 'primary' ? { style: 'positive' } : {}) }));
  return { type: 'AdaptiveCard', $schema: 'http://adaptivecards.io/schemas/adaptive-card.json', version: '1.5', body, actions };
}

export function render(card, format = 'markdown') {
  if (!card || typeof card !== 'object' || !card.title) throw new Error('Pass the "card" object returned by a Codey tool (it needs at least cardType and title).');
  if (format === 'slack') return toSlackBlocks(card);
  if (format === 'adaptive' || format === 'teams') return toAdaptiveCard(card);
  return toMarkdown(card);
}
