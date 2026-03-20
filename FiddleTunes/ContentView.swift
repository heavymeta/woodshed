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
                    .tabItem {
                        Label("Library", systemImage: "music.note.list")
                    }

                FlashcardsView()
                    .tag(Tab.flashcards)
                    .tabItem {
                        Label("Flashcards", systemImage: "rectangle.on.rectangle")
                    }
            }
            .tint(Color("AppPrimary"))

            // Floating Add button centered above tab bar
            Button {
                showAddTune = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Color("AppPrimary"))
                    .background(Color("AppSurface").clipShape(Circle()))
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            }
            .padding(.bottom, 4)
        }
        .sheet(isPresented: $showAddTune) {
            AddTuneView()
        }
    }
}

// MARK: - Stubs (replaced by later tasks)

struct LibraryView: View {
    var body: some View { Text("Library") }
}

struct FlashcardsView: View {
    var body: some View { Text("Flashcards") }
}

struct AddTuneView: View {
    var body: some View { Text("Add Tune") }
}
