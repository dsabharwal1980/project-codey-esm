#!/usr/bin/env node
// Renders a Codey card read from stdin. Usage: node mcp-server/src/render-cli.js [markdown|slack|adaptive] < card.json
import { render } from './cards.js';

const format = process.argv[2] || 'markdown';
let input = '';
process.stdin.setEncoding('utf8');
process.stdin.on('data', (c) => { input += c; });
process.stdin.on('end', () => {
  try {
    const out = render(JSON.parse(input), format);
    process.stdout.write(typeof out === 'string' ? out + '\n' : JSON.stringify(out, null, 2) + '\n');
  } catch (e) {
    process.stderr.write('Could not render card: ' + e.message + '\n');
    process.exit(1);
  }
});
