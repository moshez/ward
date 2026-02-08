# WASM-to-JS Bridge Primitives

## DOM (reads only)

| Import | Signature | Test approach |
|--------|-----------|---------------|
| `js_measure_node` | `(node_id) → bool` ; writes 6×f64 to out buffer | jsdom |
| `js_query_selector` | `(selector_ptr, selector_len) → node_id` | jsdom |

## Events

| Import | Signature | Test approach |
|--------|-----------|---------------|
| `js_add_event_listener` | `(node_id, type_ptr, type_len, listener_id)` ; calls back `on_event(listener_id, payload_ptr, payload_len)` | jsdom + dispatchEvent |
| `js_remove_event_listener` | `(listener_id)` | jsdom |
| `js_prevent_default` | `(event_handle)` — must be called synchronously within event callback | jsdom |

## Network

| Import | Signature | Test approach |
|--------|-----------|---------------|
| `js_fetch` | `(url_ptr, url_len, opts_ptr, opts_len, request_id)` ; calls back `on_fetch_complete(request_id, status, body_ptr, body_len)` | jsdom (node 18+ globals) |
| `js_fetch_abort` | `(request_id)` | jsdom |

## Clipboard

| Import | Signature | Test approach |
|--------|-----------|---------------|
| `js_clipboard_write_text` | `(text_ptr, text_len, request_id)` → `on_clipboard_complete(request_id, success)` | jsdom + mock navigator.clipboard |

## Navigation

| Import | Signature | Test approach |
|--------|-----------|---------------|
| `js_get_url` | `(out_ptr, max_len) → len` | jsdom |
| `js_get_url_hash` | `(out_ptr, max_len) → len` | jsdom |
| `js_set_url_hash` | `(hash_ptr, hash_len)` | jsdom |
| `js_replace_state` | `(url_ptr, url_len)` | jsdom |
| `js_push_state` | `(url_ptr, url_len)` | jsdom |

## File I/O (user-selected files)

| Import | Signature | Test approach |
|--------|-----------|---------------|
| `js_file_open` | `(input_node_id, request_id)` → `on_file_open(request_id, handle, size)` | jsdom + mock File |
| `js_file_read` | `(handle, offset, len, out_ptr) → bytes_read` — synchronous from cached ArrayBuffer | jsdom |
| `js_file_close` | `(handle)` | jsdom |

## Decompression

| Import | Signature | Test approach |
|--------|-----------|---------------|
| `js_decompress` | `(data_ptr, data_len, method, request_id)` → `on_decompress_complete(request_id, handle, decompressed_len)` | jsdom (node 18+ DecompressionStream) |
| `js_blob_read` | `(handle, offset, len, out_ptr) → bytes_read` | jsdom |
| `js_blob_free` | `(handle)` | jsdom |

## Push / Notifications

| Import | Signature | Test approach |
|--------|-----------|---------------|
| `js_notification_request_permission` | `(request_id)` → `on_permission_result(request_id, granted)` | jsdom + mock Notification |
| `js_notification_show` | `(title_ptr, title_len, opts_ptr, opts_len)` | jsdom + mock Notification |
| `js_push_subscribe` | `(vapid_ptr, vapid_len, request_id)` → `on_push_subscribe(request_id, json_ptr, len)` | jsdom + mock PushManager |
| `js_push_get_subscription` | `(request_id)` → same callback shape | jsdom + mock PushManager |

## Window / Document

| Import | Signature | Test approach |
|--------|-----------|---------------|
| `js_focus_window` | `()` | jsdom |
| `js_get_visibility_state` | `() → u8` (0=visible, 1=hidden) | jsdom |
| `js_log` | `(level, msg_ptr, msg_len)` | jsdom |