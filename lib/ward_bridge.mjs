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

  function readBytes(ptr, len) {
    return new Uint8Array(instance.exports.memory.buffer, ptr, len).slice();
  }

  function readString(ptr, len) {
    return new TextDecoder().decode(readBytes(ptr, len));
  }

  // --- DOM flush ---

  function wardDomFlush(bufPtr, len) {
    const mem = new Uint8Array(instance.exports.memory.buffer);
    let pos = 0;

    while (pos < len) {
      const op = mem[bufPtr + pos];
      const nodeId = readI32(mem, bufPtr + pos + 1);

      switch (op) {
        case 4: { // CREATE_ELEMENT
          const parentId = readI32(mem, bufPtr + pos + 5);
          const tagLen = mem[bufPtr + pos + 9];
          const tag = new TextDecoder().decode(mem.slice(bufPtr + pos + 10, bufPtr + pos + 10 + tagLen));
          const el = document.createElement(tag);
          nodes.set(nodeId, el);
          const parent = nodes.get(parentId);
          if (parent) parent.appendChild(el);
          pos += 10 + tagLen;
          break;
        }
        case 1: { // SET_TEXT
          const textLen = mem[bufPtr + pos + 5] | (mem[bufPtr + pos + 6] << 8);
          const text = new TextDecoder().decode(mem.slice(bufPtr + pos + 7, bufPtr + pos + 7 + textLen));
          const el = nodes.get(nodeId);
          if (el) el.textContent = text;
          pos += 7 + textLen;
          break;
        }
        case 2: { // SET_ATTR
          const nameLen = mem[bufPtr + pos + 5];
          const name = new TextDecoder().decode(mem.slice(bufPtr + pos + 6, bufPtr + pos + 6 + nameLen));
          const valOff = pos + 6 + nameLen;
          const valLen = mem[bufPtr + valOff] | (mem[bufPtr + valOff + 1] << 8);
          const value = new TextDecoder().decode(mem.slice(bufPtr + valOff + 2, bufPtr + valOff + 2 + valLen));
          const el = nodes.get(nodeId);
          if (el) el.setAttribute(name, value);
          pos += 6 + nameLen + 2 + valLen;
          break;
        }
        case 3: { // REMOVE_CHILDREN
          const el = nodes.get(nodeId);
          if (el) el.innerHTML = '';
          pos += 5;
          break;
        }
        default:
          throw new Error(`Unknown ward DOM op: ${op} at offset ${pos}`);
      }
    }
  }

  // --- Timer ---

  function wardSetTimer(delayMs, resolverPtr) {
    setTimeout(() => {
      instance.exports.ward_timer_fire(resolverPtr);
    }, delayMs);
  }

  // --- IndexedDB ---

  let dbPromise = null;
  function openDB() {
    if (!dbPromise) {
      dbPromise = new Promise((resolve, reject) => {
        const req = indexedDB.open('ward', 1);
        req.onupgradeneeded = () => {
          req.result.createObjectStore('kv');
        };
        req.onsuccess = () => resolve(req.result);
        req.onerror = () => reject(req.error);
      });
    }
    return dbPromise;
  }

  function wardIdbPut(keyPtr, keyLen, valPtr, valLen, resolverPtr) {
    const key = readString(keyPtr, keyLen);
    const val = readBytes(valPtr, valLen);
    openDB().then(db => {
      const tx = db.transaction('kv', 'readwrite');
      tx.objectStore('kv').put(val, key);
      tx.oncomplete = () => {
        instance.exports.ward_idb_fire(resolverPtr, 0);
      };
      tx.onerror = () => {
        instance.exports.ward_idb_fire(resolverPtr, -1);
      };
    });
  }

  function wardIdbGet(keyPtr, keyLen, resolverPtr) {
    const key = readString(keyPtr, keyLen);
    openDB().then(db => {
      const tx = db.transaction('kv', 'readonly');
      const req = tx.objectStore('kv').get(key);
      req.onsuccess = () => {
        const result = req.result;
        if (result === undefined) {
          instance.exports.ward_idb_fire_get(resolverPtr, 0, 0);
        } else {
          const data = new Uint8Array(result);
          const len = data.length;
          const ptr = instance.exports.malloc(len);
          new Uint8Array(instance.exports.memory.buffer).set(data, ptr);
          instance.exports.ward_idb_fire_get(resolverPtr, ptr, len);
        }
      };
      req.onerror = () => {
        instance.exports.ward_idb_fire_get(resolverPtr, 0, 0);
      };
    });
  }

  function wardIdbDelete(keyPtr, keyLen, resolverPtr) {
    const key = readString(keyPtr, keyLen);
    openDB().then(db => {
      const tx = db.transaction('kv', 'readwrite');
      tx.objectStore('kv').delete(key);
      tx.oncomplete = () => {
        instance.exports.ward_idb_fire(resolverPtr, 0);
      };
      tx.onerror = () => {
        instance.exports.ward_idb_fire(resolverPtr, -1);
      };
    });
  }

  // --- Window ---

  function wardJsFocusWindow() {
    // stub — no-op in exerciser
  }

  function wardJsGetVisibilityState() {
    return 1; // 1 = visible
  }

  function wardJsLog(level, msgPtr, msgLen) {
    const msg = readString(msgPtr, msgLen);
    const labels = ['debug', 'info', 'warn', 'error'];
    const label = labels[level] || 'log';
    console.log(`[ward:${label}] ${msg}`);
  }

  // --- Navigation ---

  function wardJsGetUrl(outPtr, maxLen) {
    // stub — return 0 bytes written
    return 0;
  }

  function wardJsGetUrlHash(outPtr, maxLen) {
    return 0;
  }

  function wardJsSetUrlHash(hashPtr, hashLen) {
    // stub
  }

  function wardJsReplaceState(urlPtr, urlLen) {
    // stub
  }

  function wardJsPushState(urlPtr, urlLen) {
    // stub
  }

  // --- DOM read ---

  function wardJsMeasureNode(nodeId) {
    // stub — fill measure stash with zeros via ward_measure_set export
    for (let i = 0; i < 6; i++) {
      instance.exports.ward_measure_set(i, 0);
    }
    return 0;
  }

  function wardJsQuerySelector(selectorPtr, selectorLen) {
    const selector = readString(selectorPtr, selectorLen);
    // stub — return -1 (not found)
    return -1;
  }

  // --- Event listener ---

  function wardJsAddEventListener(nodeId, eventTypePtr, typeLen, listenerId) {
    // stub
  }

  function wardJsRemoveEventListener(listenerId) {
    // stub
  }

  function wardJsPreventDefault() {
    // stub
  }

  // --- Fetch ---

  function wardJsFetch(urlPtr, urlLen, resolverPtr) {
    // stub — immediately resolve with status 0
    instance.exports.ward_on_fetch_complete(resolverPtr, 0, 0, 0);
  }

  // --- Clipboard ---

  function wardJsClipboardWriteText(textPtr, textLen, resolverPtr) {
    // stub — immediately resolve with success=1
    instance.exports.ward_on_clipboard_complete(resolverPtr, 1);
  }

  // --- File ---

  function wardJsFileOpen(inputNodeId, resolverPtr) {
    // stub — immediately resolve with handle=0, size=0
    instance.exports.ward_on_file_open(resolverPtr, 0, 0);
  }

  function wardJsFileRead(handle, fileOffset, len, outPtr) {
    return 0;
  }

  function wardJsFileClose(handle) {
    // stub
  }

  // --- Decompress ---

  function wardJsDecompress(dataPtr, dataLen, method, resolverPtr) {
    // stub — immediately resolve with handle=0, len=0
    instance.exports.ward_on_decompress_complete(resolverPtr, 0, 0);
  }

  function wardJsBlobRead(handle, blobOffset, len, outPtr) {
    return 0;
  }

  function wardJsBlobFree(handle) {
    // stub
  }

  // --- Notification/Push ---

  function wardJsNotificationRequestPermission(resolverPtr) {
    // stub — immediately resolve with granted=1
    instance.exports.ward_on_permission_result(resolverPtr, 1);
  }

  function wardJsNotificationShow(titlePtr, titleLen) {
    // stub
  }

  function wardJsPushSubscribe(vapidPtr, vapidLen, resolverPtr) {
    // stub — immediately resolve
    instance.exports.ward_on_push_subscribe(resolverPtr, 0, 0);
  }

  function wardJsPushGetSubscription(resolverPtr) {
    // stub — immediately resolve
    instance.exports.ward_on_push_subscribe(resolverPtr, 0, 0);
  }

  const imports = {
    env: {
      ward_dom_flush: wardDomFlush,
      ward_set_timer: wardSetTimer,
      ward_exit: () => { resolveDone(); },
      // IDB
      ward_idb_js_put: wardIdbPut,
      ward_idb_js_get: wardIdbGet,
      ward_idb_js_delete: wardIdbDelete,
      // Window
      ward_js_focus_window: wardJsFocusWindow,
      ward_js_get_visibility_state: wardJsGetVisibilityState,
      ward_js_log: wardJsLog,
      // Navigation
      ward_js_get_url: wardJsGetUrl,
      ward_js_get_url_hash: wardJsGetUrlHash,
      ward_js_set_url_hash: wardJsSetUrlHash,
      ward_js_replace_state: wardJsReplaceState,
      ward_js_push_state: wardJsPushState,
      // DOM read
      ward_js_measure_node: wardJsMeasureNode,
      ward_js_query_selector: wardJsQuerySelector,
      // Event listener
      ward_js_add_event_listener: wardJsAddEventListener,
      ward_js_remove_event_listener: wardJsRemoveEventListener,
      ward_js_prevent_default: wardJsPreventDefault,
      // Fetch
      ward_js_fetch: wardJsFetch,
      // Clipboard
      ward_js_clipboard_write_text: wardJsClipboardWriteText,
      // File
      ward_js_file_open: wardJsFileOpen,
      ward_js_file_read: wardJsFileRead,
      ward_js_file_close: wardJsFileClose,
      // Decompress
      ward_js_decompress: wardJsDecompress,
      ward_js_blob_read: wardJsBlobRead,
      ward_js_blob_free: wardJsBlobFree,
      // Notification/Push
      ward_js_notification_request_permission: wardJsNotificationRequestPermission,
      ward_js_notification_show: wardJsNotificationShow,
      ward_js_push_subscribe: wardJsPushSubscribe,
      ward_js_push_get_subscription: wardJsPushGetSubscription,
    },
  };

  const result = await WebAssembly.instantiate(wasmBytes, imports);
  instance = result.instance;
  instance.exports.ward_node_init(0);

  return { exports: instance.exports, nodes, done };
}
