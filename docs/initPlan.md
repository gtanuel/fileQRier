# ROLE & OBJECTIVE
You are an expert frontend engineer. Generate a single, self-contained HTML file (inline CSS/JS) that implements an air-gapped file transfer system using animated QR codes. The app must support two roles: Sender and Receiver. External JS libraries are allowed ONLY for QR encoding/decoding, and both MUST support byte-mode (Uint8Array) input/output.

# 📦 DATA PROTOCOL & CHUNKING
- **Chunk Types**: 
  - `HEADER`: type=0x01 (1B) | filesize=uint32 BE (4B) | checksum=SHA-256 (32B) | filename=UTF-8 (variable)
  - `DATA`: type=0x02 (1B) | fileoffset=uint32 BE (4B) | payload=raw bytes (variable)
- **Chunk Size Calculation**: Dynamically compute max payload per chunk based on selected QR Version (1-40) and Error Correction Level (L/M/Q/H). Use the QR byte capacity table minus header overhead. Split file sequentially into DATA chunks.
- **Loop Behavior**: 
  1. Show HEADER once for `max(1000, 2 * speed)` ms.
  2. Show each DATA chunk for `speed` ms.
  3. After the last DATA chunk, loop back to the first DATA chunk indefinitely.
- **Error Recovery**: Sender UI includes a seekbar-like "Progress Pointer" mapping to DATA chunk indices. Dragging/clicking jumps the loop to that chunk immediately.

# 🖥️ UI/UX FLOW
## Landing Page
- Full-screen drag-and-drop zone (accepts single file).
- Two prominent buttons: `Sender` and `Receiver`.
- Clicking `Sender` opens native file picker. Drag-drop or picker both trigger the same flow.

## Sender Flow
1. **Config Screen**: 
   - QR Version: slider 1-40
   - ECC Level: toggle buttons [L, M, Q, H]
   - Speed: slider 0.1s - 5.0s
   - Buttons: `Back` (returns to landing), `Begin`
2. **Gridbox Screen**: Shows a camera alignment grid. Tap/press anywhere to start transmission.
3. **Transmission Screen**: 
   - Large QR canvas centered.
   - Progress Pointer below QR (seekbar style).
   - Loop runs per protocol above.
   - Pointer updates in real-time; manual drag overrides loop position.

## Receiver Flow
1. **Camera Screen**: Enable `getUserMedia`, show live preview.
2. **Scanning**: Continuously decode frames. On valid `HEADER` detection:
   - Parse metadata, initialize progress map, pause scanning until ready.
   - Begin accepting `DATA` chunks.
3. **Receiving UI**:
   - Camera preview at top.
   - **Progress Map**: BitTorrent-style bar. Render missing/corrupted/partial chunks as EMPTY. Render fully received & verified chunks as FILLED.
   - **Triangle Indicator**: Above progress map, points to byte offset of last accepted DATA chunk.
   - **Status Line**: `filename | received_bytes / total_bytes | percentage%`
4. **Completion Screen** (100% received):
   - `Back`: Returns to landing.
   - `Download`: Triggers browser save dialog with correct filename.
   - `Relay`: Switches to Sender role, loads received file into Config Screen.

# ⚙️ TECHNICAL CONSTRAINTS & LIBRARIES
- **Single File**: All HTML, CSS, JS inline. No build step.
- **QR Libraries** (CDN only):
  - Encoding: `qrcode-generator` (supports byte mode)
  - Decoding: `jsQR` or `@zxing/library` (must return raw bytes)
- **Performance**: 
  - Use `requestAnimationFrame` for QR loop timing.
  - Debounce camera scanning (max 15 FPS decode attempts).
  - Reuse canvas contexts to avoid GC pressure.
- **State Management**: Use a clean, modular class/namespace structure. Avoid global scope pollution.
- **Error Handling**: 
  - Graceful fallbacks for camera denial, unsupported QR versions, checksum mismatches, or interrupted streams.
  - Clear console warnings + UI toast/status messages for user feedback.
- **Responsive**: Mobile-first layout. Touch-friendly controls.

# 🛠️ IMPLEMENTATION GUIDELINES
1. Calculate QR byte capacity dynamically based on version/ECC. Reference standard QR capacity tables or compute via library metadata.
2. Implement a `ChunkManager` class to handle file slicing, byte packing, and offset tracking.
3. Implement a `QRLoop` class for timing, rendering, and progress pointer sync.
4. Implement a `ReceiverEngine` class for camera pipeline, frame decoding, checksum verification, and progress map updates.
5. Use `Blob` + `URL.createObjectURL` for the download flow.
6. Ensure the relay flow properly resets state and reinitializes the Sender config with the received file.

# ✅ OUTPUT EXPECTATIONS
- Return ONLY the complete, runnable HTML file.
- Include concise comments explaining chunk calculation, QR library integration, and state transitions.
- Ensure zero external dependencies besides the specified QR CDN scripts.
- Code must be production-ready, well-structured, and handle edge cases (large files, slow speeds, camera errors, relay switching).
