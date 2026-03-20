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

No backend. Everything runs client-side.

---

## Data Model

One `@Model` class, stored in SwiftData and synced via CloudKit:

```swift
@Model
class Tune {
    var id: UUID
    var title: String
    var genre: String          // "Old Time" | "Scandi" | "Celtic"
    var type: String           // "Reel" | "Jig" | "Waltz" | "Breakdown" | "Hornpipe" | …
    var key: String            // "D Major" | "G Major" | "A Major" | …
    var tuning: String         // "Standard" | "Cross-G" | "AEAE" | …
    var audioFileName: String  // local filename in app Documents dir (not synced)
    var mnemonicImageData: Data?   // PNG bytes, synced as CloudKit asset
    var mnemonicPrompt: String     // prompt used for generation (for regeneration)
    var knownCount: Int
    var unknownCount: Int
    var dateAdded: Date
}
```

**Sync strategy:**
- Metadata fields and `mnemonicImageData` sync via CloudKit automatically.
- Audio files are local-only (stored in the app's Documents directory). Too large and device-specific for CloudKit asset sync.

**Flashcard weighting:**
- Tunes are sorted for flashcard sessions by `unknownCount / (knownCount + unknownCount + 1)` descending — tunes you struggle with appear more often. No formal SRS scheduling.

---

## Screen Architecture

### Tab Bar
Three items: **Library** (left) | **Add** FAB (center, raised) | **Flashcards** (right).

### 1. Library (tab)
- Default state: search bar at top + scrollable list of tunes.
- Each row: sequential number (italic serif), tune title, inline play button.
- **Pull-down gesture** from resting position reveals a filter panel with four chip groups: Genre, Type, Key, Tuning. Releasing or scrolling up collapses the panel.
- Tapping a row navigates to the Tune Player screen.
- Inline play button plays audio without navigating.

### 2. Tune Player (pushed from Library)
- Back button in top-left nav bar.
- Mnemonic illustration (grayscale, ink-bleed mix-blend-multiply effect, decorative inner border).
- Title in Noto Serif, Key + Type badge pills beneath.
- Waveform visualization (static bars representing the recording).
- Playback controls: replay 10s | play/pause (large circular FAB) | forward 10s.
- Speed picker: 0.5x | 0.75x | 1.0x | 1.25x — segmented control.

### 3. Flashcards (tab)
- Asymmetric stacked card visual (three cards visible, slight rotation offsets).
- Active card: mnemonic illustration (full bleed with ink-bleed treatment), "Mnemonic No. X" label, mastery indicator, play button (top-right), tune title + description footer.
- **Swipe right** = know it → increments `knownCount`.
- **Swipe left** = don't know it → increments `unknownCount`.
- Deck loops continuously; no session-end screen.
- Tap play button to hear the tune without leaving the card.

### 4. Add Tune (modal, triggered by Add FAB)
Two-step flow:

**Step 1 — Audio source:**
- "Record" option: live mic recording with animated waveform feedback. Tap stop when done.
- "Import" option: system file picker filtered to audio types (MP3, M4A, WAV).

**Step 2 — Metadata form:**
- Title (text field)
- Genre picker: Old Time / Scandi / Celtic
- Type picker: Reel / Jig / Waltz / Breakdown / Hornpipe / (other)
- Key picker: common keys (D, G, A, E, C Major + common minors)
- Tuning picker: Standard / Cross-G / AEAE / (other)
- Save button → audio file copied to Documents dir, `Tune` saved to SwiftData, AI image generation triggered in background.

**AI image generation:**
- Prompt template: `"Hand-drawn ink illustration of [tune title], black and white, vintage engraving style, single scene"`
- Called async after save; flashcard shows a placeholder until image arrives.
- On success, `mnemonicImageData` updated on the model — CloudKit syncs automatically.
- On failure, a retry affordance appears on the flashcard.

---

## Services

### AudioService
Wraps AVFoundation. Responsibilities:
- **Recording:** `AVAudioRecorder` with mic permission check. Saves to a temp file, then moves to Documents on confirmation.
- **Playback:** `AVAudioPlayer` with `rate` property for speed control. Supports ±10s seeking via `currentTime`.
- **Import:** Accepts a URL from the system file picker, copies to Documents dir.

### ImageGenerationService
- Calls OpenAI Images API (`POST /v1/images/generations`) with DALL-E 3.
- Returns PNG `Data` (using `response_format: b64_json`).
- API key read from Keychain at call time, never embedded in source.

### Data layer
- `ModelContainer` configured with a CloudKit container identifier.
- `@Query` used in views for reactive list updates.
- Audio filenames stored on the model; files resolved against the Documents directory at runtime.

---

## Visual Style

Follows the provided mockups exactly:

| Token | Value |
|---|---|
| Background / Surface | `#fffcf7` |
| Primary | `#59614e` (olive) |
| Secondary | `#785f55` (warm brown) |
| Tertiary | `#6a6457` |
| On-Surface | `#383831` |
| Headline font | Noto Serif |
| Body / Label font | Manrope |
| Icons | Material Symbols Outlined |
| Image treatment | grayscale + contrast + sepia, `mix-blend-multiply` equivalent |
| Card corners | rounded (12pt) |
| Shadows | soft, warm-tinted |
| Filter/badge labels | uppercase, wide tracking |

---

## Error Handling

- **Mic permission denied:** Show inline prompt to open Settings.
- **File import fails:** Toast error, return to source picker.
- **AI image fails:** Placeholder shown on flashcard with a "Generate Image" retry button.
- **CloudKit unavailable:** App works fully offline; sync resumes when connectivity returns (SwiftData handles this automatically).
- **No audio file found:** Show error state on player; offer to re-record or re-import.

---

## Out of Scope

- Android / cross-platform
- Social features, sharing
- Notation / sheet music display
- Metronome
- User accounts (iCloud identity used implicitly)
- Settings screen (deferred to v2)
