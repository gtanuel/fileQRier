# Context

## Glossary

**Sender** — The device/instance displaying QR frames for file transfer. Operates the flow: Landing → Config → Gridbox → Transmission.

**Receiver** — The device/instance scanning QR frames via camera. Operates the flow: Landing → Camera → Receiving → Completion/Error.

**Chunk** — A single QR-encoded unit of the transfer. Two types:
- **HEADER** (0x01) — Metadata frame: type(1B) + filesize(4B) + SHA-256(32B) + filename(variable). Encoded as one QR frame.
- **DATA** (0x02) — Payload frame: type(1B) + fileoffset(4B) + payload(variable). Each encoded as one QR frame.

**Chunk offset** — The byte position within the file where a DATA chunk's payload begins. Used to index the receiver's progress map.

**Progress Map** — A BitTorrent-style visual bar on the Receiver showing which chunks have been received. Rendered on canvas, fits viewport width (no scrolling). Empty chunks take visual priority over filled when multiple chunks map to the same pixel.

**Progress Pointer** — A seekbar-style control on the Sender below the QR display. Shows the current chunk index and allows the user to drag/jump to any chunk. Div-based rendering.

**Gridbox Screen** — A focus/alignment aid displayed on the Sender's screen. The Receiver's camera operator uses it to verify focus and framing before the Sender begins QR transmission. Held indefinitely until the Sender taps to start.

**Relay** — The Receiver, after completing a transfer, can switch to Sender role and re-transmit the received file. Opens Config Screen with default settings (no original metadata passed). The relay loop runs indefinitely until the user presses Back.

**Status Line** — Persistent text line showing current transfer state (e.g., "filename | received / total | percentage"). Used on both Sender and Receiver.

**Buffer** — The in-memory `ArrayBuffer` holding the entire file. Read once at file selection time. Reused for SHA-256 hashing and on-demand slicing during Sender transmission.

## Design Decisions

- **No hard caps** on file size or throughput. User controls everything via Config Screen.
- **QR Version 15** (69×69) is the default. Payload ~887 bytes per DATA chunk with ECC-M.
- **ECC Level M** is the default.
- **Speed 0.5s** per chunk is the default.
- **Config persistence:** Settings (QR Version, ECC, Speed) are saved to localStorage (`qrTransfer_senderConfig`) when user clicks "Begin". Restored when Config Screen opens. No reset button — manual adjustment only.
- **jsQR** is the decoding library (receiver side). Lightweight; assumes stationary device setup.
- **qrcode-generator** (kazuhikoarase) is the encoding library (sender side). Works via script tag, `stringToBytes` override for raw 0x00-0xFF bytes, manual canvas rendering via `isDark()`/`getModuleCount()`.
- **In-memory only** — no IndexedDB, no File System Access API. File written only via browser download dialog.
- **One file read** — the file is read once into a buffer at selection time. The same buffer is used for SHA-256 hashing and chunk slicing.
- **No pre-chunking** — chunks are sliced from the buffer on-demand during transmission.
- **Per-chunk integrity** via QR ECC. **File integrity** via SHA-256 checked at 100% completion.
- **Missed chunks** treated as gaps. Sender's Progress Pointer allows jumping to approximate gap location.
- **Missing HEADER recovery** — sender restarts from Config Screen.
- **Camera denial** — persistent error message shown; user reloads page.
- **No transient toasts** — progress in Status Line, errors shown persistently with Back button.
- **Architecture** — decoupled: core classes emit events/callbacks; a UIManager handles all DOM.
- **Progress Map** — single canvas, no scrolling, pixel-priority rendering (empty over filled).
- **Progress Pointer** — div-based seekbar.
