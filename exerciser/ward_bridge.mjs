// ward_bridge.mjs — Bridge between ward WASM and a DOM document
// Parses the ward binary diff protocol and applies it to a standard DOM.
// Works in any ES module environment (browser or Node.js).

// Parse a little-endian i32 from a Uint8Array at offset
function readI32(buf, off) {
  return buf[off] | (buf[off+1] << 8) | (buf[off+2] << 16) | (buf[off+3] << 24);
}

/**
 * Load a ward WASM module and connect it to a DOM document.
 *
 * @param {BufferSource} wasmBytes — compiled WASM bytes
 * @param {Element} root — root element for ward to render into (node_id 0)
 * @returns {{ exports, nodes, done }} — WASM exports, node registry,
 *   and a promise that resolves when WASM calls ward_exit
 */
export async function loadWard(wasmBytes, root) {
  const document = root.ownerDocument;
  let instance = null;
  let resolveDone;
  const done = new Promise(r => { resolveDone = r; });

  // Node registry: node_id -> DOM element
  const nodes = new Map();
  nodes.set(0, root);

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
        const el = document.createElement(tag);
        nodes.set(nodeId, el);
        const parent = nodes.get(parentId);
        if (parent) parent.appendChild(el);
        break;
      }
      case 1: { // SET_TEXT
        const textLen = buf[5] | (buf[6] << 8);
        const text = new TextDecoder().decode(buf.slice(7, 7 + textLen));
        const el = nodes.get(nodeId);
        if (el) el.textContent = text;
        break;
      }
      case 2: { // SET_ATTR
        const nameLen = buf[5];
        const name = new TextDecoder().decode(buf.slice(6, 6 + nameLen));
        const valOff = 6 + nameLen;
        const valLen = buf[valOff] | (buf[valOff+1] << 8);
        const value = new TextDecoder().decode(buf.slice(valOff + 2, valOff + 2 + valLen));
        const el = nodes.get(nodeId);
        if (el) el.setAttribute(name, value);
        break;
      }
      case 3: { // REMOVE_CHILDREN
        const el = nodes.get(nodeId);
        if (el) el.innerHTML = '';
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

  const imports = {
    env: {
      ward_dom_flush: wardDomFlush,
      ward_set_timer: wardSetTimer,
      ward_exit: () => { resolveDone(); },
    },
  };

  const result = await WebAssembly.instantiate(wasmBytes, imports);
  instance = result.instance;
  instance.exports.ward_node_init(0);

  return { exports: instance.exports, nodes, done };
}
