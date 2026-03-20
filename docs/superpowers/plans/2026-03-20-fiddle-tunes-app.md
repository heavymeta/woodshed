# Fiddle Tunes App Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build a native iOS app (SwiftUI + SwiftData + CloudKit) for recording, categorizing, and memorizing fiddle tunes with AI-generated mnemonic flashcard images.

**Architecture:** SwiftData `Tune` model synced via CloudKit private database. `AudioService` (shared singleton, AVFoundation) handles recording, playback, and waveform sampling. `ImageGenerationService` calls DALL-E 3 to produce mnemonic images stored on the model. Five screens: Library tab, Tune Player, Flashcards tab, Add Tune modal, API key bootstrap alert.

**Tech Stack:** Swift 5.9, SwiftUI, SwiftData, CloudKit, AVFoundation, OpenAI DALL-E 3, XCTest

---

## File Map

```
FiddleTunes/
├── FiddleTunesApp.swift              # App entry, ModelContainer, API key bootstrap check
├── ContentView.swift                 # TabView: Library | Add FAB | Flashcards
│
├── Models/
│   └── Tune.swift                    # @Model class (SwiftData)
│
├── Services/
│   ├── KeychainService.swift         # Read/write API key to Keychain
│   ├── AudioService.swift            # AVFoundation: record, play, waveform, import, delete
│   └── ImageGenerationService.swift  # DALL-E 3 API call → Data
│
├── Views/
│   ├── Library/
│   │   ├── LibraryView.swift         # Search + list + swipe-delete + empty state
│   │   ├── TuneRowView.swift         # Single row: number, title, play button
│   │   └── FilterPanelView.swift     # Pull-down chip panel: Genre, Type, Key, Tuning
│   ├── Player/
│   │   ├── TunePlayerView.swift      # Full player: image, controls, speed picker
│   │   └── WaveformView.swift        # 50-bar static waveform from waveformSamples
│   ├── Flashcards/
│   │   ├── FlashcardsView.swift      # Weighted card stack, swipe gestures, loop
│   │   └── FlashcardCardView.swift   # Single card: image, title, play, states
│   └── AddTune/
│       ├── AddTuneView.swift         # Modal container: step 1 source → step 2 form
│       ├── RecordAudioView.swift     # Live mic recording with animated bars
│       └── TuneMetadataFormView.swift # Pickers + save action + image gen trigger
│
├── Helpers/
│   └── FlashcardWeighting.swift      # Pure function: weighted sort for flashcard deck
│
└── Resources/
    ├── Fonts/                        # NotoSerif, Manrope, MaterialSymbolsOutlined .ttf
    └── Assets.xcassets               # Color set tokens

FiddleTunesTests/
├── KeychainServiceTests.swift
├── ImageGenerationServiceTests.swift
├── AudioServiceWaveformTests.swift   # Tests waveform sampling logic
└── FlashcardWeightingTests.swift
```

---

## Task 1: Xcode Project Setup

**Files:**
- Create: `FiddleTunes.xcodeproj` (via Xcode)
- Create: `FiddleTunes/Resources/Fonts/` (add font files)
- Create: `FiddleTunes/FiddleTunes.entitlements`
- Modify: `FiddleTunes/Info.plist`

- [ ] **Step 1: Create the Xcode project**

  In Xcode: File → New → Project → iOS App.
  - Product name: `FiddleTunes`
  - Interface: SwiftUI
  - Language: Swift
  - Storage: None (SwiftData added manually)
  - Uncheck "Include Tests" — we'll add the test target manually for control

- [ ] **Step 2: Add test target**

  In Xcode: File → New → Target → Unit Testing Bundle.
  - Name: `FiddleTunesTests`
  - Target to be tested: `FiddleTunes`

- [ ] **Step 3: Add CloudKit capability**

  In Xcode: FiddleTunes target → Signing & Capabilities → + Capability → CloudKit.
  - Add container: `iCloud.com.YOUR_BUNDLE_ID.fiddletunes` (replace with your actual bundle ID)
  - Also enable iCloud → CloudKit checkbox

- [ ] **Step 4: Add background modes capability**

  Signing & Capabilities → + Capability → Background Modes → check "Remote notifications" (required for CloudKit push sync).

- [ ] **Step 5: Download and add fonts**

  Download from Google Fonts:
  - Noto Serif (Regular, Bold, Italic)
  - Manrope (Variable font)
  - Material Symbols Outlined (variable .ttf from https://github.com/google/material-symbols)

  Drag all `.ttf` files into `FiddleTunes/Resources/Fonts/` in Xcode. Ensure "Add to target: FiddleTunes" is checked for each.

- [ ] **Step 6: Register fonts in Info.plist**

  Add `UIAppFonts` array key with these string values:
  ```
  NotoSerif-Regular.ttf
  NotoSerif-Bold.ttf
  NotoSerif-Italic.ttf
  Manrope-VariableFont_wght.ttf
  MaterialSymbolsOutlined[FILL,GRAD,opsz,wght].ttf
  ```

- [ ] **Step 7: Add color tokens to Assets.xcassets**

  In Xcode Assets catalog, add these Color Sets (Light appearance only for v1):
  - `AppSurface`: `#fffcf7`
  - `AppPrimary`: `#59614e`
  - `AppSecondary`: `#785f55`
  - `AppTertiary`: `#6a6457`
  - `AppOnSurface`: `#383831`
  - `AppOnSurfaceVariant`: `#65655c`
  - `AppSurfaceContainer`: `#f6f4ec`
  - `AppSurfaceContainerLow`: `#fcf9f3`
  - `AppSurfaceContainerHigh`: `#f0eee5`
  - `AppSurfaceContainerHighest`: `#eae8de`
  - `AppSurfaceContainerLowest`: `#ffffff`
  - `AppOutlineVariant`: `#babab0`
  - `AppPrimaryContainer`: `#dde6ce`

- [ ] **Step 8: Add mic usage description to Info.plist**

  Add key `NSMicrophoneUsageDescription` with value:
  `"FiddleTunes needs microphone access to record your fiddle playing."`

- [ ] **Step 9: Commit**

  ```bash
  git add .
  git commit -m "chore: initial Xcode project with CloudKit, fonts, and color tokens"
  ```

---

## Task 2: Tune Model

**Files:**
- Create: `FiddleTunes/Models/Tune.swift`

- [ ] **Step 1: Create `Tune.swift`**

  ```swift
  // FiddleTunes/Models/Tune.swift
  import SwiftData
  import Foundation

  @Model
  final class Tune {
      @Attribute(.unique) var id: UUID = UUID()
      var title: String
      var genre: String       // "Old Time" | "Scandi" | "Celtic"
      var type: String        // "Reel" | "Jig" | "Waltz" | "Breakdown" | "Hornpipe" | "Other"
      var key: String         // e.g. "D Major", "G Major", "A minor"
      var tuning: String      // "Standard" | "Cross-G" | "AEAE" | "Other"
      var audioFileName: String?
      @Attribute(.externalStorage) var mnemonicImageData: Data?
      var mnemonicPrompt: String
      var waveformSamples: [Float] = []
      var knownCount: Int = 0
      var unknownCount: Int = 0
      var dateAdded: Date = Date()

      init(title: String, genre: String, type: String, key: String, tuning: String, mnemonicPrompt: String) {
          self.title = title
          self.genre = genre
          self.type = type
          self.key = key
          self.tuning = tuning
          self.mnemonicPrompt = mnemonicPrompt
      }
  }
  ```

- [ ] **Step 2: Verify the model compiles**

  Build the project (⌘B). Expect: Build Succeeded.

- [ ] **Step 3: Commit**

  ```bash
  git add FiddleTunes/Models/Tune.swift
  git commit -m "feat: add Tune SwiftData model"
  ```

---

## Task 3: KeychainService

**Files:**
- Create: `FiddleTunes/Services/KeychainService.swift`
- Create: `FiddleTunesTests/KeychainServiceTests.swift`

- [ ] **Step 1: Write failing tests**

  ```swift
  // FiddleTunesTests/KeychainServiceTests.swift
  import XCTest
  @testable import FiddleTunes

  final class KeychainServiceTests: XCTestCase {
      let testKey = "test.openai.key.unittest"

      override func tearDown() {
          KeychainService.delete(key: testKey)
      }

      func test_save_and_read_roundtrip() throws {
          KeychainService.save(key: testKey, value: "sk-test-1234")
          let result = KeychainService.read(key: testKey)
          XCTAssertEqual(result, "sk-test-1234")
      }

      func test_read_returns_nil_when_not_set() {
          let result = KeychainService.read(key: testKey)
          XCTAssertNil(result)
      }

      func test_overwrite_replaces_value() {
          KeychainService.save(key: testKey, value: "first")
          KeychainService.save(key: testKey, value: "second")
          XCTAssertEqual(KeychainService.read(key: testKey), "second")
      }

      func test_delete_removes_value() {
          KeychainService.save(key: testKey, value: "to-delete")
          KeychainService.delete(key: testKey)
          XCTAssertNil(KeychainService.read(key: testKey))
      }
  }
  ```

- [ ] **Step 2: Run tests — expect FAIL (type not found)**

  In Xcode: ⌘U. Expected: compile error "Cannot find type 'KeychainService'".

- [ ] **Step 3: Implement `KeychainService`**

  ```swift
  // FiddleTunes/Services/KeychainService.swift
  import Foundation
  import Security

  enum KeychainService {
      static func save(key: String, value: String) {
          let data = Data(value.utf8)
          let query: [CFString: Any] = [
              kSecClass: kSecClassGenericPassword,
              kSecAttrAccount: key
          ]
          // Delete existing before adding
          SecItemDelete(query as CFDictionary)
          let attributes: [CFString: Any] = [
              kSecClass: kSecClassGenericPassword,
              kSecAttrAccount: key,
              kSecValueData: data
          ]
          SecItemAdd(attributes as CFDictionary, nil)
      }

      static func read(key: String) -> String? {
          let query: [CFString: Any] = [
              kSecClass: kSecClassGenericPassword,
              kSecAttrAccount: key,
              kSecReturnData: true,
              kSecMatchLimit: kSecMatchLimitOne
          ]
          var result: AnyObject?
          let status = SecItemCopyMatching(query as CFDictionary, &result)
          guard status == errSecSuccess, let data = result as? Data else { return nil }
          return String(data: data, encoding: .utf8)
      }

      static func delete(key: String) {
          let query: [CFString: Any] = [
              kSecClass: kSecClassGenericPassword,
              kSecAttrAccount: key
          ]
          SecItemDelete(query as CFDictionary)
      }
  }
  ```

- [ ] **Step 4: Run tests — expect PASS**

  ⌘U. Expected: all 4 tests pass.

- [ ] **Step 5: Commit**

  ```bash
  git add FiddleTunes/Services/KeychainService.swift FiddleTunesTests/KeychainServiceTests.swift
  git commit -m "feat: add KeychainService with tests"
  ```

---

## Task 4: FlashcardWeighting Helper

**Files:**
- Create: `FiddleTunes/Helpers/FlashcardWeighting.swift`
- Create: `FiddleTunesTests/FlashcardWeightingTests.swift`

- [ ] **Step 1: Write failing tests**

  ```swift
  // FiddleTunesTests/FlashcardWeightingTests.swift
  import XCTest
  @testable import FiddleTunes

  final class FlashcardWeightingTests: XCTestCase {
      func test_tune_with_more_unknowns_sorts_first() {
          let tunes: [(known: Int, unknown: Int)] = [
              (known: 10, unknown: 1),  // well-known, should be last
              (known: 0, unknown: 5),   // struggling, should be first
              (known: 3, unknown: 3),   // middle
          ]
          let weights = tunes.map { FlashcardWeighting.weight(knownCount: $0.known, unknownCount: $0.unknown) }
          XCTAssertGreaterThan(weights[1], weights[2])
          XCTAssertGreaterThan(weights[2], weights[0])
      }

      func test_brand_new_tune_has_zero_weight() {
          let weight = FlashcardWeighting.weight(knownCount: 0, unknownCount: 0)
          XCTAssertEqual(weight, 0.0, accuracy: 0.001)
      }

      func test_all_known_approaches_zero() {
          let weight = FlashcardWeighting.weight(knownCount: 100, unknownCount: 0)
          XCTAssertLessThan(weight, 0.01)
      }

      func test_sorted_deck_puts_highest_weight_first() {
          // Simulated tuples: (id, known, unknown)
          let deck = [(id: 1, k: 5, u: 0), (id: 2, k: 0, u: 8), (id: 3, k: 2, u: 2)]
          let sorted = FlashcardWeighting.sort(deck.map { (id: $0.id, known: $0.k, unknown: $0.u) })
          XCTAssertEqual(sorted.first?.id, 2)
          XCTAssertEqual(sorted.last?.id, 1)
      }
  }
  ```

- [ ] **Step 2: Run tests — expect FAIL**

  ⌘U. Expected: compile error.

- [ ] **Step 3: Implement `FlashcardWeighting`**

  ```swift
  // FiddleTunes/Helpers/FlashcardWeighting.swift
  import Foundation

  enum FlashcardWeighting {
      /// Returns a weight in [0, 1). Higher = more unknown = should appear sooner.
      static func weight(knownCount: Int, unknownCount: Int) -> Double {
          let unknown = Double(unknownCount)
          let total = Double(knownCount + unknownCount)
          return unknown / (total + 1.0)
      }

      /// Sort a sequence by descending weight. Input items must provide known/unknown counts.
      static func sort(_ items: [(id: Int, known: Int, unknown: Int)]) -> [(id: Int, known: Int, unknown: Int)] {
          items.sorted { a, b in
              weight(knownCount: a.known, unknownCount: a.unknown) >
              weight(knownCount: b.known, unknownCount: b.unknown)
          }
      }
  }
  ```

- [ ] **Step 4: Run tests — expect PASS**

  ⌘U. Expected: all 4 tests pass.

- [ ] **Step 5: Commit**

  ```bash
  git add FiddleTunes/Helpers/FlashcardWeighting.swift FiddleTunesTests/FlashcardWeightingTests.swift
  git commit -m "feat: add FlashcardWeighting helper with tests"
  ```

---

## Task 5: ImageGenerationService

**Files:**
- Create: `FiddleTunes/Services/ImageGenerationService.swift`
- Create: `FiddleTunesTests/ImageGenerationServiceTests.swift`

- [ ] **Step 1: Write failing tests**

  ```swift
  // FiddleTunesTests/ImageGenerationServiceTests.swift
  import XCTest
  @testable import FiddleTunes

  // Protocol for injectable URLSession
  final class ImageGenerationServiceTests: XCTestCase {

      func test_buildRequest_includes_authorization_header() throws {
          let request = try ImageGenerationService.buildRequest(apiKey: "sk-abc", prompt: "test prompt")
          XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer sk-abc")
      }

      func test_buildRequest_sets_json_content_type() throws {
          let request = try ImageGenerationService.buildRequest(apiKey: "sk-abc", prompt: "test")
          XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
      }

      func test_buildRequest_encodes_prompt_in_body() throws {
          let request = try ImageGenerationService.buildRequest(apiKey: "sk-abc", prompt: "my prompt")
          let body = try XCTUnwrap(request.httpBody)
          let json = try JSONSerialization.jsonObject(with: body) as? [String: Any]
          XCTAssertEqual(json?["prompt"] as? String, "my prompt")
          XCTAssertEqual(json?["model"] as? String, "dall-e-3")
          XCTAssertEqual(json?["response_format"] as? String, "b64_json")
      }

      func test_decodeImageData_extracts_base64_png() throws {
          let samplePNG = Data([0x89, 0x50, 0x4E, 0x47]) // PNG magic bytes
          let b64 = samplePNG.base64EncodedString()
          let responseJSON = """
          {"data":[{"b64_json":"\(b64)"}]}
          """.data(using: .utf8)!
          let result = try ImageGenerationService.decodeImageData(from: responseJSON)
          XCTAssertEqual(result, samplePNG)
      }
  }
  ```

- [ ] **Step 2: Run tests — expect FAIL**

  ⌘U. Expected: compile error.

- [ ] **Step 3: Implement `ImageGenerationService`**

  ```swift
  // FiddleTunes/Services/ImageGenerationService.swift
  import Foundation

  enum ImageGenerationService {
      static let endpoint = URL(string: "https://api.openai.com/v1/images/generations")!

      enum ImageGenError: Error {
          case missingAPIKey
          case badResponse
          case decodingFailed
      }

      static func buildRequest(apiKey: String, prompt: String) throws -> URLRequest {
          var request = URLRequest(url: endpoint)
          request.httpMethod = "POST"
          request.setValue("application/json", forHTTPHeaderField: "Content-Type")
          request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
          let body: [String: Any] = [
              "model": "dall-e-3",
              "prompt": prompt,
              "n": 1,
              "size": "1024x1024",
              "response_format": "b64_json"
          ]
          request.httpBody = try JSONSerialization.data(withJSONObject: body)
          return request
      }

      static func decodeImageData(from responseData: Data) throws -> Data {
          struct Response: Decodable {
              struct Item: Decodable { let b64_json: String }
              let data: [Item]
          }
          let response = try JSONDecoder().decode(Response.self, from: responseData)
          guard let b64 = response.data.first?.b64_json,
                let imageData = Data(base64Encoded: b64) else {
              throw ImageGenError.decodingFailed
          }
          return imageData
      }

      /// Generates a mnemonic image and returns PNG Data.
      static func generate(prompt: String) async throws -> Data {
          guard let apiKey = KeychainService.read(key: "openai.api.key") else {
              throw ImageGenError.missingAPIKey
          }
          let request = try buildRequest(apiKey: apiKey, prompt: prompt)
          let (data, response) = try await URLSession.shared.data(for: request)
          guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
              throw ImageGenError.badResponse
          }
          return try decodeImageData(from: data)
      }
  }
  ```

- [ ] **Step 4: Run tests — expect PASS**

  ⌘U. Expected: all 4 tests pass.

- [ ] **Step 5: Commit**

  ```bash
  git add FiddleTunes/Services/ImageGenerationService.swift FiddleTunesTests/ImageGenerationServiceTests.swift
  git commit -m "feat: add ImageGenerationService with DALL-E 3 support and tests"
  ```

---

## Task 6: AudioService — Waveform Sampling

**Files:**
- Create: `FiddleTunes/Services/AudioService.swift` (partial — waveform only first)
- Create: `FiddleTunesTests/AudioServiceWaveformTests.swift`

- [ ] **Step 1: Write failing tests for waveform sampling**

  ```swift
  // FiddleTunesTests/AudioServiceWaveformTests.swift
  import XCTest
  import AVFoundation
  @testable import FiddleTunes

  final class AudioServiceWaveformTests: XCTestCase {

      func test_normalize_returns_exactly_50_values() {
          let samples = Array(repeating: Float(0.5), count: 1000)
          let result = AudioService.normalize(samples: samples, targetCount: 50)
          XCTAssertEqual(result.count, 50)
      }

      func test_normalize_values_in_zero_to_one_range() {
          let samples = (0..<500).map { Float($0) }
          let result = AudioService.normalize(samples: samples, targetCount: 50)
          XCTAssertTrue(result.allSatisfy { $0 >= 0.0 && $0 <= 1.0 })
      }

      func test_normalize_silent_audio_returns_zeros() {
          let samples = Array(repeating: Float(0.0), count: 200)
          let result = AudioService.normalize(samples: samples, targetCount: 50)
          XCTAssertTrue(result.allSatisfy { $0 == 0.0 })
      }

      func test_normalize_handles_fewer_samples_than_target() {
          let samples = Array(repeating: Float(0.3), count: 10)
          let result = AudioService.normalize(samples: samples, targetCount: 50)
          XCTAssertEqual(result.count, 50)
      }
  }
  ```

- [ ] **Step 2: Run tests — expect FAIL**

  ⌘U. Expected: compile error.

- [ ] **Step 3: Create `AudioService.swift` with `normalize` function**

  ```swift
  // FiddleTunes/Services/AudioService.swift
  import Foundation
  import AVFoundation

  @MainActor
  final class AudioService: NSObject, ObservableObject {
      static let shared = AudioService()

      @Published var isPlaying = false
      @Published var isRecording = false

      private var player: AVAudioPlayer?
      private var recorder: AVAudioRecorder?

      private override init() {
          super.init()
          setupSession()
      }

      // MARK: - AVAudioSession

      private func setupSession() {
          do {
              try AVAudioSession.sharedInstance().setCategory(.playAndRecord, options: [.defaultToSpeaker])
              try AVAudioSession.sharedInstance().setActive(true)
          } catch {
              print("AudioService: session setup failed: \(error)")
          }
      }

      // MARK: - Waveform Sampling (static — testable without AVFoundation)

      /// Downsamples raw PCM floats to exactly `targetCount` normalized amplitude values in [0, 1].
      static func normalize(samples: [Float], targetCount: Int) -> [Float] {
          guard !samples.isEmpty, targetCount > 0 else {
              return Array(repeating: 0.0, count: targetCount)
          }
          // Chunk input into targetCount buckets, take RMS of each
          let chunkSize = max(1, samples.count / targetCount)
          var result: [Float] = []
          result.reserveCapacity(targetCount)
          let absMax = samples.map(abs).max() ?? 1.0
          let scale = absMax > 0 ? absMax : 1.0

          for i in 0..<targetCount {
              let start = i * chunkSize
              let end = min(start + chunkSize, samples.count)
              if start >= samples.count {
                  result.append(0.0)
              } else {
                  let chunk = samples[start..<end]
                  let rms = sqrt(chunk.map { $0 * $0 }.reduce(0, +) / Float(chunk.count))
                  result.append(min(rms / scale, 1.0))
              }
          }
          return result
      }

      /// Reads an audio file and returns exactly 50 normalized amplitude values.
      func sampleWaveform(from url: URL) -> [Float] {
          guard let audioFile = try? AVAudioFile(forReading: url),
                let format = AVAudioFormat(standardFormatWithSampleRate: audioFile.fileFormat.sampleRate, channels: 1) else {
              return Array(repeating: 0.0, count: 50)
          }
          let frameCount = AVAudioFrameCount(audioFile.length)
          guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount),
                (try? audioFile.read(into: buffer)) != nil,
                let channelData = buffer.floatChannelData?[0] else {
              return Array(repeating: 0.0, count: 50)
          }
          let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
          return AudioService.normalize(samples: samples, targetCount: 50)
      }
  }
  ```

- [ ] **Step 4: Run tests — expect PASS**

  ⌘U. Expected: all 4 tests pass.

- [ ] **Step 5: Commit**

  ```bash
  git add FiddleTunes/Services/AudioService.swift FiddleTunesTests/AudioServiceWaveformTests.swift
  git commit -m "feat: add AudioService skeleton with waveform sampling and tests"
  ```

---

## Task 7: AudioService — Recording, Playback, Import, Delete

**Files:**
- Modify: `FiddleTunes/Services/AudioService.swift`

- [ ] **Step 1: Add recording support to `AudioService`**

  Add these methods to `AudioService`:

  ```swift
  // MARK: - Recording

  private var tempRecordingURL: URL {
      FileManager.default.temporaryDirectory.appendingPathComponent("temp_recording.m4a")
  }

  func startRecording() throws {
      let settings: [String: Any] = [
          AVFormatIDKey: kAudioFormatMPEG4AAC,
          AVSampleRateKey: 44100.0,
          AVNumberOfChannelsKey: 1,
          AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
      ]
      recorder = try AVAudioRecorder(url: tempRecordingURL, settings: settings)
      recorder?.delegate = self
      recorder?.record()
      isRecording = true
  }

  /// Stops recording and returns the waveform samples. Call `saveRecording(named:)` to persist.
  func stopRecording() -> [Float] {
      recorder?.stop()
      isRecording = false
      return sampleWaveform(from: tempRecordingURL)
  }

  /// Moves the temp recording to the Documents directory. Returns the filename.
  @discardableResult
  func saveRecording(named filename: String) throws -> String {
      let dest = documentsURL(for: filename)
      if FileManager.default.fileExists(atPath: dest.path) {
          try FileManager.default.removeItem(at: dest)
      }
      try FileManager.default.moveItem(at: tempRecordingURL, to: dest)
      return filename
  }

  func cancelRecording() {
      recorder?.stop()
      recorder?.deleteRecording()
      isRecording = false
  }
  ```

- [ ] **Step 2: Add playback support**

  ```swift
  // MARK: - Playback

  func play(filename: String, rate: Float = 1.0) throws {
      // Stop recorder if active
      if isRecording { cancelRecording() }
      // Stop current player
      player?.stop()

      let url = documentsURL(for: filename)
      player = try AVAudioPlayer(contentsOf: url)
      player?.enableRate = true
      player?.prepareToPlay()
      player?.rate = rate
      player?.delegate = self
      player?.play()
      isPlaying = true
  }

  func stop() {
      player?.stop()
      isPlaying = false
  }

  func seek(by seconds: TimeInterval) {
      guard let player else { return }
      let newTime = max(0, min(player.duration, player.currentTime + seconds))
      player.currentTime = newTime
  }

  func setRate(_ rate: Float) {
      player?.rate = rate
  }
  ```

- [ ] **Step 3: Add import, delete, and helper methods**

  ```swift
  // MARK: - Import

  func importAudio(from sourceURL: URL) throws -> (filename: String, waveform: [Float]) {
      let filename = UUID().uuidString + "." + sourceURL.pathExtension
      let dest = documentsURL(for: filename)
      try FileManager.default.copyItem(at: sourceURL, to: dest)
      let waveform = sampleWaveform(from: dest)
      return (filename, waveform)
  }

  // MARK: - Delete

  func deleteAudioFile(named filename: String) {
      let url = documentsURL(for: filename)
      try? FileManager.default.removeItem(at: url)
  }

  // MARK: - Helpers

  private func documentsURL(for filename: String) -> URL {
      FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
          .appendingPathComponent(filename)
  }
  ```

- [ ] **Step 4: Add AVAudioPlayer/Recorder delegate conformance**

  ```swift
  // MARK: - Delegates

  extension AudioService: AVAudioPlayerDelegate {
      nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
          Task { @MainActor in self.isPlaying = false }
      }
  }

  extension AudioService: AVAudioRecorderDelegate {
      nonisolated func audioRecorderEncodeErrorDidOccur(_ recorder: AVAudioRecorder, error: Error?) {
          Task { @MainActor in
              self.isRecording = false
              // Error surfaced via isRecording state change; caller observes via @Published
          }
      }
  }
  ```

- [ ] **Step 5: Build — expect success**

  ⌘B. Fix any compile errors.

- [ ] **Step 6: Commit**

  ```bash
  git add FiddleTunes/Services/AudioService.swift
  git commit -m "feat: complete AudioService with recording, playback, import, and delete"
  ```

---

## Task 8: App Entry Point — ModelContainer + CloudKit + Bootstrap

**Files:**
- Modify: `FiddleTunes/FiddleTunesApp.swift`

- [ ] **Step 1: Implement `FiddleTunesApp.swift`**

  ```swift
  // FiddleTunes/FiddleTunesApp.swift
  import SwiftUI
  import SwiftData

  @main
  struct FiddleTunesApp: App {
      @State private var showAPIKeyAlert = false
      @State private var pendingAPIKey = ""

      var sharedModelContainer: ModelContainer = {
          let schema = Schema([Tune.self])
          let config = ModelConfiguration(
              schema: schema,
              cloudKitDatabase: .private("iCloud.com.YOUR_BUNDLE_ID.fiddletunes")
          )
          do {
              return try ModelContainer(for: schema, configurations: [config])
          } catch {
              fatalError("Could not create ModelContainer: \(error)")
          }
      }()

      var body: some Scene {
          WindowGroup {
              ContentView()
                  .onAppear { checkAPIKey() }
                  .alert("OpenAI API Key", isPresented: $showAPIKeyAlert) {
                      TextField("sk-...", text: $pendingAPIKey)
                          .autocorrectionDisabled()
                          .textInputAutocapitalization(.never)
                      Button("Save") {
                          KeychainService.save(key: "openai.api.key", value: pendingAPIKey)
                          pendingAPIKey = ""
                      }
                      Button("Cancel", role: .cancel) {}
                  } message: {
                      Text("Paste your OpenAI API key to enable mnemonic image generation.")
                  }
          }
          .modelContainer(sharedModelContainer)
      }

      private func checkAPIKey() {
          if KeychainService.read(key: "openai.api.key") == nil {
              showAPIKeyAlert = true
          }
      }
  }
  ```

  > Replace `YOUR_BUNDLE_ID` with your actual bundle identifier (e.g. `com.yourname.fiddletunes`).

- [ ] **Step 2: Build — expect success**

  ⌘B.

- [ ] **Step 3: Commit**

  ```bash
  git add FiddleTunes/FiddleTunesApp.swift
  git commit -m "feat: add app entry point with ModelContainer, CloudKit, and API key bootstrap"
  ```

---

## Task 9: ContentView — Tab Structure

**Files:**
- Modify: `FiddleTunes/ContentView.swift`

- [ ] **Step 1: Implement the tab bar**

  ```swift
  // FiddleTunes/ContentView.swift
  import SwiftUI

  struct ContentView: View {
      @State private var showAddTune = false
      @State private var selectedTab: Tab = .library

      enum Tab { case library, flashcards }

      var body: some View {
          ZStack(alignment: .bottom) {
              TabView(selection: $selectedTab) {
                  LibraryView()
                      .tag(Tab.library)
                  FlashcardsView()
                      .tag(Tab.flashcards)
              }
              .tabViewStyle(.page(indexDisplayMode: .never))

              // Custom bottom tab bar
              bottomBar
          }
          .sheet(isPresented: $showAddTune) {
              AddTuneView()
          }
          .ignoresSafeArea(edges: .bottom)
      }

      private var bottomBar: some View {
          HStack {
              // Library tab
              Button {
                  selectedTab = .library
              } label: {
                  VStack(spacing: 2) {
                      Image(systemName: selectedTab == .library ? "book.fill" : "book")
                          .font(.system(size: 22))
                      Text("Library")
                          .font(.custom("Manrope-Regular", size: 10))
                          .textCase(.uppercase)
                          .tracking(2)
                  }
                  .foregroundStyle(selectedTab == .library ? Color("AppPrimary") : Color("AppOnSurfaceVariant").opacity(0.6))
              }
              .frame(maxWidth: .infinity)

              // Add FAB (center)
              Button {
                  showAddTune = true
              } label: {
                  VStack(spacing: 2) {
                      ZStack {
                          Circle()
                              .fill(Color("AppPrimary"))
                              .frame(width: 56, height: 56)
                              .shadow(color: Color("AppOnSurface").opacity(0.15), radius: 8, y: 4)
                          Text("add")
                              .font(.custom("MaterialSymbolsOutlined", size: 28))
                              .foregroundStyle(Color("AppSurface"))
                      }
                      .offset(y: -12)
                      Text("Add")
                          .font(.custom("Manrope-Regular", size: 10))
                          .textCase(.uppercase)
                          .tracking(2)
                          .foregroundStyle(Color("AppOnSurfaceVariant").opacity(0.6))
                  }
              }
              .frame(maxWidth: .infinity)

              // Flashcards tab
              Button {
                  selectedTab = .flashcards
              } label: {
                  VStack(spacing: 2) {
                      Text(selectedTab == .flashcards ? "\u{E8F4}" : "\u{E8F4}") // style icon
                          .font(.custom("MaterialSymbolsOutlined", size: 22))
                      Text("Flashcards")
                          .font(.custom("Manrope-Regular", size: 10))
                          .textCase(.uppercase)
                          .tracking(2)
                  }
                  .foregroundStyle(selectedTab == .flashcards ? Color("AppPrimary") : Color("AppOnSurfaceVariant").opacity(0.6))
              }
              .frame(maxWidth: .infinity)
          }
          .padding(.horizontal, 16)
          .padding(.top, 8)
          .padding(.bottom, 28)
          .background(
              Color("AppSurface")
                  .overlay(alignment: .top) {
                      Divider().opacity(0.3)
                  }
                  .shadow(color: Color("AppOnSurface").opacity(0.04), radius: 20, y: -4)
          )
          .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
      }
  }
  ```

  > Material Symbols codepoints: `style` = `\u{E8F4}`. Verify the correct codepoint for your font version — the font maps icon names to Unicode codepoints which you can look up in the Material Symbols variable font reference.

- [ ] **Step 2: Add stub views so the project compiles**

  Create empty placeholder files so ContentView can reference them:

  ```swift
  // FiddleTunes/Views/Library/LibraryView.swift
  import SwiftUI
  struct LibraryView: View { var body: some View { Text("Library") } }

  // FiddleTunes/Views/Flashcards/FlashcardsView.swift
  import SwiftUI
  struct FlashcardsView: View { var body: some View { Text("Flashcards") } }

  // FiddleTunes/Views/AddTune/AddTuneView.swift
  import SwiftUI
  struct AddTuneView: View { var body: some View { Text("Add Tune") } }
  ```

- [ ] **Step 3: Build and run in simulator — verify tab bar appears**

  ⌘R. Expected: two placeholder screens with the custom tab bar at the bottom. Add FAB is center-raised.

- [ ] **Step 4: Commit**

  ```bash
  git add FiddleTunes/ContentView.swift FiddleTunes/Views/
  git commit -m "feat: add ContentView with custom tab bar and stub screens"
  ```

---

## Task 10: Library — TuneRowView

**Files:**
- Modify: `FiddleTunes/Views/Library/LibraryView.swift` (replace stub)
- Create: `FiddleTunes/Views/Library/TuneRowView.swift`

- [ ] **Step 1: Create `TuneRowView`**

  ```swift
  // FiddleTunes/Views/Library/TuneRowView.swift
  import SwiftUI

  struct TuneRowView: View {
      let tune: Tune
      let index: Int
      let onPlay: () -> Void

      var body: some View {
          HStack(spacing: 16) {
              Text(String(format: "%03d", index + 1))
                  .font(.custom("NotoSerif-Italic", size: 10))
                  .foregroundStyle(Color("AppSecondary").opacity(0.6))
                  .frame(width: 28, alignment: .leading)

              Text(tune.title)
                  .font(.custom("NotoSerif-Regular", size: 18))
                  .foregroundStyle(Color("AppOnSurface"))
                  .frame(maxWidth: .infinity, alignment: .leading)

              Button(action: onPlay) {
                  Text("play_arrow")
                      .font(.custom("MaterialSymbolsOutlined", size: 22))
                      .foregroundStyle(Color("AppPrimary"))
                      .frame(width: 40, height: 40)
                      .contentShape(Circle())
              }
              .buttonStyle(.plain)
          }
          .padding(.horizontal, 24)
          .padding(.vertical, 16)
          .background(Color("AppSurfaceContainerLow"))
          .overlay(alignment: .bottom) {
              Divider()
                  .foregroundStyle(Color("AppOutlineVariant").opacity(0.3))
          }
      }
  }
  ```

- [ ] **Step 2: Build — expect success**

  ⌘B.

- [ ] **Step 3: Commit**

  ```bash
  git add FiddleTunes/Views/Library/TuneRowView.swift
  git commit -m "feat: add TuneRowView"
  ```

---

## Task 11: Library — FilterPanelView

**Files:**
- Create: `FiddleTunes/Views/Library/FilterPanelView.swift`

- [ ] **Step 1: Create `FilterPanelView`**

  ```swift
  // FiddleTunes/Views/Library/FilterPanelView.swift
  import SwiftUI

  struct FilterPanelView: View {
      @Binding var selectedGenre: String?
      @Binding var selectedType: String?
      @Binding var selectedKey: String?
      @Binding var selectedTuning: String?

      let genres = ["Old Time", "Scandi", "Celtic"]
      let types = ["Reel", "Jig", "Waltz", "Breakdown", "Hornpipe", "Other"]
      let keys = ["D Major", "G Major", "A Major", "E Major", "C Major", "D minor", "G minor", "A minor"]
      let tunings = ["Standard", "Cross-G", "AEAE", "Other"]

      var body: some View {
          VStack(alignment: .leading, spacing: 16) {
              chipGroup(label: "Genre", options: genres, selection: $selectedGenre)
              chipGroup(label: "Type", options: types, selection: $selectedType)
              chipGroup(label: "Key", options: keys, selection: $selectedKey)
              chipGroup(label: "Tuning", options: tunings, selection: $selectedTuning)
          }
          .padding(.horizontal, 24)
          .padding(.vertical, 20)
          .background(Color("AppSurface"))
      }

      @ViewBuilder
      private func chipGroup(label: String, options: [String], selection: Binding<String?>) -> some View {
          VStack(alignment: .leading, spacing: 8) {
              Text(label)
                  .font(.custom("Manrope-Regular", size: 10))
                  .textCase(.uppercase)
                  .tracking(2)
                  .foregroundStyle(Color("AppOnSurfaceVariant").opacity(0.6))

              ScrollView(.horizontal, showsIndicators: false) {
                  HStack(spacing: 8) {
                      ForEach(options, id: \.self) { option in
                          let isSelected = selection.wrappedValue == option
                          Button {
                              selection.wrappedValue = isSelected ? nil : option
                          } label: {
                              Text(option)
                                  .font(.custom("Manrope-Regular", size: 12))
                                  .padding(.horizontal, 16)
                                  .padding(.vertical, 6)
                                  .background(isSelected ? Color("AppPrimary") : Color.clear)
                                  .foregroundStyle(isSelected ? Color("AppSurface") : Color("AppOnSurface"))
                                  .clipShape(Capsule())
                                  .overlay(Capsule().stroke(Color("AppOutlineVariant"), lineWidth: isSelected ? 0 : 1))
                          }
                          .buttonStyle(.plain)
                          .animation(.easeInOut(duration: 0.15), value: isSelected)
                      }
                  }
              }
          }
      }
  }
  ```

- [ ] **Step 2: Build — expect success**

  ⌘B.

- [ ] **Step 3: Commit**

  ```bash
  git add FiddleTunes/Views/Library/FilterPanelView.swift
  git commit -m "feat: add FilterPanelView with chip groups"
  ```

---

## Task 12: Library — LibraryView (Full)

**Files:**
- Modify: `FiddleTunes/Views/Library/LibraryView.swift`

- [ ] **Step 1: Implement full `LibraryView`**

  ```swift
  // FiddleTunes/Views/Library/LibraryView.swift
  import SwiftUI
  import SwiftData

  struct LibraryView: View {
      @Environment(\.modelContext) private var modelContext
      @Query(sort: \Tune.dateAdded, order: .reverse) private var allTunes: [Tune]
      @StateObject private var audio = AudioService.shared

      @State private var searchText = ""
      @State private var selectedGenre: String?
      @State private var selectedType: String?
      @State private var selectedKey: String?
      @State private var selectedTuning: String?
      @State private var filterPanelOffset: CGFloat = -220  // hidden above scroll
      @State private var isDragging = false
      @State private var selectedTune: Tune?

      private var filteredTunes: [Tune] {
          allTunes.filter { tune in
              (searchText.isEmpty || tune.title.localizedCaseInsensitiveContains(searchText))
              && (selectedGenre == nil || tune.genre == selectedGenre)
              && (selectedType == nil || tune.type == selectedType)
              && (selectedKey == nil || tune.key == selectedKey)
              && (selectedTuning == nil || tune.tuning == selectedTuning)
          }
      }

      var body: some View {
          NavigationStack {
              ZStack(alignment: .top) {
                  // Filter panel (slides in from top)
                  FilterPanelView(
                      selectedGenre: $selectedGenre,
                      selectedType: $selectedType,
                      selectedKey: $selectedKey,
                      selectedTuning: $selectedTuning
                  )
                  .offset(y: filterPanelOffset)
                  .zIndex(1)

                  ScrollView {
                      // Pull-down drag target at top of scroll
                      Color.clear
                          .frame(height: 1)
                          .gesture(
                              DragGesture()
                                  .onChanged { value in
                                      if value.translation.height > 0 {
                                          withAnimation(.spring(response: 0.3)) {
                                              filterPanelOffset = min(0, -220 + value.translation.height * 0.8)
                                          }
                                      }
                                  }
                                  .onEnded { value in
                                      withAnimation(.spring(response: 0.3)) {
                                          filterPanelOffset = value.translation.height > 80 ? 0 : -220
                                      }
                                  }
                          )

                      VStack(alignment: .leading, spacing: 0) {
                          // Header
                          VStack(alignment: .leading, spacing: 4) {
                              Text("Curated Anthology")
                                  .font(.custom("Manrope-Regular", size: 10))
                                  .textCase(.uppercase)
                                  .tracking(2)
                                  .foregroundStyle(Color("AppTertiary"))
                              Text("Library")
                                  .font(.custom("NotoSerif-Bold", size: 36))
                                  .foregroundStyle(Color("AppOnSurface"))
                          }
                          .padding(.horizontal, 24)
                          .padding(.top, 24)
                          .padding(.bottom, 16)

                          // Search bar
                          HStack {
                              Text("search")
                                  .font(.custom("MaterialSymbolsOutlined", size: 20))
                                  .foregroundStyle(Color("AppOnSurfaceVariant").opacity(0.5))
                              TextField("Search by title...", text: $searchText)
                                  .font(.custom("Manrope-Regular", size: 16))
                                  .autocorrectionDisabled()
                          }
                          .padding(.horizontal, 16)
                          .frame(height: 52)
                          .background(Color("AppSurfaceContainerLow"))
                          .clipShape(Capsule())
                          .overlay(Capsule().stroke(Color("AppOutlineVariant").opacity(0.3), lineWidth: 1))
                          .padding(.horizontal, 24)
                          .padding(.bottom, 24)

                          // Tune list
                          if filteredTunes.isEmpty {
                              emptyState
                          } else {
                              ForEach(Array(filteredTunes.enumerated()), id: \.element.id) { index, tune in
                                  NavigationLink(value: tune) {
                                      TuneRowView(tune: tune, index: index) {
                                          playInline(tune: tune)
                                      }
                                  }
                                  .buttonStyle(.plain)
                                  .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                      Button(role: .destructive) {
                                          deleteTune(tune)
                                      } label: {
                                          Label("Delete", systemImage: "trash")
                                      }
                                  }
                              }
                          }

                          // Bottom padding for tab bar
                          Spacer().frame(height: 100)
                      }
                  }
                  .scrollIndicators(.hidden)
              }
              .navigationDestination(for: Tune.self) { tune in
                  TunePlayerView(tune: tune)
              }
          }
          .background(Color("AppSurface"))
          // Tap outside filter panel to collapse it
          .onTapGesture {
              if filterPanelOffset == 0 {
                  withAnimation(.spring(response: 0.3)) { filterPanelOffset = -220 }
              }
          }
      }

      private var emptyState: some View {
          VStack(spacing: 12) {
              Text("No tunes yet.")
                  .font(.custom("NotoSerif-Regular", size: 18))
                  .foregroundStyle(Color("AppOnSurface"))
              Text("Tap + to add your first tune.")
                  .font(.custom("Manrope-Regular", size: 14))
                  .foregroundStyle(Color("AppOnSurfaceVariant"))
          }
          .frame(maxWidth: .infinity)
          .padding(.top, 60)
      }

      private func playInline(tune: Tune) {
          guard let filename = tune.audioFileName else { return }
          try? audio.play(filename: filename)
      }

      private func deleteTune(_ tune: Tune) {
          if let filename = tune.audioFileName {
              audio.deleteAudioFile(named: filename)
          }
          modelContext.delete(tune)
      }
  }
  ```

- [ ] **Step 2: Add stub `TunePlayerView` so NavigationLink compiles**

  ```swift
  // FiddleTunes/Views/Player/TunePlayerView.swift
  import SwiftUI
  struct TunePlayerView: View {
      let tune: Tune
      var body: some View { Text(tune.title) }
  }
  ```

- [ ] **Step 3: Build and run — verify library renders**

  ⌘R. Tap the Library tab. Expect: header, search bar, empty state message.

- [ ] **Step 4: Commit**

  ```bash
  git add FiddleTunes/Views/Library/LibraryView.swift FiddleTunes/Views/Player/TunePlayerView.swift
  git commit -m "feat: implement LibraryView with search, filter panel, and swipe-delete"
  ```

---

## Task 13: WaveformView

**Files:**
- Create: `FiddleTunes/Views/Player/WaveformView.swift`

- [ ] **Step 1: Create `WaveformView`**

  ```swift
  // FiddleTunes/Views/Player/WaveformView.swift
  import SwiftUI

  struct WaveformView: View {
      let samples: [Float]   // exactly 50 values in [0,1]
      var color: Color = Color("AppPrimary")

      var body: some View {
          GeometryReader { geo in
              HStack(alignment: .center, spacing: geo.size.width / CGFloat(samples.count * 3)) {
                  ForEach(Array(samples.enumerated()), id: \.offset) { _, sample in
                      RoundedRectangle(cornerRadius: 2)
                          .fill(color)
                          .frame(
                              width: max(2, geo.size.width / CGFloat(samples.count * 2)),
                              height: max(3, geo.size.height * CGFloat(sample))
                          )
                          .opacity(Double(0.3 + sample * 0.7))
                  }
              }
          }
      }
  }

  #Preview {
      WaveformView(samples: (0..<50).map { Float.random(in: 0...1) })
          .frame(height: 80)
          .padding()
  }
  ```

- [ ] **Step 2: Build — expect success**

  ⌘B.

- [ ] **Step 3: Commit**

  ```bash
  git add FiddleTunes/Views/Player/WaveformView.swift
  git commit -m "feat: add WaveformView"
  ```

---

## Task 14: TunePlayerView (Full)

**Files:**
- Modify: `FiddleTunes/Views/Player/TunePlayerView.swift`

- [ ] **Step 1: Implement full `TunePlayerView`**

  ```swift
  // FiddleTunes/Views/Player/TunePlayerView.swift
  import SwiftUI

  struct TunePlayerView: View {
      let tune: Tune
      @StateObject private var audio = AudioService.shared
      @State private var playbackRate: Float = 1.0
      @Environment(\.dismiss) private var dismiss

      let rates: [Float] = [0.5, 0.75, 1.0, 1.25]

      var body: some View {
          ScrollView {
              VStack(spacing: 24) {
                  // Mnemonic illustration
                  mnemonicImage
                      .frame(width: 200, height: 200)

                  // Title + metadata badges
                  VStack(spacing: 6) {
                      Text(tune.title)
                          .font(.custom("NotoSerif-Bold", size: 26))
                          .foregroundStyle(Color("AppOnSurface"))
                      HStack(spacing: 12) {
                          badge(tune.key)
                          badge(tune.type)
                      }
                  }

                  // Waveform
                  WaveformView(samples: tune.waveformSamples.isEmpty
                      ? Array(repeating: Float.random(in: 0.1...0.9), count: 50)
                      : tune.waveformSamples)
                      .frame(height: 80)
                      .padding(.horizontal, 24)

                  // Playback controls
                  playbackControls

                  // Speed picker
                  speedPicker

                  Spacer().frame(height: 40)
              }
              .padding(.top, 24)
          }
          .background(Color("AppSurface"))
          .navigationBarTitleDisplayMode(.inline)
          .toolbar {
              ToolbarItem(placement: .navigationBarLeading) {
                  Button { dismiss() } label: {
                      Text("arrow_back")
                          .font(.custom("MaterialSymbolsOutlined", size: 22))
                          .foregroundStyle(Color("AppPrimary"))
                  }
              }
          }
      }

      @ViewBuilder
      private var mnemonicImage: some View {
          ZStack {
              RoundedRectangle(cornerRadius: 12)
                  .fill(Color("AppSurfaceContainer"))
                  .rotationEffect(.degrees(3))
                  .scaleEffect(1.05)
                  .opacity(0.5)

              Group {
                  if let data = tune.mnemonicImageData, let uiImage = UIImage(data: data) {
                      Image(uiImage: uiImage)
                          .resizable()
                          .scaledToFill()
                          .grayscale(1.0)
                          .blendMode(.multiply)
                  } else {
                      Color("AppSurfaceContainerHigh")
                  }
              }
              .clipShape(RoundedRectangle(cornerRadius: 12))
              .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color("AppOutlineVariant").opacity(0.2), lineWidth: 1))
              .overlay(
                  RoundedRectangle(cornerRadius: 10)
                      .stroke(Color("AppPrimary").opacity(0.2), lineWidth: 0.5)
                      .padding(6)
              )
          }
      }

      @ViewBuilder
      private var playbackControls: some View {
          HStack(spacing: 32) {
              Button { audio.seek(by: -10) } label: {
                  Text("replay_10")
                      .font(.custom("MaterialSymbolsOutlined", size: 30))
                      .foregroundStyle(Color("AppOnSurfaceVariant"))
              }
              .buttonStyle(.plain)

              Button {
                  if audio.isPlaying {
                      audio.stop()
                  } else {
                      try? audio.play(filename: tune.audioFileName ?? "", rate: playbackRate)
                  }
              } label: {
                  ZStack {
                      Circle()
                          .fill(Color("AppPrimary"))
                          .frame(width: 80, height: 80)
                          .shadow(color: Color("AppOnSurface").opacity(0.15), radius: 12, y: 6)
                      Text(audio.isPlaying ? "pause" : "play_arrow")
                          .font(.custom("MaterialSymbolsOutlined", size: 44))
                          .foregroundStyle(Color("AppSurface"))
                  }
              }
              .buttonStyle(.plain)
              .disabled(tune.audioFileName == nil)

              Button { audio.seek(by: 10) } label: {
                  Text("forward_10")
                      .font(.custom("MaterialSymbolsOutlined", size: 30))
                      .foregroundStyle(Color("AppOnSurfaceVariant"))
              }
              .buttonStyle(.plain)
          }
      }

      @ViewBuilder
      private var speedPicker: some View {
          VStack(spacing: 8) {
              Text("Tempo Modulation")
                  .font(.custom("Manrope-Regular", size: 10))
                  .textCase(.uppercase)
                  .tracking(2)
                  .foregroundStyle(Color("AppOnSurfaceVariant").opacity(0.6))

              HStack(spacing: 4) {
                  ForEach(rates, id: \.self) { rate in
                      Button {
                          playbackRate = rate
                          audio.setRate(rate)
                      } label: {
                          Text("\(rate, specifier: "%.2g")x")
                              .font(.custom("Manrope-Regular", size: 13))
                              .fontWeight(playbackRate == rate ? .bold : .regular)
                              .frame(maxWidth: .infinity)
                              .padding(.vertical, 10)
                              .background(playbackRate == rate ? Color("AppPrimary") : Color.clear)
                              .foregroundStyle(playbackRate == rate ? Color("AppSurface") : Color("AppOnSurfaceVariant"))
                              .clipShape(RoundedRectangle(cornerRadius: 8))
                      }
                      .buttonStyle(.plain)
                  }
              }
              .padding(4)
              .background(Color("AppSurfaceContainerLow"))
              .clipShape(RoundedRectangle(cornerRadius: 12))
          }
          .padding(.horizontal, 24)
          .frame(maxWidth: 320)
      }

      private func badge(_ text: String) -> some View {
          Text(text)
              .font(.custom("Manrope-Regular", size: 10))
              .textCase(.uppercase)
              .tracking(1)
              .foregroundStyle(Color("AppOnSurfaceVariant"))
              .padding(.horizontal, 10)
              .padding(.vertical, 4)
              .background(Color("AppSurfaceContainerHigh"))
              .clipShape(Capsule())
      }
  }
  ```

- [ ] **Step 2: Build and run — navigate to player from library**

  Add a test tune via the Xcode debugger or temporarily hardcode one. Tap a tune row. Expect: player screen with image placeholder, waveform, controls, speed picker.

- [ ] **Step 3: Commit**

  ```bash
  git add FiddleTunes/Views/Player/TunePlayerView.swift
  git commit -m "feat: implement TunePlayerView with waveform, controls, and speed picker"
  ```

---

## Task 15: FlashcardCardView

**Files:**
- Create: `FiddleTunes/Views/Flashcards/FlashcardCardView.swift`

- [ ] **Step 1: Create `FlashcardCardView`**

  ```swift
  // FiddleTunes/Views/Flashcards/FlashcardCardView.swift
  import SwiftUI

  struct FlashcardCardView: View {
      let tune: Tune
      let cardNumber: Int
      let onPlay: () -> Void
      let onRetryImage: () -> Void

      var body: some View {
          ZStack {
              RoundedRectangle(cornerRadius: 16)
                  .fill(Color("AppSurfaceContainerLowest", bundle: nil))
                  .shadow(color: Color("AppOnSurface").opacity(0.06), radius: 24, y: 8)

              VStack(spacing: 0) {
                  // Card header
                  HStack(alignment: .top) {
                      VStack(alignment: .leading, spacing: 2) {
                          Text("Mnemonic No. \(cardNumber)")
                              .font(.custom("Manrope-Regular", size: 9))
                              .textCase(.uppercase)
                              .tracking(2)
                              .foregroundStyle(Color("AppOnSurfaceVariant").opacity(0.7))
                          masteryBadge
                      }
                      Spacer()
                      Button(action: onPlay) {
                          ZStack {
                              Circle()
                                  .fill(Color("AppPrimary"))
                                  .frame(width: 40, height: 40)
                              Text("play_arrow")
                                  .font(.custom("MaterialSymbolsOutlined", size: 22))
                                  .foregroundStyle(Color("AppSurface"))
                          }
                      }
                      .buttonStyle(.plain)
                  }
                  .padding(.horizontal, 24)
                  .padding(.top, 24)
                  .padding(.bottom, 20)

                  // Mnemonic image
                  mnemonicImage
                      .frame(maxWidth: .infinity)
                      .padding(.horizontal, 24)

                  // Title and subtitle
                  VStack(spacing: 4) {
                      Text(tune.title)
                          .font(.custom("NotoSerif-Bold", size: 24))
                          .foregroundStyle(Color("AppOnSurface"))
                      Text("\(tune.genre) · \(tune.key)")
                          .font(.custom("Manrope-Regular", size: 13))
                          .italic()
                          .foregroundStyle(Color("AppOnSurfaceVariant"))
                  }
                  .padding(.horizontal, 24)
                  .padding(.vertical, 20)
              }
          }
          .overlay(RoundedRectangle(cornerRadius: 16).stroke(Color("AppOutlineVariant").opacity(0.2), lineWidth: 0.5))
      }

      @ViewBuilder
      private var mnemonicImage: some View {
          RoundedRectangle(cornerRadius: 8)
              .fill(Color("AppSurfaceContainerLow"))
              .overlay {
                  if let data = tune.mnemonicImageData, let uiImage = UIImage(data: data) {
                      Image(uiImage: uiImage)
                          .resizable()
                          .scaledToFill()
                          .grayscale(1.0)
                          .blendMode(.multiply)
                          .overlay(Color("AppPrimary").opacity(0.05))
                          .clipShape(RoundedRectangle(cornerRadius: 8))
                          .overlay(
                              RoundedRectangle(cornerRadius: 6)
                                  .stroke(Color("AppPrimary").opacity(0.2), lineWidth: 0.5)
                                  .padding(6)
                          )
                  } else {
                      // Placeholder / retry state
                      VStack(spacing: 12) {
                          if tune.mnemonicPrompt.isEmpty {
                              ProgressView()
                          } else {
                              Text("No image yet")
                                  .font(.custom("Manrope-Regular", size: 13))
                                  .foregroundStyle(Color("AppOnSurfaceVariant"))
                              Button("Generate Image", action: onRetryImage)
                                  .font(.custom("Manrope-Regular", size: 12))
                                  .foregroundStyle(Color("AppPrimary"))
                          }
                      }
                  }
              }
              .aspectRatio(1.0, contentMode: .fit)
      }

      private var masteryBadge: some View {
          let total = tune.knownCount + tune.unknownCount
          let label: String
          let fill: Bool
          if total == 0 { label = "New"; fill = false }
          else if tune.knownCount > tune.unknownCount { label = "Mastery High"; fill = true }
          else { label = "Needs Work"; fill = false }

          return HStack(spacing: 3) {
              Text("star")
                  .font(.custom("MaterialSymbolsOutlined", size: 12))
              Text(label)
                  .font(.custom("Manrope-Regular", size: 10))
                  .fontWeight(.bold)
                  .textCase(.uppercase)
                  .tracking(2)
          }
          .foregroundStyle(Color("AppPrimary"))
      }
  }
  ```

- [ ] **Step 2: Build — expect success**

  ⌘B.

- [ ] **Step 3: Commit**

  ```bash
  git add FiddleTunes/Views/Flashcards/FlashcardCardView.swift
  git commit -m "feat: add FlashcardCardView with image states and mastery badge"
  ```

---

## Task 16: FlashcardsView (Full)

**Files:**
- Modify: `FiddleTunes/Views/Flashcards/FlashcardsView.swift`

- [ ] **Step 1: Implement full `FlashcardsView`**

  ```swift
  // FiddleTunes/Views/Flashcards/FlashcardsView.swift
  import SwiftUI
  import SwiftData

  struct FlashcardsView: View {
      @Query private var allTunes: [Tune]
      @Environment(\.modelContext) private var modelContext
      @StateObject private var audio = AudioService.shared

      @State private var deck: [Tune] = []
      @State private var dragOffset: CGSize = .zero
      @State private var isAnimatingSwipe = false

      private var topTune: Tune? { deck.first }

      var body: some View {
          ZStack {
              Color("AppSurface").ignoresSafeArea()

              if deck.isEmpty && allTunes.isEmpty {
                  emptyState
              } else {
                  cardStack
              }
          }
          .onAppear { buildDeck() }
          .onChange(of: allTunes.count) { buildDeck() }
      }

      // MARK: - Card Stack

      private var cardStack: some View {
          ZStack {
              // Background cards (decorative)
              if deck.count > 2 {
                  RoundedRectangle(cornerRadius: 16)
                      .fill(Color("AppSurfaceContainerHighest"))
                      .padding(.horizontal, 28)
                      .offset(y: 16)
                      .rotationEffect(.degrees(0.8))
                      .opacity(0.6)
              }
              if deck.count > 1 {
                  RoundedRectangle(cornerRadius: 16)
                      .fill(Color("AppSurfaceContainerHigh"))
                      .padding(.horizontal, 20)
                      .offset(y: 8)
                      .rotationEffect(.degrees(-1))
              }

              // Top (active) card
              if let tune = topTune, let index = allTunes.firstIndex(where: { $0.id == tune.id }) {
                  FlashcardCardView(
                      tune: tune,
                      cardNumber: index + 1,
                      onPlay: { try? audio.play(filename: tune.audioFileName ?? "") },
                      onRetryImage: { retryImageGeneration(for: tune) }
                  )
                  .padding(.horizontal, 12)
                  .offset(x: dragOffset.width, y: dragOffset.height * 0.2)
                  .rotationEffect(.degrees(Double(dragOffset.width) / 20.0))
                  .gesture(swipeGesture)
                  .overlay(swipeIndicator)
              }
          }
          .padding(.horizontal, 8)
          .frame(maxHeight: .infinity)
          .padding(.bottom, 100) // above tab bar
      }

      private var swipeGesture: some Gesture {
          DragGesture()
              .onChanged { value in
                  guard !isAnimatingSwipe else { return }
                  dragOffset = value.translation
              }
              .onEnded { value in
                  let threshold: CGFloat = 100
                  if value.translation.width > threshold {
                      swipe(direction: .right)
                  } else if value.translation.width < -threshold {
                      swipe(direction: .left)
                  } else {
                      withAnimation(.spring()) { dragOffset = .zero }
                  }
              }
      }

      @ViewBuilder
      private var swipeIndicator: some View {
          if dragOffset.width > 30 {
              Text("KNOW IT")
                  .font(.custom("Manrope-Regular", size: 16)).fontWeight(.bold)
                  .foregroundStyle(.green)
                  .padding(8)
                  .background(Color.green.opacity(0.15))
                  .clipShape(RoundedRectangle(cornerRadius: 8))
                  .rotationEffect(.degrees(-15))
                  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                  .padding(24)
                  .opacity(Double(min(dragOffset.width / 100, 1.0)))
          } else if dragOffset.width < -30 {
              Text("SKIP")
                  .font(.custom("Manrope-Regular", size: 16)).fontWeight(.bold)
                  .foregroundStyle(.red)
                  .padding(8)
                  .background(Color.red.opacity(0.15))
                  .clipShape(RoundedRectangle(cornerRadius: 8))
                  .rotationEffect(.degrees(15))
                  .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
                  .padding(24)
                  .opacity(Double(min(-dragOffset.width / 100, 1.0)))
          }
      }

      // MARK: - Swipe Logic

      enum SwipeDirection { case left, right }

      private func swipe(direction: SwipeDirection) {
          guard let tune = topTune else { return }
          isAnimatingSwipe = true

          let targetX: CGFloat = direction == .right ? 600 : -600
          withAnimation(.easeInOut(duration: 0.35)) {
              dragOffset = CGSize(width: targetX, height: 0)
          }

          DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
              // Update counts
              if direction == .right {
                  tune.knownCount += 1
              } else {
                  tune.unknownCount += 1
              }
              try? modelContext.save()

              // Advance deck
              deck.removeFirst()
              dragOffset = .zero
              isAnimatingSwipe = false

              // Rebuild if deck exhausted
              if deck.isEmpty { buildDeck() }
          }
      }

      // MARK: - Deck Management

      private func buildDeck() {
          let sorted = allTunes.sorted {
              FlashcardWeighting.weight(knownCount: $0.knownCount, unknownCount: $0.unknownCount) >
              FlashcardWeighting.weight(knownCount: $1.knownCount, unknownCount: $1.unknownCount)
          }
          deck = sorted
      }

      // MARK: - Image Retry

      private func retryImageGeneration(for tune: Tune) {
          Task {
              let data = try? await ImageGenerationService.generate(prompt: tune.mnemonicPrompt)
              await MainActor.run {
                  tune.mnemonicImageData = data
                  try? modelContext.save()
              }
          }
      }

      // MARK: - Empty State

      private var emptyState: some View {
          VStack(spacing: 16) {
              Text("No tunes yet.")
                  .font(.custom("NotoSerif-Regular", size: 22))
                  .foregroundStyle(Color("AppOnSurface"))
              Text("Add some tunes to your library to start practicing.")
                  .font(.custom("Manrope-Regular", size: 14))
                  .foregroundStyle(Color("AppOnSurfaceVariant"))
                  .multilineTextAlignment(.center)
              Text("↓ Tap + below")
                  .font(.custom("Manrope-Regular", size: 13))
                  .foregroundStyle(Color("AppPrimary"))
          }
          .padding(.horizontal, 40)
      }
  }
  ```

- [ ] **Step 2: Build and run — verify card stack**

  ⌘R. Switch to Flashcards tab. If no tunes exist, expect the empty state. After adding tunes (later), verify cards appear.

- [ ] **Step 3: Commit**

  ```bash
  git add FiddleTunes/Views/Flashcards/FlashcardsView.swift
  git commit -m "feat: implement FlashcardsView with weighted deck, swipe gestures, and loop"
  ```

---

## Task 17: AddTuneView — Recording Step

**Files:**
- Create: `FiddleTunes/Views/AddTune/RecordAudioView.swift`

- [ ] **Step 1: Create `RecordAudioView`**

  ```swift
  // FiddleTunes/Views/AddTune/RecordAudioView.swift
  import SwiftUI

  struct RecordAudioView: View {
      @StateObject private var audio = AudioService.shared
      let onComplete: (String, [Float]) -> Void  // filename, waveform
      let onImport: () -> Void

      @State private var animationPhase: CGFloat = 0

      var body: some View {
          VStack(spacing: 32) {
              Text("How would you like to add audio?")
                  .font(.custom("NotoSerif-Regular", size: 20))
                  .foregroundStyle(Color("AppOnSurface"))
                  .multilineTextAlignment(.center)
                  .padding(.top, 32)

              if audio.isRecording {
                  recordingInProgress
              } else {
                  sourceOptions
              }
          }
          .padding(.horizontal, 24)
      }

      private var sourceOptions: some View {
          VStack(spacing: 16) {
              // Record option
              Button {
                  try? audio.startRecording()
              } label: {
                  HStack(spacing: 16) {
                      ZStack {
                          Circle().fill(Color("AppPrimary")).frame(width: 48, height: 48)
                          Text("mic")
                              .font(.custom("MaterialSymbolsOutlined", size: 24))
                              .foregroundStyle(Color("AppSurface"))
                      }
                      VStack(alignment: .leading, spacing: 2) {
                          Text("Record")
                              .font(.custom("NotoSerif-Regular", size: 17))
                              .foregroundStyle(Color("AppOnSurface"))
                          Text("Capture yourself playing")
                              .font(.custom("Manrope-Regular", size: 12))
                              .foregroundStyle(Color("AppOnSurfaceVariant"))
                      }
                      Spacer()
                  }
                  .padding(20)
                  .background(Color("AppSurfaceContainerLow"))
                  .clipShape(RoundedRectangle(cornerRadius: 12))
                  .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color("AppOutlineVariant").opacity(0.3), lineWidth: 1))
              }
              .buttonStyle(.plain)

              // Import option
              Button(action: onImport) {
                  HStack(spacing: 16) {
                      ZStack {
                          Circle().fill(Color("AppSurfaceContainerHigh")).frame(width: 48, height: 48)
                          Text("upload_file")
                              .font(.custom("MaterialSymbolsOutlined", size: 24))
                              .foregroundStyle(Color("AppPrimary"))
                      }
                      VStack(alignment: .leading, spacing: 2) {
                          Text("Import")
                              .font(.custom("NotoSerif-Regular", size: 17))
                              .foregroundStyle(Color("AppOnSurface"))
                          Text("Choose an audio file")
                              .font(.custom("Manrope-Regular", size: 12))
                              .foregroundStyle(Color("AppOnSurfaceVariant"))
                      }
                      Spacer()
                  }
                  .padding(20)
                  .background(Color("AppSurfaceContainerLow"))
                  .clipShape(RoundedRectangle(cornerRadius: 12))
                  .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color("AppOutlineVariant").opacity(0.3), lineWidth: 1))
              }
              .buttonStyle(.plain)
          }
      }

      private var recordingInProgress: some View {
          VStack(spacing: 24) {
              // Animated waveform bars
              HStack(alignment: .center, spacing: 4) {
                  ForEach(0..<20, id: \.self) { i in
                      RoundedRectangle(cornerRadius: 2)
                          .fill(Color("AppPrimary"))
                          .frame(width: 4, height: CGFloat.random(in: 8...48))
                          .animation(
                              Animation.easeInOut(duration: 0.3)
                                  .repeatForever()
                                  .delay(Double(i) * 0.05),
                              value: animationPhase
                          )
                  }
              }
              .frame(height: 60)
              .onAppear { animationPhase = 1 }

              Text("Recording...")
                  .font(.custom("Manrope-Regular", size: 14))
                  .foregroundStyle(Color("AppOnSurfaceVariant"))

              Button {
                  let waveform = audio.stopRecording()
                  let filename = UUID().uuidString + ".m4a"
                  try? audio.saveRecording(named: filename)
                  onComplete(filename, waveform)
              } label: {
                  Text("Stop Recording")
                      .font(.custom("Manrope-Regular", size: 16)).fontWeight(.semibold)
                      .foregroundStyle(Color("AppSurface"))
                      .frame(maxWidth: .infinity)
                      .padding(.vertical, 16)
                      .background(Color("AppPrimary"))
                      .clipShape(RoundedRectangle(cornerRadius: 12))
              }
              .buttonStyle(.plain)
          }
      }
  }
  ```

- [ ] **Step 2: Build — expect success**

  ⌘B.

- [ ] **Step 3: Commit**

  ```bash
  git add FiddleTunes/Views/AddTune/RecordAudioView.swift
  git commit -m "feat: add RecordAudioView with mic recording and animated bars"
  ```

---

## Task 18: AddTuneView — Metadata Form + Full Modal

**Files:**
- Create: `FiddleTunes/Views/AddTune/TuneMetadataFormView.swift`
- Modify: `FiddleTunes/Views/AddTune/AddTuneView.swift`

- [ ] **Step 1: Create `TuneMetadataFormView`**

  ```swift
  // FiddleTunes/Views/AddTune/TuneMetadataFormView.swift
  import SwiftUI

  struct TuneMetadataFormView: View {
      @Binding var title: String
      @Binding var genre: String
      @Binding var type: String
      @Binding var key: String
      @Binding var tuning: String
      let onSave: () -> Void

      let genres = ["Old Time", "Scandi", "Celtic"]
      let types = ["Reel", "Jig", "Waltz", "Breakdown", "Hornpipe", "Other"]
      let keys = ["D Major", "G Major", "A Major", "E Major", "C Major", "D minor", "G minor", "A minor"]
      let tunings = ["Standard", "Cross-G", "AEAE", "Other"]

      var body: some View {
          VStack(spacing: 20) {
              Text("About This Tune")
                  .font(.custom("NotoSerif-Bold", size: 22))
                  .foregroundStyle(Color("AppOnSurface"))
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(.top, 8)

              // Title
              VStack(alignment: .leading, spacing: 6) {
                  fieldLabel("Title")
                  TextField("e.g. Soldier's Joy", text: $title)
                      .font(.custom("NotoSerif-Regular", size: 17))
                      .padding(.horizontal, 16)
                      .padding(.vertical, 14)
                      .background(Color("AppSurfaceContainerLow"))
                      .clipShape(RoundedRectangle(cornerRadius: 10))
                      .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color("AppOutlineVariant").opacity(0.3), lineWidth: 1))
              }

              pickerRow(label: "Genre", options: genres, selection: $genre)
              pickerRow(label: "Type", options: types, selection: $type)
              pickerRow(label: "Key", options: keys, selection: $key)
              pickerRow(label: "Tuning", options: tunings, selection: $tuning)

              Button(action: onSave) {
                  Text("Save & Generate Image")
                      .font(.custom("Manrope-Regular", size: 16)).fontWeight(.semibold)
                      .foregroundStyle(Color("AppSurface"))
                      .frame(maxWidth: .infinity)
                      .padding(.vertical, 16)
                      .background(title.isEmpty ? Color("AppPrimary").opacity(0.4) : Color("AppPrimary"))
                      .clipShape(RoundedRectangle(cornerRadius: 12))
              }
              .buttonStyle(.plain)
              .disabled(title.isEmpty)
          }
          .padding(.horizontal, 24)
      }

      private func fieldLabel(_ text: String) -> some View {
          Text(text)
              .font(.custom("Manrope-Regular", size: 10))
              .textCase(.uppercase)
              .tracking(2)
              .foregroundStyle(Color("AppOnSurfaceVariant").opacity(0.6))
      }

      @ViewBuilder
      private func pickerRow(label: String, options: [String], selection: Binding<String>) -> some View {
          VStack(alignment: .leading, spacing: 6) {
              fieldLabel(label)
              Picker(label, selection: selection) {
                  ForEach(options, id: \.self) { Text($0).tag($0) }
              }
              .pickerStyle(.menu)
              .tint(Color("AppPrimary"))
              .padding(.horizontal, 16)
              .padding(.vertical, 10)
              .frame(maxWidth: .infinity, alignment: .leading)
              .background(Color("AppSurfaceContainerLow"))
              .clipShape(RoundedRectangle(cornerRadius: 10))
              .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color("AppOutlineVariant").opacity(0.3), lineWidth: 1))
          }
      }
  }
  ```

- [ ] **Step 2: Implement full `AddTuneView`**

  ```swift
  // FiddleTunes/Views/AddTune/AddTuneView.swift
  import SwiftUI
  import SwiftData
  import UniformTypeIdentifiers

  struct AddTuneView: View {
      @Environment(\.modelContext) private var modelContext
      @Environment(\.dismiss) private var dismiss

      // Step tracking
      enum Step { case source, metadata }
      @State private var currentStep: Step = .source

      // Audio
      @State private var audioFilename: String?
      @State private var waveformSamples: [Float] = []
      @State private var showFilePicker = false

      // Metadata
      @State private var title = ""
      @State private var genre = "Old Time"
      @State private var type = "Reel"
      @State private var key = "D Major"
      @State private var tuning = "Standard"

      var body: some View {
          NavigationStack {
              ScrollView {
                  switch currentStep {
                  case .source:
                      RecordAudioView(
                          onComplete: { filename, waveform in
                              audioFilename = filename
                              waveformSamples = waveform
                              currentStep = .metadata
                          },
                          onImport: { showFilePicker = true }
                      )
                  case .metadata:
                      TuneMetadataFormView(
                          title: $title,
                          genre: $genre,
                          type: $type,
                          key: $key,
                          tuning: $tuning,
                          onSave: saveTune
                      )
                  }
              }
              .navigationTitle(currentStep == .source ? "Add Tune" : "Tune Details")
              .navigationBarTitleDisplayMode(.inline)
              .toolbar {
                  ToolbarItem(placement: .cancellationAction) {
                      Button("Cancel") { dismiss() }
                          .font(.custom("Manrope-Regular", size: 16))
                          .foregroundStyle(Color("AppPrimary"))
                  }
                  if currentStep == .metadata {
                      ToolbarItem(placement: .navigationBarLeading) {
                          Button {
                              currentStep = .source
                          } label: {
                              Text("arrow_back")
                                  .font(.custom("MaterialSymbolsOutlined", size: 22))
                                  .foregroundStyle(Color("AppPrimary"))
                          }
                      }
                  }
              }
          }
          .fileImporter(
              isPresented: $showFilePicker,
              allowedContentTypes: [.audio, UTType("public.mp3")!, UTType("com.apple.m4a-audio")!]
          ) { result in
              handleImport(result: result)
          }
      }

      private func handleImport(result: Result<URL, Error>) {
          guard case .success(let url) = result else { return }
          let audio = AudioService.shared
          guard let (filename, waveform) = try? audio.importAudio(from: url) else { return }
          audioFilename = filename
          waveformSamples = waveform
          currentStep = .metadata
      }

      private func saveTune() {
          let prompt = "Hand-drawn ink illustration of \(title), a \(genre) \(type), black and white, vintage engraving style, single scene"
          let tune = Tune(title: title, genre: genre, type: type, key: key, tuning: tuning, mnemonicPrompt: prompt)
          tune.audioFileName = audioFilename
          tune.waveformSamples = waveformSamples
          modelContext.insert(tune)
          try? modelContext.save()
          // Capture stable ID before dismissing — do NOT capture tune or modelContext across actor boundaries
          let tuneID = tune.id
          dismiss()

          // Trigger image generation in background.
          // Re-fetch the model by ID inside MainActor.run to avoid "ModelContext accessed from wrong actor" crash.
          Task {
              let data = try? await ImageGenerationService.generate(prompt: prompt)
              // Fetch a fresh descriptor on the main actor rather than capturing the model instance
              let descriptor = FetchDescriptor<Tune>(predicate: #Predicate { $0.id == tuneID })
              if let fetched = try? modelContext.fetch(descriptor).first {
                  fetched.mnemonicImageData = data
                  try? modelContext.save()
              }
          }
      }
  }
  ```

- [ ] **Step 3: Build and run — test the full add flow**

  ⌘R. Tap Add FAB. Expect: source picker modal. Tap Record → animated bars → stop → metadata form → save. Verify tune appears in Library.

- [ ] **Step 4: Commit**

  ```bash
  git add FiddleTunes/Views/AddTune/
  git commit -m "feat: implement full AddTune flow with recording, import, metadata, and image generation"
  ```

---

## Task 19: End-to-End Verification

- [ ] **Step 1: Run all unit tests**

  ⌘U. Expected: all tests pass (KeychainService, FlashcardWeighting, ImageGenerationService, AudioServiceWaveform).

- [ ] **Step 2: Manual smoke test — add a tune via recording**

  1. Launch app on device or simulator.
  2. Tap Add → Record → play a few notes → Stop Recording.
  3. Fill in title "Soldier's Joy", genre Old Time, type Reel, key D Major, tuning Standard.
  4. Tap "Save & Generate Image."
  5. Verify tune appears in Library with number 001 and play button.
  6. Verify flashcard appears in Flashcards tab with title and mastery badge.
  7. If API key is set, wait ~10s — verify mnemonic image appears on flashcard.

- [ ] **Step 3: Manual smoke test — import a tune**

  1. Tap Add → Import → pick an MP3 from Files.
  2. Fill metadata and save.
  3. Verify tune appears in Library.

- [ ] **Step 4: Manual smoke test — Library player**

  1. Tap a tune row → TunePlayer screen.
  2. Tap play → audio plays.
  3. Tap 0.5x speed → verify tempo slows.
  4. Tap replay 10s → playback jumps back.

- [ ] **Step 5: Manual smoke test — Flashcard swipe**

  1. Swipe right on a card → card animates off, "KNOW IT" indicator visible.
  2. Swipe left → "SKIP" indicator visible.
  3. After swiping through all cards, deck restarts.

- [ ] **Step 6: Manual smoke test — Filter panel**

  1. In Library tab, pull down from top of scroll.
  2. Filter panel slides in with Genre, Type, Key, Tuning chips.
  3. Tap "Old Time" → only Old Time tunes shown.
  4. Tap again → filter clears.

- [ ] **Step 7: Manual smoke test — Delete a tune**

  1. Swipe left on a Library row → red Delete button appears.
  2. Tap Delete → tune removed from list and Flashcards.

- [ ] **Step 8: Final commit**

  ```bash
  git add .
  git commit -m "feat: complete fiddle tunes app v1"
  ```

---

## Notes for Implementer

**CloudKit container ID:** Replace `iCloud.com.YOUR_BUNDLE_ID.fiddletunes` everywhere with your actual bundle identifier. Must also be created in the Apple Developer portal under Certificates, Identifiers & Profiles → Identifiers → App ID → CloudKit.

**Material Symbols codepoints:** The font maps icon names to Unicode codepoints. Look up exact codepoints at [fonts.google.com/icons](https://fonts.google.com/icons). The plan uses string literals (e.g. `"play_arrow"`) — for the font to render correctly, you may need to use the codepoint directly (e.g. `"\u{E037}"`) or use the ligature-enabled font setting. Test each icon renders correctly in a Xcode Preview.

**File picker UTTypes:** The `UTType("public.mp3")` initializer returns `Optional` — use `UTType.mp3` (iOS 14+) if available, and provide a fallback. Adjust as needed based on your deployment target.

**Font names:** The exact `Font.custom()` name string must match what the OS reports after loading. Print `UIFont.familyNames` to a console to discover the exact registered names after adding fonts.
