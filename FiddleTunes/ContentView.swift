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
                    .toolbar(.hidden, for: .tabBar)

                FlashcardsView()
                    .tag(Tab.flashcards)
                    .toolbar(.hidden, for: .tabBar)
            }

            customTabBar
        }
        .sheet(isPresented: $showAddTune) {
            AddTuneView()
        }
    }

    // MARK: - Custom Tab Bar

    private var customTabBar: some View {
        HStack(spacing: 0) {
            tabButton(title: "Library", systemImage: "books.vertical", tab: .library)

            // FAB — center
            Button {
                showAddTune = true
            } label: {
                ZStack {
                    Circle()
                        .fill(Color("AppPrimary"))
                        .frame(width: 52, height: 52)
                        .shadow(color: Color("AppPrimary").opacity(0.35), radius: 8, y: 2)
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 80)

            tabButton(title: "Flashcards", systemImage: "rectangle.on.rectangle", tab: .flashcards)
        }
        .padding(.horizontal, 24)
        .frame(height: 56)
        .background(
            Color("AppSurface")
                .shadow(color: .black.opacity(0.08), radius: 6, y: -1)
                .ignoresSafeArea(edges: .bottom)
        )
    }

    private func tabButton(title: String, systemImage: String, tab: Tab) -> some View {
        Button {
            selectedTab = tab
        } label: {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 22))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .padding(.top, 6)
            .foregroundStyle(
                selectedTab == tab
                    ? Color("AppPrimary")
                    : Color("AppOnSurfaceVariant").opacity(0.45)
            )
        }
        .frame(maxWidth: .infinity)
    }
}
