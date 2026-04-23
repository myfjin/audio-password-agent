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

> **Note.** No backwards-compatibility is required with the Python Fernet
> format — the user has no credential-carrying WAV files produced by the
> Python version, only clean audio carriers. The migration therefore
> adopts modern authenticated encryption from scratch.

### 1. Encryption — AES-256-GCM

We use **AES-256-GCM** via CryptoKit. GCM is authenticated encryption,
so we get integrity + confidentiality in one primitive (no separate HMAC
step, no padding oracle concerns).

Token layout written into each WAV credential payload:

```
┌─────────┬─────────────────┬──────────────────────────────┐
│ version │ nonce (12 B)    │ ciphertext + auth tag (16 B) │
│ 1 byte  │                 │                              │
└─────────┴─────────────────┴──────────────────────────────┘
```

The version byte exists so we can evolve the format later without
breaking existing vault files.

### 2. Key Derivation — PBKDF2-SHA256 (600 000 iterations)

We use **PBKDF2-SHA256** with 600 000 iterations (OWASP 2023
recommendation). PBKDF2 is the industry standard and is available via
`CommonCrypto.CCKeyDerivationPBKDF`. The master salt lives in a vault
config file next to the WAV carriers.

```swift
CCKeyDerivationPBKDF(
    CCPBKDFAlgorithm(kCCPBKDF2),
    password, password.count,
    salt,     salt.count,
    CCPseudoRandomAlgorithm(kCCPRFHmacAlgSHA256),
    600_000,
    &derived, 32
)
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

Implements the authenticated-encryption stack in
`Packages/AudioPasswordAgentCore/Sources/AudioPasswordAgentCore/CryptoManager.swift`.

Surface:
- `generateSalt() -> Data` — 16 random bytes via `SecRandomCopyBytes`
- `deriveKey(password:salt:) throws -> SymmetricKey` — PBKDF2-SHA256,
  600 000 iterations, 32-byte output
- `encrypt(_:key:) throws -> Data` — AES-256-GCM with a fresh 12-byte
  nonce per call; returns `[version | nonce | ciphertext | tag]`
- `decrypt(_:key:) throws -> String` — parses token, verifies auth tag,
  returns UTF-8 plaintext

Errors surface as `CryptoError` cases:
`keyDerivationFailed`, `invalidToken(reason:)`,
`encryptionFailed`, `decryptionFailed`.

**Validation gate:** the XCTest suite in
`Tests/AudioPasswordAgentCoreTests/CryptoManagerTests.swift` covers:
determinism, uniqueness, roundtrip, Unicode payloads, nonce freshness,
wrong-key rejection, tampered-ciphertext rejection, tampered-tag
rejection, short-token rejection, unknown-version rejection. All green
before moving to Phase 3.

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
    let encryptedPassword: Data     // AES-GCM token (see Phase 2)
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

### Phase 7 — Cleanup

- Confirm full XCTest suite (crypto + audio + agent) green on macOS 13+
- Benchmark key derivation (600K PBKDF2-SHA256 iters) on target hardware;
  add a progress indicator if > 1 s
- Remove Python source once the Swift app fully replaces it
- Update `README.md` with Swift build/run instructions

---

## Risk Register

| Risk | Likelihood | Mitigation |
|---|---|---|
| Non-standard WAV headers break offset=44 assumption | Medium | Parse RIFF chunks dynamically (Phase 3) |
| Key derivation performance (600K iters) | Low | Benchmark early in Phase 2; derive master key once per session |
| Vault salt loss equals data loss | **High impact** | Store `vault.config` (with salt) alongside vault WAVs; include in backups |
| macOS Keychain entitlement issues in sandbox | Low | Config file approach sidesteps Keychain for v1 |

---

## Phase Checklist

- [x] Phase 1 — SwiftUI app shell running in Xcode
- [x] Phase 2 — `CryptoManager` (AES-GCM + PBKDF2) + full XCTest coverage
- [ ] Phase 3 — `AudioSteganography` + WAV roundtrip test
- [ ] Phase 4 — `AudioPasswordAgent` orchestrator
- [ ] Phase 5 — SwiftUI app (TimelineView, EditorPanelView, TransportBar, themes)
- [ ] Phase 6 — Full XCTest suite passing
- [ ] Phase 7 — Cross-validation, cleanup, docs
