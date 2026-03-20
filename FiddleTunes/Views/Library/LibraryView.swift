// FiddleTunes/Views/Library/LibraryView.swift
import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tune.dateAdded, order: .reverse) private var tunes: [Tune]
    @EnvironmentObject var audio: AudioService

    @State private var searchText = ""
    @State private var showFilters = false
    @State private var selectedGenre: String?
    @State private var selectedType: String?
    @State private var selectedKey: String?
    @State private var selectedTuning: String?
    @State private var selectedTune: Tune?

    var filteredTunes: [Tune] {
        tunes.filter { tune in
            let matchesSearch = searchText.isEmpty ||
                tune.title.localizedCaseInsensitiveContains(searchText)
            let matchesGenre   = selectedGenre  == nil || tune.genre  == selectedGenre
            let matchesType    = selectedType   == nil || tune.type   == selectedType
            let matchesKey     = selectedKey    == nil || tune.key    == selectedKey
            let matchesTuning  = selectedTuning == nil || tune.tuning == selectedTuning
            return matchesSearch && matchesGenre && matchesType && matchesKey && matchesTuning
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if showFilters {
                    FilterPanelView(
                        selectedGenre: $selectedGenre,
                        selectedType: $selectedType,
                        selectedKey: $selectedKey,
                        selectedTuning: $selectedTuning
                    )
                    .transition(.move(edge: .top).combined(with: .opacity))
                }

                if filteredTunes.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(filteredTunes.enumerated()), id: \.element.id) { index, tune in
                                TuneRowView(tune: tune, index: index)
                                    .contentShape(Rectangle())
                                    .onTapGesture { selectedTune = tune }
                                    .swipeActions(edge: .trailing) {
                                        Button(role: .destructive) {
                                            deleteTune(tune)
                                        } label: {
                                            Label("Delete", systemImage: "trash")
                                        }
                                    }
                            }
                        }
                    }
                }
            }
            .background(Color("AppSurface"))
            .navigationTitle("FiddleTunes")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search tunes")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        withAnimation { showFilters.toggle() }
                    } label: {
                        Image(systemName: showFilters ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                            .foregroundStyle(Color("AppPrimary"))
                    }
                }
            }
            .sheet(item: $selectedTune) { tune in
                TunePlayerView(tune: tune)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Spacer()
            Text("No tunes yet.")
                .font(.custom("NotoSerif-Regular", size: 18))
                .foregroundStyle(Color("AppOnSurface"))
            Text("Tap + to add your first tune.")
                .font(.custom("NotoSerif-Regular", size: 14))
                .foregroundStyle(Color("AppOnSurfaceVariant"))
            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    private func deleteTune(_ tune: Tune) {
        if let filename = tune.audioFileName {
            audio.deleteAudioFile(named: filename)
        }
        modelContext.delete(tune)
    }
}
