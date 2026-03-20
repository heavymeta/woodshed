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
                        Label("Library", systemImage: "books.vertical")
                    }

                // Inert center slot so the FAB sits over the middle tab item
                Color.clear
                    .tag(Tab.library)
                    .tabItem { Label("Add", systemImage: "plus") }

                FlashcardsView()
                    .tag(Tab.flashcards)
                    .tabItem {
                        Label("Flashcards", systemImage: "rectangle.on.rectangle")
                    }
            }
            .tint(Color("AppPrimary"))

            // Raised circular Add button
            VStack(spacing: 4) {
                Button {
                    showAddTune = true
                } label: {
                    ZStack {
                        Circle()
                            .fill(Color("AppPrimary"))
                            .frame(width: 60, height: 60)
                            .shadow(
                                color: Color("AppPrimary").opacity(0.4),
                                radius: 10, y: 3
                            )
                        Image(systemName: "plus")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                }
                .offset(y: -8)

                Text("Add")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(Color("AppOnSurfaceVariant"))
                    .offset(y: -2)
            }
            .padding(.bottom, 4)
        }
        .sheet(isPresented: $showAddTune) {
            AddTuneView()
        }
    }
}
