// FiddleTunes/Views/Library/LibraryView.swift
import SwiftUI
import SwiftData

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Tune.dateAdded, order: .reverse) private var tunes: [Tune]
    @EnvironmentObject var audio: AudioService

    @State private var searchText = ""
    @State private var selectedGenre: String?
    @State private var selectedTuning: String?
    @State private var selectedTune: Tune?

    var filteredTunes: [Tune] {
        tunes.filter { tune in
            let matchesSearch = searchText.isEmpty ||
                tune.title.localizedCaseInsensitiveContains(searchText)
            let matchesGenre  = selectedGenre  == nil || tune.genre  == selectedGenre
            let matchesTuning = selectedTuning == nil || tune.tuning == selectedTuning
            return matchesSearch && matchesGenre && matchesTuning
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {

                    // Search
                    searchBar
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 24)

                    // Filter chips — always visible
                    filterRow(
                        label: "FILTER BY GENRE",
                        options: ["Old Time", "Scandi", "Celtic"],
                        selection: $selectedGenre
                    )
                    .padding(.bottom, 12)

                    filterRow(
                        label: "FILTER BY TUNING",
                        options: ["Standard", "Cross-G", "AEAE", "Other"],
                        selection: $selectedTuning
                    )
                    .padding(.bottom, 36)

                    // Section header
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CURATED ANTHOLOGY")
                            .font(.system(size: 11, weight: .semibold))
                            .tracking(2.5)
                            .foregroundStyle(Color("AppOnSurfaceVariant"))
                            .padding(.horizontal, 20)

                        Text("Library")
                            .font(.system(size: 42, weight: .bold, design: .serif))
                            .foregroundStyle(Color("AppOnSurface"))
                            .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 20)

                    // Tune list
                    if filteredTunes.isEmpty {
                        emptyState
                    } else {
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

                    Spacer(minLength: 100)
                }
            }
            .background(Color("AppSurface"))
            .navigationBarHidden(true)
            .sheet(item: $selectedTune) { tune in
                TunePlayerView(tune: tune)
                    .environmentObject(audio)
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Color("AppOnSurfaceVariant"))
            TextField("Search by title...", text: $searchText)
                .font(.system(size: 16))
                .foregroundStyle(Color("AppOnSurface"))
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
