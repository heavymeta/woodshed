# Woodshed

An iOS app for learning traditional fiddle tunes. Combines audio recording, spaced-repetition flashcards, and AI-generated mnemonic images to help you memorize a large repertoire.

## What it does

- **Flashcard practice** — swipe through your tune library. Swipe right when you know it, left when you don't. The algorithm surfaces tunes you're struggling with more often.
- **Mnemonic images** — tap to generate a vivid memory aid for each tune name. GPT-4o writes the scene; Flux renders it as a linocut-style illustration.
- **Audio recording** — record yourself playing a tune directly in the app. Waveform visualization, variable playback speed.
- **Tune library** — searchable list with filter chips for genre, key, and tuning. Ships pre-seeded with ~30 Irish, Scottish, and Scandinavian tunes.

## Requirements

- Xcode 16+
- iOS 17+ device or simulator
- An Apple developer account (for CloudKit)
- OpenAI API key (for mnemonic text generation)
- Fal.ai API key (for image generation)

## Setup

### 1. Clone and open

```bash
git clone https://github.com/heavymeta/woodshed.git
cd woodshed
open FiddleTunes.xcodeproj
```

### 2. Set your development team

In Xcode, select the `FiddleTunes` target → Signing & Capabilities → set your development team. The app uses a CloudKit container (`iCloud.com.iancurry.fiddletunes`) — you'll need to either provision that container under your account or swap it for your own in `FiddleTunes.entitlements` and `project.yml`.

### 3. Build and run

Build to a simulator or device. On first launch the app will prompt for:

- **OpenAI API key** — used to generate mnemonic scene descriptions (GPT-4o)
- **Fal.ai API key** — used to render mnemonic images (Flux Dev model)

Both keys are stored in the device keychain. You can skip these prompts and the app will work without AI features — tunes just won't have generated images.

### 4. Seed audio

Bundled tune recordings are distributed via CloudKit's public database to keep the app bundle small. On first launch the app fetches any missing audio files automatically. If you're running under a different CloudKit container the seed audio won't download — you can still add your own recordings manually.

## Project structure

```
FiddleTunes/
├── Models/              Tune (SwiftData)
├── Services/
│   ├── AudioService              Recording, playback, waveform sampling
│   ├── ImageGenerationService    Fal.ai Flux integration
│   ├── MnemonicPromptService     OpenAI GPT-4o integration
│   ├── KeychainService           Secure API key storage
│   ├── SeedService               Bundled tune seeding + deduplication
│   └── CloudKitSeedService       CloudKit audio sync
├── Views/
│   ├── Flashcards/               Card stack + swipe interactions
│   ├── Library/                  Tune list, search, filters
│   ├── AddTune/                  Record or import, metadata form
│   └── Player/                   Waveform display + playback controls
├── Helpers/
│   └── FlashcardWeighting        Spaced repetition algorithm
└── Resources/
    ├── seed_tunes.json           Bundled tune metadata (~30 tunes)
    └── Fonts/                    Noto Serif, Manrope, Material Symbols
```

## Tech

- SwiftUI + SwiftData
- CloudKit (iCloud sync)
- AVFoundation (audio)
- OpenAI API (GPT-4o)
- [Fal.ai](https://fal.ai) (Flux Dev image generation)
