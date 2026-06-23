# Plan: fileQRier — Air-Gapped QR File Transfer

Single HTML file. Inline CSS/JS. Two CDN libraries: `qrcode` (encode), `jsQR` (decode).

## Tracer Bullets

### Slice 1 — Skeleton + Landing Page + File Selection [AFK]
**Goal:** App opens, user drags/drops or picks a file, file is read into an `ArrayBuffer`.

- HTML shell with inline CSS (mobile-first, full-screen layout, screen show/hide utility)
- Landing page: full-screen drag-and-drop zone + Sender/Receiver buttons
- Drag-drop and file picker both trigger `File` → `ArrayBuffer` read via `FileReader`
- File buffer stored in app state; filename + filesize displayed
- **Demo:** Open HTML file → drag a file → see filename and filesize shown

### Slice 2 — Config Screen + LocalStorage Persistence [AFK]
**Goal:** Config UI renders, user adjusts settings, settings persist across page reloads.

- Config Screen UI: QR Version slider (1–40), ECC toggle buttons (L/M/Q/H), Speed slider (0.1s–5.0s)
- "Back" button returns to Landing; "Begin" button advances to Gridbox
- On "Begin": save `{version, ecc, speed}` to `localStorage` key `qrTransfer_senderConfig`
- On Config Screen open: restore from localStorage if present; otherwise use defaults (V15, M, 0.5s)
- No reset button — manual adjustment only
- **Demo:** Adjust sliders → click Begin → reload page → Config shows saved values

### Slice 3 — Sender QR Encoding Pipeline [AFK]
**Goal:** Given a file buffer, produce QR code canvases for HEADER and DATA chunks.

- `ChunkManager` class:
  - `createHeaderChunk(buffer)`: packs `type(1B) | filesize(4B) | sha256(32B) | filename(variable)` into `Uint8Array`
  - `createDataChunks(buffer)`: slices buffer into DATA chunks: `type(1B) | fileoffset(4B) | payload(variable)`
  - Payload size = QR byte capacity for selected version/ECC − 5 (header overhead)
- SHA-256 via Web Crypto API `subtle.digest('SHA-256', buffer)`
- QR encoding via `qrcode` library: `QRCode.toCanvas(canvas, chunkBytes, { version, errorCorrectionLevel })`
- `qrcode` byte mode maps 0x00–0xFF 1:1 via ISO/IEC 8859-1
- **Demo:** Select a file → render QR code canvas for the HEADER chunk → verify it's scannable

### Slice 4 — Sender Transmission Loop [HITL]
**Goal:** Full sender flow — Gridbox → QR loop with HEADER once + DATA loop → seekable progress pointer.

- Gridbox Screen: full-screen grid pattern, tap/press to start transmission
- Transmission Screen: large centered QR canvas, div-based progress pointer (seekbar) below
- Loop timing via `requestAnimationFrame` + `speed` interval:
  - HEADER shown for `max(1000, 2 * speed)` ms once
  - DATA chunks shown for `speed` ms each
  - After last DATA chunk, loop back to first DATA chunk indefinitely
- Progress pointer: `<div>` bar + `<div>` pointer, `min=0`, `max=N-1` (DATA chunk count)
- Dragging/clicking progress pointer jumps loop to that chunk index immediately
- "Back" button returns to Config Screen (restart required if receiver missed HEADER)
- **Demo:** Tap Gridbox → see QR codes cycle → drag progress pointer to chunk 50 → loop jumps to chunk 50

### Slice 5 — Receiver Camera + Decoding Pipeline [AFK]
**Goal:** Receiver shows camera feed, decodes QR codes from frames at max 15 FPS, outputs raw bytes.

- Camera Screen: `getUserMedia` → `<video>` preview, canvas for frame extraction
- Frame extraction: `canvas.getContext('2d').getImageData()` from video frame
- Decoding: `jsQR(imageData.data, width, height)` → returns `binaryData` (`Uint8ClampedArray`)
- Convert to `Uint8Array`: `new Uint8Array(code.binaryData)`
- Debounce decode attempts to max 15 FPS via `setTimeout`/`requestAnimationFrame`
- Camera denial: persistent error message with instructions to reload page
- **Demo:** Open receiver → grant camera → point at a QR code on another screen → see decoded bytes logged

### Slice 6 — Receiver State Machine + HEADER Parsing [HITL]
**Goal:** Receiver detects HEADER, parses metadata, initializes progress map, transitions to collecting state.

- State machine: `IDLE` → `HEADER_DETECTED` → `COLLECTING` → `COMPLETE` / `ERROR`
- On HEADER decode: parse `type(1B) | filesize(4B) | sha256(32B) | filename(variable)` from QR frame bytes
- Filename = bytes from index 37 to end of frame (QR frame boundary = delimiter)
- Initialize byte buffer (`new ArrayBuffer(filesize)`), progress map (all-empty), chunk count = `ceil(filesize / payloadSize)`
- Camera continues scanning — no pause, no user gating
- Status Line: `filename | 0 / total | 0%`
- **Demo:** Point receiver at HEADER QR → see filename and filesize appear in Status Line → progress map initialized

### Slice 7 — Receiver DATA Reception + Progress Map + Completion [HITL]
**Goal:** Receiver accepts DATA chunks, writes to buffer, updates progress map, verifies SHA-256, shows Completion/Error screen.

- On DATA decode: parse `type(1B) | fileoffset(4B) | payload(variable)`
- Write payload to `buffer.slice(fileoffset, fileoffset + payload.length)` via `new Uint8Array(buffer).set(payload, fileoffset)`
- Progress Map: single `<canvas>`, fits viewport width (no scrolling)
  - Each chunk maps to 1+ pixels; if multiple chunks map to same pixel, empty takes priority
  - Filled chunks = black, empty = white/transparent
- Triangle indicator above progress map: points to byte offset of last accepted contiguous chunk
- On 100% received: compute SHA-256 of assembled buffer, compare with HEADER checksum
  - Match → `COMPLETE` state
  - Mismatch → `ERROR` state
- **Demo:** Point receiver at DATA QR stream → see progress map fill → on completion, SHA-256 verified

### Slice 8 — Completion/Error Screens + Download + Relay [HITL]
**Goal:** User sees result of transfer, can download, go back, or relay.

- Completion Screen: camera preview (top), progress map (filled), Status Line, buttons: Back / Download / Relay
- Download: `new Blob([buffer])` → `URL.createObjectURL(blob)` → `<a download="filename">` → triggers browser save dialog
- Error Screen: persistent error message + "Back" button (returns to Landing)
- Relay: switch to Sender role, load received file buffer into Config Screen (default settings), user can adjust and transmit
- Relay DATA loop runs indefinitely until user presses Back → returns to Completion Screen
- **Demo:** Complete transfer → tap Download → file saves → tap Relay → Config opens with received file → transmit

### Slice 9 — End-to-End Integration + Responsive Polish [HITL]
**Goal:** Full sender→receiver transfer between two devices, responsive layout, all error paths handled.

- Responsive CSS: mobile-first, touch-friendly controls, QR canvas scales to viewport
- Error handling: camera denial, QR decode failures (treated as missed chunks), checksum failure
- Status Line: persistent progress display on both Sender and Receiver
- No transient toasts — only persistent Status Line and persistent Error screens
- State cleanup on Back/Relay/Download
- **Demo:** Transfer a real file (photo, PDF, etc.) from Sender device to Receiver device → download verified file
