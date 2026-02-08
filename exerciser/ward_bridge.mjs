// ward_bridge.mjs — Reusable bridge between ward WASM and a DOM implementation
// Parses the ward binary diff protocol and dispatches to a DOM adapter.
// Also handles WASM loading, timer bridging, and exit signaling.

import { readFile } from 'node:fs/promises';

// Parse a little-endian i32 from a Uint8Array at offset
function readI32(buf, off) {
  return buf[off] | (buf[off+1] << 8) | (buf[off+2] << 16) | (buf[off+3] << 24);
}

/**
 * Load a ward WASM module and connect it to a DOM adapter.
 *
 * @param {string|URL} wasmPath — path to the .wasm file
 * @param {object} adapter — DOM operations the bridge dispatches to:
 *   adapter.createElement(nodeId, parentId, tag)
 *   adapter.setText(nodeId, text)
 *   adapter.setAttr(nodeId, name, value)
 *   adapter.removeChildren(nodeId)
 *   adapter.onExit() — called when WASM calls ward_exit
 * @returns {{ instance, exports }} — the WASM instance and its exports
 */
export async function loadWard(wasmPath, adapter) {
  const wasmBuf = await readFile(wasmPath);
  let instance = null;

  function wardDomFlush(bufPtr, len) {
    const mem = new Uint8Array(instance.exports.memory.buffer);
    const buf = mem.slice(bufPtr, bufPtr + len);

    const op = buf[0];
    const nodeId = readI32(buf, 1);

    switch (op) {
      case 4: { // CREATE_ELEMENT
        const parentId = readI32(buf, 5);
        const tagLen = buf[9];
        const tag = new TextDecoder().decode(buf.slice(10, 10 + tagLen));
        adapter.createElement(nodeId, parentId, tag);
        break;
      }
      case 1: { // SET_TEXT
        const textLen = buf[5] | (buf[6] << 8);
        const text = new TextDecoder().decode(buf.slice(7, 7 + textLen));
        adapter.setText(nodeId, text);
        break;
      }
      case 2: { // SET_ATTR
        const nameLen = buf[5];
        const name = new TextDecoder().decode(buf.slice(6, 6 + nameLen));
        const valOff = 6 + nameLen;
        const valLen = buf[valOff] | (buf[valOff+1] << 8);
        const value = new TextDecoder().decode(buf.slice(valOff + 2, valOff + 2 + valLen));
        adapter.setAttr(nodeId, name, value);
        break;
      }
      case 3: { // REMOVE_CHILDREN
        adapter.removeChildren(nodeId);
        break;
      }
      default:
        throw new Error(`Unknown ward DOM op: ${op}`);
    }
  }

  function wardSetTimer(delayMs, resolverPtr) {
    setTimeout(() => {
      instance.exports.ward_timer_fire(resolverPtr);
    }, delayMs);
  }

  function wardExit() {
    adapter.onExit();
  }

  const imports = {
    env: {
      ward_dom_flush: wardDomFlush,
      ward_set_timer: wardSetTimer,
      ward_exit: wardExit,
    },
  };

  const result = await WebAssembly.instantiate(wasmBuf, imports);
  instance = result.instance;

  return { instance, exports: instance.exports };
}
