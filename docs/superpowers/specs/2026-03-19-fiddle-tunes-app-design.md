# Fiddle Tunes App — Design Spec
_2026-03-19_

## Overview

A native iOS app for recording, categorizing, practicing, and memorizing fiddle tunes. Two main tabs — Library and Flashcards — plus an Add flow for capturing new tunes. Visual style follows a parchment/scholarly aesthetic established in the provided mockups.

---

## Tech Stack

- **Framework:** SwiftUI (iOS 17+)
- **Data / sync:** SwiftData + CloudKit (iCloud)
- **Audio:** AVFoundation
- **Image generation:** OpenAI DALL-E 3 API (called directly from app)
- **Secrets:** OpenAI API key stored in Keychain
- **Icons:** Material Symbols Outlined (bundled variable font — not a system resource)

No backend. Everything runs client-side.

---

## Bootstrap: API Key Setup

On first launch, the app checks the Keychain for an OpenAI API key. If absent, it presents a one-time alert prompting the user to paste their key. The key is written to Keychain and never requested again. This is the only "settings" needed in v1; no Settings screen is required.

---

## Data Model

One `@Model` class, stored in SwiftData and synced via CloudKit:

```swift
@Model
class Tune {
    @Attribute(.unique) var id: UUID = UUID()
    var title: String
    var genre: String           // "Old Time" | "Scandi" | "Celtic"
    var type: String            // "Reel" | "Jig" | "Waltz" | "Breakdown" | "Hornpipe" | "Other"
    var key: String             // "D Major" | "G Major" | "A Major" | …
    var tuning: String          // "Standard" | "Cross-G" | "AEAE" | "Other"
    var audioFileName: String?  // local filename in app Documents dir (nil if audio missing)
    @Attribute(.externalStorage)
    var mnemonicImageData: Data?    // PNG bytes (~1-3 MB), stored externally to keep SQLite rows small
    var mnemonicPrompt: String      // template-expanded prompt, set synchronously at save time
    var waveformSamples: [Float] = []  // exactly 50 normalized amplitude values (0-1)
    var knownCount: Int = 0
    var unknownCount: Int = 0
    var dateAdded: Date = Date()
}
```

**Sync strategy:**
- Uses CloudKit **private database** (user's own iCloud account). Not the public database.
- Metadata fields and `mnemonicImageData` sync via CloudKit automatically.
- Audio files are local-only (stored in the app's Documents directory). Too large and device-specific for CloudKit asset sync.
- `mnemonicImageData` uses `@Attribute(.externalStorage)` so PNG bytes (~1–3 MB each) are stored in a sidecar file rather than inline in SQLite, keeping fetch performance acceptable. CloudKit syncs external storage as a `CKAsset` automatically.

**Audio file cleanup:**
- Deleting a `Tune` must also delete its audio file from Documents. `AudioService` exposes a `deleteAudioFile(named:)` method; the delete action calls this before removing the model.

**Flashcard weighting:**
- Sort order computed at session start and refreshed at the end of each loop through the deck. Formula: `unknownCount / (knownCount + unknownCount + 1)` descending — tunes you struggle with appear more often.
- A swipe mid-session does not reorder the current deck; the new order takes effect when the deck loops back to the beginning.

---

## Screen Architecture

### Tab Bar
Three items: **Library** (left) | **Add** FAB (center, raised) | **Flashcards** (right).

### 1. Library (tab)
- Default state: search bar at top + scrollable list of tunes.
- Each row: sequential number (italic serif), tune title, inline play button.
- **Pull-down filter panel:** Implemented as an offset `VStack` above the scroll origin, revealed by a custom `DragGesture` that fires only when scroll offset is at the top (tracked via `.onScrollGeometryChange` — available in iOS 17) and direction is downward — avoiding conflict with system scroll. Collapsing restores the offset. Panel contains four chip groups: Genre, Type, Key, Tuning.
- Tapping a row navigates to the Tune Player screen.
- Inline play button plays audio without navigating (uses shared `AudioService`; interrupts any current playback).
- **Empty state:** "No tunes yet. Tap + to add your first tune." centered in the list area.
- **Edit/Delete:** Swipe-to-delete on list rows. Tap-to-edit is out of scope for v1 (title typos can be fixed by delete + re-add).

### 2. Tune Player (pushed from Library)
- Back button in top-left nav bar.
- Mnemonic illustration (grayscale, `.blendMode(.multiply)` with sepia overlay, decorative inner border).
- Title in Noto Serif, Key + Type badge pills beneath.
- Waveform visualization: decorative static bars (heights pre-computed from audio sample amplitudes using `AVAudioFile` + `AVAudioPCMBuffer` at import/record time, stored as a `[Float]` array on the model). Not interactive.
- Playback controls: replay 10s | play/pause (large circular FAB) | forward 10s.
- Speed picker: 0.5x | 0.75x | 1.0x | 1.25x — segmented control. Uses `AVAudioPlayer` with `enableRate = true` set before `prepareToPlay`.
- **Missing audio state:** If `audioFileName` is nil or the file is not found, show a placeholder with a "Re-record or Import" button.

### 3. Flashcards (tab)
- Asymmetric stacked card visual (three cards visible, slight rotation offsets).
- Active card: mnemonic illustration (full bleed with `.blendMode(.multiply)` treatment), "Mnemonic No. X" label, mastery indicator, play button (top-right), tune title + description footer.
- **Swipe right** = know it → increments `knownCount`.
- **Swipe left** = don't know it → increments `unknownCount`.
- Deck loops continuously; no session-end screen. Sort order refreshes at each loop completion.
- Tap play button to hear the tune (uses shared `AudioService`; interrupts any current playback).
- **Empty state:** "Add some tunes to your library to start practicing." with an arrow pointing to the Add FAB.
- **Pending image state:** If `mnemonicImageData` is nil (generation in progress or failed), show a parchment-colored placeholder with a spinner or retry button respectively.
- **Retry:** Tapping "Generate Image" immediately re-calls `ImageGenerationService` with the stored `mnemonicPrompt`. No prompt editing in v1.

### 4. Add Tune (modal, triggered by Add FAB)
Two-step flow:

**Step 1 — Audio source:**
- "Record" option: live mic recording with animated waveform feedback. Tap stop when done. Mic permission requested here if not yet granted.
- "Import" option: system file picker filtered to audio types (MP3, M4A, WAV).

**Step 2 — Metadata form:**
- Title (text field)
- Genre picker: Old Time / Scandi / Celtic
- Type picker: Reel / Jig / Waltz / Breakdown / Hornpipe / Other
- Key picker: D, G, A, E, C Major + D, G, A minor (common fiddle keys)
- Tuning picker: Standard / Cross-G / AEAE / Other
- Save button → the `Tune` object is constructed here (after all metadata is available), `mnemonicPrompt` set to the expanded template string, audio file copied to Documents dir, waveform data computed from the audio file, then the model is inserted into SwiftData. AI image generation is triggered in a detached `Task` immediately after insert; on completion the model's `mnemonicImageData` is updated on the main actor.

**AI image generation:**
- Prompt template: `"Hand-drawn ink illustration of [tune title], a [genre] [type], black and white, vintage engraving style, single scene"` — genre and type are included to improve image specificity.
- Called async after save; flashcard shows placeholder until image arrives.
- On success, `mnemonicImageData` updated on the model — CloudKit syncs automatically.
- On failure, retry button appears on the flashcard (see Flashcards section).

---

## Services

### AudioService (shared singleton)
`AudioService.shared` — one instance across the app. A new `play()` call interrupts any in-progress playback.

**AVAudioSession configuration:**
- Category: `.playAndRecord`, options: `.defaultToSpeaker` (so playback routes to the speaker by default, not the earpiece).
- Session activated on first play/record action; remains active for the app's lifetime.
- External interruptions (phone calls, Siri): on interruption-began, pause playback. On interruption-ended with `shouldResume` flag, resume only if the app is in the foreground. This is a known gap — v1 may simply require a manual play tap after interruption.

Responsibilities:
- **Recording:** `AVAudioRecorder` with mic permission check. Settings: format `.aac`, sample rate `44100 Hz`, channels `1` (mono). Saves to a temp file; moves to Documents on confirmation. If `play()` is called while a recording is in progress, the recorder is stopped first, then playback begins.
- **Playback:** `AVAudioPlayer` with `enableRate = true` set before `prepareToPlay`. `rate` property used for speed control. ±10s seeking via `currentTime`.
- **Import:** Accepts a URL from the system file picker, copies to Documents dir, returns the local filename.
- **Waveform sampling:** Reads audio file using `AVAudioFile` + `AVAudioPCMBuffer`, downsamples to exactly 50 amplitude values normalized to 0–1. Called once at import/record time; result stored in `Tune.waveformSamples`.
- **Delete:** `deleteAudioFile(named:)` removes file from Documents dir.
- **Mic revocation:** If the OS terminates an in-progress recording due to permission revocation, handle the `AVAudioRecorderDelegate` error and return to the source picker with a message.

### ImageGenerationService
- Calls OpenAI Images API (`POST /v1/images/generations`) with model `dall-e-3`, `response_format: b64_json`, size `1024x1024`.
- Decodes base64 response to `Data`.
- API key read from Keychain at call time, never embedded in source.
- Acceptable risk for personal use: key lives on-device in Keychain; app is not distributed publicly.

### Data layer
- `ModelContainer` configured with CloudKit container identifier `iCloud.com.YOUR_BUNDLE_ID.fiddletunes` (replace with actual bundle ID). Must match the entitlement in the Xcode project and the App ID capability in the Apple Developer portal.
- `@Query` used in views for reactive list updates.
- Audio filenames stored on the model; files resolved against the Documents directory at runtime.

---

## Visual Style

Follows the provided mockups exactly. Three custom fonts must be bundled in the app target and declared under `UIAppFonts` in `Info.plist`: **Noto Serif**, **Manrope**, and **Material Symbols Outlined** (variable `.ttf`). None are system fonts.

| Token | Value |
|---|---|
| Background / Surface | `#fffcf7` |
| Primary | `#59614e` (olive) |
| Secondary | `#785f55` (warm brown) |
| Tertiary | `#6a6457` |
| On-Surface | `#383831` |
| Headline font | Noto Serif |
| Body / Label font | Manrope |
| Icons | Material Symbols Outlined (bundled) |
| Image treatment | grayscale + `.blendMode(.multiply)` + sepia overlay |
| Card corners | rounded (12pt) |
| Shadows | soft, warm-tinted |
| Filter/badge labels | uppercase, wide tracking |

---

## Error Handling

- **Mic permission denied:** Inline prompt to open Settings; recording path unavailable until granted.
- **File import fails:** Toast error, return to source picker.
- **AI image fails (any error — timeout, 4xx, 5xx):** Parchment placeholder on flashcard with "Generate Image" retry button. Retry is user-initiated only; no automatic retry to avoid hammering the API on rate-limit errors. Retry re-calls `ImageGenerationService` using the stored `mnemonicPrompt`.
- **CloudKit unavailable:** App works fully offline; sync resumes automatically when connectivity returns.
- **No audio file found:** Error state on player with "Re-record or Import" button.

---

## Out of Scope (v1)

- Android / cross-platform
- Social features, sharing
- Notation / sheet music display
- Metronome
- User accounts (iCloud identity used implicitly)
- Settings screen
- Editing tune metadata after save (delete + re-add as workaround)
- Interactive waveform scrubbing
- Spaced repetition scheduling
