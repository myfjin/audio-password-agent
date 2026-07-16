# Audio Password Agent

A macOS SwiftUI app that hides AES-256-GCM encrypted credentials inside WAV audio files using LSB steganography. The UI looks like a DAW (Digital Audio Workstation), disguising the password manager as audio editing software.

## Architecture

```
audio-password-agent/
├── Packages/AudioPasswordAgentCore/   ← Pure Swift library (no UI)
│   └── Sources/AudioPasswordAgentCore/
│       ├── CryptoManager.swift        ← AES-256-GCM + PBKDF2-SHA256
│       ├── WAVParser.swift            ← RIFF chunk walker
│       ├── AudioSteganography.swift   ← LSB embed/extract
│       ├── AudioPasswordAgent.swift   ← Vault orchestrator
│       ├── Errors.swift               ← CryptoError, AudioError, VaultError
│       ├── Credential.swift           ← CredentialInfo / Credential structs
│       ├── CredentialPayload.swift    ← Codable JSON embedded in WAV
│       └── VaultConfig.swift          ← Master salt persistence
└── App/Sources/                       ← SwiftUI macOS app
    ├── Managers/
    │   ├── KeychainManager.swift      ← macOS Keychain store/load/delete
    │   └── VaultManager.swift         ← Bridges Core ↔ SwiftUI
    ├── ViewModels/TimelineViewModel.swift
    ├── Views/
    │   ├── AddCredentialView.swift    ← Sheet to embed new credentials
    │   ├── UnlockView.swift           ← First-launch + manual unlock screen
    │   ├── TransportBarView.swift     ← DAW-style toolbar
    │   ├── TrackHeadersView.swift     ← Left-side track names
    │   ├── Timeline/
    │   │   ├── TimelineTracksView.swift
    │   │   └── ClipView.swift
    │   └── Editor/
    │       ├── EditorPanelView.swift  ← Credential reveal + copy UI
    │       ├── KnobView.swift
    │       └── VerticalSliderView.swift
    ├── Models/AppModels.swift
    └── Theme/AppTheme.swift
```

## Commands

### Run tests (Swift Package)
```bash
cd Packages/AudioPasswordAgentCore
swift test
```

### Build the app (CLI)
```bash
xcodebuild -project AudioPasswordAgent.xcodeproj -scheme AudioPasswordAgent -configuration Debug build
```

### Open in Xcode
```bash
open AudioPasswordAgent.xcodeproj
```

## Security model

1. **Steganography** — the WAV file is the first layer; the file is playable audio, not obviously a password store.
2. **AES-256-GCM** — the actual password field is encrypted via CryptoKit, authenticated, tamper-evident.
3. **PBKDF2-SHA256 (600,000 iterations)** — the master password is never stored; only the derived key is kept in memory.
4. **vault.config** — stores the master salt. This file must be backed up alongside vault WAVs; without it the key cannot be re-derived.
5. **Keychain** — master password cached in macOS Keychain for auto-unlock on relaunch.

## Token format

```
[version:1B | nonce:12B | ciphertext:NB | GCM-tag:16B]
```

## Payload framing inside WAV PCM data

```
[magic "APA1":4B | length-BE:4B | JSON payload bytes]
```

The JSON payload is a `CredentialPayload`:
```json
{ "version": "1.0", "service": "GitHub", "username": "me@example.com",
  "encryptedToken": "<base64>", "storedAt": "<ISO8601>", "metadata": {} }
```

## Vault directory structure

```
~/Library/Application Support/AudioPasswordAgent/vault/
├── vault.config          ← keep this backed up
├── Work/                 ← one subfolder = one DAW track
│   ├── github.wav
│   └── aws.wav
└── Social/
    └── twitter.wav
```

Subfolders become track rows. WAV files at the vault root land in a "General" track.

## Adding a credential

1. Click the **+** (orange circle plus) in the transport bar.
2. Enter service name, username, and password.
3. Choose a **carrier WAV** — any silent or musical WAV file; credentials are embedded in LSBs of PCM samples, inaudible.
4. Choose or create a **track folder** (vault subfolder).
5. Click **Store in WAV** — the output WAV is saved to the vault subfolder.

## Viewing a credential

Click a clip on the timeline → the editor panel opens on the left. The password field shows `••••••••`. Click the eye icon to decrypt and reveal it. Click the copy icon to copy to clipboard.

## WAV capacity

Each 16-bit PCM sample stores 2 bits of payload (the 2 LSBs). A 1-second WAV at 44.1 kHz mono provides ~11 KB of usable capacity — enough for any credential JSON payload (typically < 500 bytes).
