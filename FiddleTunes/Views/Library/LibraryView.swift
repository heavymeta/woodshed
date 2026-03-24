// FiddleTunes/Views/Library/LibraryView.swift
import SwiftUI
import SwiftData

// Hooks into UIScrollView KVO to detect true rubber-band overscroll
private struct OverscrollDetector: UIViewRepresentable {
    let threshold: CGFloat
    let onOverscroll: () -> Void
    let onReset: () -> Void

    func makeUIView(context: Context) -> _OverscrollView {
        let v = _OverscrollView()
        v.threshold = threshold
        v.onOverscroll = onOverscroll
        v.onReset = onReset
        return v
    }

    func updateUIView(_ uiView: _OverscrollView, context: Context) {
        uiView.threshold = threshold
        uiView.onOverscroll = onOverscroll
        uiView.onReset = onReset
    }
}

final class _OverscrollView: UIView {
    var threshold: CGFloat = 50
    var onOverscroll: (() -> Void)?
    var onReset: (() -> Void)?
    private var kvo: NSKeyValueObservation?
    private var fired = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // Walk up to find the UIScrollView
        var v: UIView? = superview
        while let candidate = v {
            if let sv = candidate as? UIScrollView {
                kvo = sv.observe(\.contentOffset, options: .new) { [weak self] scrollView, _ in
                    guard let self else { return }
                    let overscroll = -(scrollView.contentOffset.y + scrollView.adjustedContentInset.top)
                    if overscroll > self.threshold, !self.fired {
                        self.fired = true
                        DispatchQueue.main.async { self.onOverscroll?() }
                    } else if overscroll <= 0, self.fired {
                        self.fired = false
                        DispatchQueue.main.async { self.onReset?() }
                    }
                }
                return
            }
            v = candidate.superview
        }
    }
}

// MARK: - Cascading fold modifier

private struct FoldEffect: ViewModifier {
    let isExpanded: Bool
    let index: Int
    let total: Int

    private let stagger: Double = 0.09

    func body(content: Content) -> some View {
        content
            .rotation3DEffect(
                .degrees(isExpanded ? 0 : -90),
                axis: (1, 0, 0),
                anchor: .top,
                perspective: 0.35
            )
            .opacity(isExpanded ? 1 : 0)
            .animation(
                .spring(response: 0.4, dampingFraction: 0.72)
                .delay(isExpanded
                       ? Double(index) * stagger          // top-down on open
                       : Double(total - 1 - index) * stagger), // bottom-up on close
                value: isExpanded
            )
    }
}

private extension View {
    func foldEffect(isExpanded: Bool, index: Int, total: Int) -> some View {
        modifier(FoldEffect(isExpanded: isExpanded, index: index, total: total))
    }
}

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tune.dateAdded, order: .reverse) private var tunes: [Tune]
    @EnvironmentObject var audio: AudioService

    @State private var searchText = ""
    @FocusState private var searchFocused: Bool
    @State private var selectedGenre: String?
    @State private var selectedKey: String?
    @State private var selectedTuning: String?
    @State private var selectedTune: Tune?
    @State private var showSettings = false
    @State private var pendingClaudeKey = ""
    @State private var pendingFalKey = ""
    @State private var filtersExpanded = false

    private let filterPanelHeight: CGFloat = 260

    var filteredTunes: [Tune] {
        tunes.filter { tune in
            let matchesSearch = searchText.isEmpty ||
                tune.title.localizedCaseInsensitiveContains(searchText)
            let matchesGenre  = selectedGenre  == nil || tune.genre  == selectedGenre
            let matchesKey    = selectedKey    == nil || tune.key    == selectedKey
            let matchesTuning = selectedTuning == nil || tune.tuning == selectedTuning
            return matchesSearch && matchesGenre && matchesKey && matchesTuning
        }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .topLeading) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {

                        // UIKit overscroll detector
                        OverscrollDetector(threshold: 50) {
                            withAnimation(.spring(response: 0.55, dampingFraction: 0.72)) {
                                filtersExpanded = true
                            }
                        } onReset: {}
                        .frame(height: 0)

                        // Filter fold panel
                        Color.clear
                            .frame(height: filtersExpanded ? filterPanelHeight : 0)
                            .overlay(alignment: .top) {
                                VStack(spacing: 0) {
                                    // Settings row (no fold)
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.25)) { showSettings = true }
                                    } label: {
                                        HStack {
                                            Image(systemName: "gearshape")
                                                .font(.system(size: 15))
                                            Text("Settings")
                                                .font(.system(size: 14))
                                            Spacer()
                                            Image(systemName: "chevron.right")
                                                .font(.system(size: 11))
                                                .foregroundStyle(Color("AppOnSurfaceVariant").opacity(0.45))
                                        }
                                        .foregroundStyle(Color("AppOnSurface"))
                                        .padding(.horizontal, 20)
                                        .padding(.vertical, 10)
                                    }
                                    .padding(.bottom, 6)

                                    filterRow(
                                        label: "FILTER BY GENRE",
                                        options: ["Old Time", "Scandi", "Celtic"],
                                        selection: $selectedGenre
                                    )
                                    .padding(.bottom, 12)
                                    .foldEffect(isExpanded: filtersExpanded, index: 0, total: 3)

                                    filterRow(
                                        label: "FILTER BY KEY",
                                        options: ["D Major", "G Major", "A Major", "A Minor", "B Minor", "D Minor", "E Minor", "Other"],
                                        selection: $selectedKey
                                    )
                                    .padding(.bottom, 12)
                                    .foldEffect(isExpanded: filtersExpanded, index: 1, total: 3)

                                    filterRow(
                                        label: "FILTER BY TUNING",
                                        options: ["Standard", "Cross-G", "AEAE", "Other"],
                                        selection: $selectedTuning
                                    )
                                    .padding(.bottom, 12)
                                    .foldEffect(isExpanded: filtersExpanded, index: 2, total: 3)
                                }
                                .padding(.top, 4)
                            }
                            .clipped()
                            .animation(.spring(response: 0.55, dampingFraction: 0.72), value: filtersExpanded)
                            .gesture(
                                DragGesture(minimumDistance: 30)
                                    .onEnded { value in
                                        let isHorizontal = abs(value.translation.width) > abs(value.translation.height)
                                        if isHorizontal {
                                            withAnimation(.spring(response: 0.45, dampingFraction: 0.8)) {
                                                filtersExpanded = false
                                            }
                                        }
                                    }
                            )

                        // Search
                        searchBar
                            .padding(.horizontal, 20)
                            .padding(.top, 16)
                            .padding(.bottom, 24)

                        // Tune list
                        if filteredTunes.isEmpty {
                            emptyState
                        } else {
                            ForEach(Array(filteredTunes.enumerated()), id: \.element.id) { index, tune in
                                TuneRowView(tune: tune, index: index,
                                            onTap: { selectedTune = tune },
                                            onDelete: { deleteTune(tune) })
                            }
                        }

                        Spacer(minLength: 100)
                    }
                }
                .background(Color("AppSurface"))

                // Settings drawer overlay
                if showSettings {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.easeInOut(duration: 0.25)) { showSettings = false }
                        }

                    settingsDrawer
                        .transition(.move(edge: .leading))
                }
            }
            .navigationBarHidden(true)
            .sheet(item: $selectedTune) { tune in
                TunePlayerView(tune: tune)
                    .environmentObject(audio)
            }
        }
    }

    // MARK: - Settings Drawer

    private var settingsDrawer: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Settings")
                    .font(.system(size: 22, weight: .semibold, design: .serif))
                    .foregroundStyle(Color("AppOnSurface"))
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) { showSettings = false }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(Color("AppOnSurfaceVariant"))
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 60)
            .padding(.bottom, 32)

            Divider().padding(.horizontal, 24)

            // OpenAI key
            VStack(alignment: .leading, spacing: 8) {
                Text("OPENAI API KEY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(Color("AppOnSurfaceVariant"))
                HStack {
                    Image(systemName: openAIKeyStored ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .foregroundStyle(openAIKeyStored ? Color.green : Color.orange)
                    Text(openAIKeyStored ? "Key stored" : "Not set")
                        .font(.system(size: 13))
                        .foregroundStyle(Color("AppOnSurfaceVariant"))
                }
                TextField("sk-...", text: $pendingClaudeKey)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(10)
                    .background(Color("AppSurfaceContainerHigh"))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 24)
            .padding(.top, 28)

            // Fal.ai key
            VStack(alignment: .leading, spacing: 8) {
                Text("FAL.AI API KEY")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.5)
                    .foregroundStyle(Color("AppOnSurfaceVariant"))
                HStack {
                    Image(systemName: falKeyStored ? "checkmark.circle.fill" : "exclamationmark.circle")
                        .foregroundStyle(falKeyStored ? Color.green : Color.orange)
                    Text(falKeyStored ? "Key stored" : "Not set")
                        .font(.system(size: 13))
                        .foregroundStyle(Color("AppOnSurfaceVariant"))
                }
                TextField("fal_key_...", text: $pendingFalKey)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .font(.system(size: 13, design: .monospaced))
                    .padding(10)
                    .background(Color("AppSurfaceContainerHigh"))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)

            Button {
                let oaiKey = pendingClaudeKey.trimmingCharacters(in: .whitespacesAndNewlines)
                let falKey = pendingFalKey.trimmingCharacters(in: .whitespacesAndNewlines)
                if !oaiKey.isEmpty {
                    KeychainService.save(key: MnemonicPromptService.keychainKey, value: oaiKey)
                    pendingClaudeKey = ""
                }
                if !falKey.isEmpty {
                    KeychainService.save(key: ImageGenerationService.keychainKey, value: falKey)
                    pendingFalKey = ""
                }
                withAnimation(.easeInOut(duration: 0.25)) { showSettings = false }
            } label: {
                Text("Save Keys")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color("AppPrimary"))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)

            Spacer()
        }
        .frame(width: 300)
        .background(Color("AppSurface"))
        .ignoresSafeArea()
    }

    private var openAIKeyStored: Bool {
        KeychainService.read(key: MnemonicPromptService.keychainKey) != nil
    }

    private var falKeyStored: Bool {
        KeychainService.read(key: ImageGenerationService.keychainKey) != nil
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color("AppOnSurfaceVariant"))
            TextField("Search by title...", text: $searchText)
                .font(.system(size: 16))
                .foregroundStyle(Color("AppOnSurface"))
                .focused($searchFocused)
            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchFocused = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color("AppOnSurfaceVariant"))
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 14)
        .background(Color("AppSurfaceContainerLow"))
        .clipShape(Capsule())
    }

    // MARK: - Filter Row

    @ViewBuilder
    private func filterRow(label: String, options: [String], selection: Binding<String?>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(2.5)
                .foregroundStyle(Color("AppOnSurfaceVariant"))
                .padding(.horizontal, 20)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        let isSelected = selection.wrappedValue == option
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selection.wrappedValue = isSelected ? nil : option
                            }
                        } label: {
                            Text(option)
                                .font(.system(size: 14))
                                .foregroundStyle(isSelected ? Color.white : Color("AppOnSurface"))
                                .padding(.horizontal, 18)
                                .padding(.vertical, 9)
                                .background(isSelected ? Color("AppPrimary") : Color.clear)
                                .clipShape(Capsule())
                                .overlay(
                                    Capsule().stroke(
                                        isSelected ? Color("AppPrimary") : Color("AppOutlineVariant"),
                                        lineWidth: 1
                                    )
                                )
                        }
                    }
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer(minLength: 48)
            Text("No tunes yet.")
                .font(.system(size: 20, design: .serif))
                .foregroundStyle(Color("AppOnSurface"))
            Text("Tap Add to record your first tune.")
                .font(.system(size: 14))
                .foregroundStyle(Color("AppOnSurfaceVariant"))
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 20)
    }

    // MARK: - Actions

    private func deleteTune(_ tune: Tune) {
        if let filename = tune.audioFileName {
            audio.deleteAudioFile(named: filename)
        }
        modelContext.delete(tune)
    }
}
