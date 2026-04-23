# Swift Migration Plan — Audio Password Agent

## Overview

This document describes a phased strategy for migrating the Python-based
`audio-password-agent` to Swift. The codebase is ~250 lines across three
core modules (crypto, audio steganography, agent orchestrator). The
migration targets a **native macOS app** built with SwiftUI, with the core
logic packaged as a Swift Package so it can also be consumed from a CLI or
iOS target. Full backward-compatibility with existing WAV files produced by
the Python version is preserved.

---

## Current Stack (Python)

| Module | File | Key dependency |
|---|---|---|
| Crypto | `src/core/crypto.py` | `cryptography` (Fernet) |
| Steganography | `src/core/audio.py` | stdlib `wave` |
| Agent | `src/core/agent.py` | above two |
| API | `src/api/__init__.py` | FastAPI (placeholder only) |

---

## Target Stack (Swift)

| Concern | Swift approach |
|---|---|
| Package manager | Swift Package Manager (SPM) |
| Crypto primitives | CryptoKit + CommonCrypto (AES-CBC) |
| WAV I/O | Foundation `Data` + manual RIFF parser |
| UI framework | SwiftUI (DAW-style interface, dark + light themes) |
| State management | `@Observable` / `ObservableObject` view models |
| Tests | XCTest |
| Platform | macOS 13+ (primary), iOS 16+ (future) |

---

## Critical Technical Constraints

### 1. Fernet Encryption Compatibility

The Python code uses `cryptography.fernet.Fernet` (AES-128-CBC +
HMAC-SHA256). This is a **wire format** — existing WAV files contain
Fernet tokens that the Swift version must be able to decrypt.

**Problem:** CryptoKit does **not** expose AES-CBC. It only provides
AES-GCM and AES-KeyWrap.

**Solution:** Implement the Fernet spec manually using:
- `CommonCrypto.CCCrypt` for AES-128-CBC encrypt/decrypt
- `CryptoKit.HMAC<SHA256>` for signing/verification
- Fernet token layout: `0x80 | timestamp(8B) | IV(16B) | ciphertext | HMAC(32B)`

```swift
// Key split: first 16 bytes = HMAC signing key, last 16 bytes = AES key
let signingKey  = fernetKey.prefix(16)
let encryptionKey = fernetKey.suffix(16)
```

### 2. Key Derivation Compatibility

The Python key derivation is a **non-standard SHA256 chain** (not PBKDF2):

```python
key_material = password.encode() + b"audio_pwd_manager_salt_v1"
for _ in range(100_000):
    key_material = hashlib.sha256(key_material).digest()
return base64url_encode(key_material[:32])
```

This must be replicated exactly in Swift using `CryptoKit.SHA256`:

```swift
var keyMaterial = Data(password.utf8) + Data("audio_pwd_manager_salt_v1".utf8)
for _ in 0..<100_000 {
    keyMaterial = Data(SHA256.hash(data: keyMaterial))
}
let fernetKey = Data(keyMaterial.prefix(32))
```

### 3. WAV Byte-Level Access

Python's `wave` module exposes raw PCM bytes. AVFoundation converts audio
to Float32 buffers, which destroys the LSB encoding. The Swift
implementation must read WAV files as raw `Data` and skip the RIFF header
(typically 44 bytes) to reach PCM samples directly.

```swift
// Standard PCM WAV: 44-byte header, then raw sample bytes
let pcmOffset = 44
var frames = [UInt8](wavData[pcmOffset...])
// LSB embed/extract operates on frames[]
```

---

## Migration Phases

### Phase 1 — Project Scaffolding

**Goal:** Establish the Swift package structure mirroring the Python layout.

```
AudioPasswordAgent/
├── Package.swift
├── Sources/
│   └── AudioPasswordAgentCore/     ← pure Swift, no UI dependency
│       ├── CryptoManager.swift
│       ├── AudioSteganography.swift
│       └── AudioPasswordAgent.swift
├── App/                             ← Xcode app target (SwiftUI)
│   ├── AudioPasswordAgentApp.swift
│   ├── Views/
│   │   ├── TimelineView.swift       ← main DAW-style track view
│   │   ├── TrackRowView.swift       ← one row per credential category
│   │   ├── ClipView.swift          ← colored block with waveform
│   │   ├── EditorPanelView.swift   ← credential detail / editor
│   │   └── TransportBarView.swift  ← top bar (lock timer, controls)
│   ├── ViewModels/
│   │   ├── TimelineViewModel.swift
│   │   └── EditorViewModel.swift
│   └── Theme/
│       ├── AppTheme.swift          ← orange accent, dark/light
│       └── Colors.swift
└── Tests/
    └── AudioPasswordAgentTests/
        ├── CryptoManagerTests.swift
        ├── AudioSteganographyTests.swift
        └── AudioPasswordAgentTests.swift
```

`Package.swift` dependencies: none external — CryptoKit, CommonCrypto, and
Foundation cover everything. The `App/` target is an Xcode target that
imports `AudioPasswordAgentCore` as a local package.

**Deliverable:** `swift build` succeeds with empty stubs.

---

### Phase 2 — CryptoManager

Port `crypto.py` → `CryptoManager.swift`.

Tasks:
- Implement `deriveKey(password:) -> Data` — exact SHA256 chain (100K iters)
- Implement Fernet `encrypt(data:key:) throws -> Data`
  - Generate 16-byte random IV via `SystemRandomNumberGenerator`
  - AES-128-CBC via `CommonCrypto`
  - HMAC-SHA256 over `version + timestamp + IV + ciphertext`
  - Concatenate all fields, base64url-encode
- Implement `decrypt(token:key:) throws -> String`
  - base64url-decode, split fields
  - Verify HMAC before decrypting (timing-safe compare)
  - AES-128-CBC decrypt, strip PKCS7 padding

**Validation gate:** Write a cross-language test — encrypt in Python, decrypt
in Swift and vice versa — before moving to Phase 3.

---

### Phase 3 — AudioSteganography

Port `audio.py` → `AudioSteganography.swift`.

Tasks:
- `validateAudioFile(path:) throws` — check extension, parse RIFF header,
  verify `nframes >= 100`
- `embedData(audioFile:data:outputFile:) throws` — read raw bytes, skip
  header, write bits into LSBs of PCM bytes, rewrite file
- `extractData(audioFile:) throws -> Data` — collect LSBs, assemble bytes,
  strip trailing null bytes

WAV parsing notes:
- Read `Data(contentsOf:)` for the full file
- Parse RIFF chunk (`RIFF`, file size, `WAVE`) at bytes 0–11
- Find `data` sub-chunk (scan for `"data"` marker after `fmt ` chunk)
  rather than assuming a fixed 44-byte offset — this handles non-standard
  headers correctly

**Validation gate:** Embed data with Python, extract with Swift (and
reverse) using the same WAV file.

---

### Phase 4 — Agent Orchestrator

Port `agent.py` → `AudioPasswordAgent.swift`.

Tasks:
- `init(masterPassword:)` — calls `CryptoManager.deriveKey`
- `storeCredential(audioFile:service:username:password:metadata:outputFile:) -> Result`
- `retrieveCredential(audioFile:service:) -> Result`
- `listStoredServices() -> [String: ServiceInfo]`
- Define `CredentialResult` as a Swift `enum` (success/failure with
  associated values) replacing the Python dict-based responses

The Swift version uses `Codable` structs for the JSON payload instead of
plain dicts:

```swift
struct CredentialPayload: Codable {
    let service: String
    let username: String
    let encryptedPassword: String   // base64url Fernet token
    let timestamp: String
    let version: String
    let customMetadata: [String: String]
}
```

---

### Phase 5 — SwiftUI Interface

Build the DAW-style macOS app on top of the Phase 4 core. The UI is split
into three regions that mirror the design:

**TransportBarView** (top strip)
- Session lock timer (counts up from unlock, shown as `00:02:48`)
- Lock/unlock button (triggers master-password prompt via `SecKeychainItem`
  or a local `@State` sheet)
- Dark/Light theme toggle

**TimelineView** (main canvas)
- `ScrollView(.horizontal)` containing `LazyHStack` of time columns
- Each row = one `TrackRowView` (credential category: Work, Social, etc.)
- Each colored block = one `ClipView` (a single WAV credential file)
  - Color assigned per category
  - Waveform drawn with SwiftUI `Path` from PCM sample amplitudes
  - Tap to select → opens `EditorPanelView`

**EditorPanelView** (right/bottom sheet — visible in "editor" screenshots)
- Shows service name, username, masked password with reveal toggle
- "Knobs" styled as circular `Slider` wrappers → control metadata fields
- Horizontal sliders → could represent password strength, expiry countdown,
  or custom metadata values
- Save button calls `AudioPasswordAgent.storeCredential()`

**Theme:**
```swift
extension Color {
    static let accent    = Color(hex: "#FF6B00")   // orange
    static let clipPink  = Color(hex: "#FF6B9D")
    static let clipGreen = Color(hex: "#4CAF82")
    static let clipBrown = Color(hex: "#C4843A")
    static let clipBlue  = Color(hex: "#5B8CDB")
    static let clipSalmon = Color(hex: "#E8736A")
}
```

Both `.dark` and `.light` color schemes are supported via SwiftUI's
`.preferredColorScheme` toggle stored in `AppStorage`.

---

### Phase 6 — XCTest Suite

Mirror the Python test coverage:

| Python test | Swift equivalent |
|---|---|
| `test_crypto.py` | `CryptoManagerTests` |
| `test_audio.py` | `AudioSteganographyTests` |
| `test_agent.py` | `AudioPasswordAgentTests` |

Generate test WAV fixtures programmatically (1 s @ 44.1 kHz, 16-bit PCM)
inside `setUpWithError()` using `AVAudioPCMBuffer` written to a temp file.

---

### Phase 7 — Cross-Validation & Cleanup

- Run full Python test suite and Swift test suite against the **same set of
  WAV fixtures** to confirm byte-for-byte compatibility
- Benchmark key derivation (100K SHA256 iters) on target hardware; add a
  progress indicator if > 1 s
- Remove Python source once all tests pass and the team is satisfied
- Update `README.md` with Swift build/run instructions

---

## Risk Register

| Risk | Likelihood | Mitigation |
|---|---|---|
| Fernet AES-CBC not in CryptoKit | **Certain** | Use CommonCrypto (Phase 2) |
| Non-standard WAV headers break offset=44 assumption | Medium | Parse RIFF chunks dynamically (Phase 3) |
| Timing of HMAC verification | Low | Use `ConstantTimeDataUtils` or compare hashes, not byte-by-byte |
| Swift on Linux missing CommonCrypto | Medium | Wrap with `#if canImport(CommonCrypto)` + OpenSSL fallback |
| Key derivation performance | Low | Benchmark early in Phase 2 |

---

## Phase Checklist

- [ ] Phase 1 — Package scaffolding, `swift build` green
- [ ] Phase 2 — `CryptoManager` + cross-language Fernet roundtrip test
- [ ] Phase 3 — `AudioSteganography` + cross-language WAV roundtrip test
- [ ] Phase 4 — `AudioPasswordAgent` orchestrator
- [ ] Phase 5 — SwiftUI app (TimelineView, EditorPanelView, TransportBar, themes)
- [ ] Phase 6 — Full XCTest suite passing
- [ ] Phase 7 — Cross-validation, cleanup, docs
