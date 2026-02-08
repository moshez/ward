// node_exerciser.mjs — Node.js exerciser: jsdom adapter for ward_bridge
// Verifies ward DOM output end-to-end via the promise-based timer flow.

import { JSDOM } from 'jsdom';
import { loadWard } from './ward_bridge.mjs';

const dom = new JSDOM('<!DOCTYPE html><div id="ward-root"></div>');
const document = dom.window.document;
const root = document.getElementById('ward-root');

// Node registry: node_id -> DOM element
const nodes = new Map();
nodes.set(0, root);

// jsdom adapter — implements the interface expected by ward_bridge
const adapter = {
  createElement(nodeId, parentId, tag) {
    const el = document.createElement(tag);
    nodes.set(nodeId, el);
    const parent = nodes.get(parentId);
    if (parent) parent.appendChild(el);
  },
  setText(nodeId, text) {
    const el = nodes.get(nodeId);
    if (el) el.textContent = text;
  },
  setAttr(nodeId, name, value) {
    const el = nodes.get(nodeId);
    if (el) el.setAttribute(name, value);
  },
  removeChildren(nodeId) {
    const el = nodes.get(nodeId);
    if (el) el.innerHTML = '';
  },
  onExit() {
    console.log('\n==> Final DOM state:');
    console.log(root.innerHTML);
    console.log('\n==> Node DOM exerciser completed');
    process.exit(0);
  },
};

async function main() {
  const wasmPath = new URL('../build/node_ward.wasm', import.meta.url);
  const { exports } = await loadWard(wasmPath, adapter);

  console.log('==> Node DOM exerciser started');
  console.log('==> Calling ward_node_init(0)...');
  exports.ward_node_init(0);

  // Print DOM at 2 seconds to verify elements were created
  setTimeout(() => {
    console.log('\n==> DOM at 2s:');
    console.log(root.innerHTML);
  }, 2000);
}

main().catch(err => {
  console.error('Fatal:', err);
  process.exit(1);
});
