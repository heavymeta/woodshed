// FiddleTunes/Views/Flashcards/FlashcardsView.swift
import SwiftUI
import SwiftData

struct FlashcardsView: View {
    @Query private var tunes: [Tune]
    @EnvironmentObject var audio: AudioService
    @Environment(\.modelContext) private var modelContext

    @State private var deck: [Tune] = []
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppSurface").ignoresSafeArea()

                if tunes.isEmpty {
                    emptyLibraryState
                } else if deck.isEmpty {
                    allDoneState
                } else {
                    VStack(spacing: 0) {
                        Spacer()
                        cardStack
                        Spacer()
                        actionButtons
                            .padding(.bottom, 32)
                    }
                }
            }
            .navigationTitle("Flashcards")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear { rebuildDeck() }
        }
    }

    // MARK: - Card Stack

    private var cardStack: some View {
        ZStack {
            ForEach(Array(deck.prefix(3).enumerated().reversed()), id: \.element.id) { index, tune in
                if index > 0 {
                    FlashcardCardView(tune: tune)
                        .scaleEffect(1.0 - CGFloat(index) * 0.04)
                        .offset(y: CGFloat(index) * 8)
                        .opacity(1.0 - Double(index) * 0.2)
                }
            }
            if let topTune = deck.first {
                topCard(topTune)
            }
        }
        .padding(.horizontal, 24)
    }

    private func topCard(_ tune: Tune) -> some View {
        let rotation = dragOffset.width / 20.0

        return FlashcardCardView(tune: tune)
            .overlay(swipeLabel)
            .rotationEffect(.degrees(rotation))
            .offset(dragOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in dragOffset = value.translation }
                    .onEnded { value in
                        if value.translation.width > 80 {
                            swipe(tune: tune, known: true)
                        } else if value.translation.width < -80 {
                            swipe(tune: tune, known: false)
                        } else {
                            withAnimation(.spring()) { dragOffset = .zero }
                        }
                    }
            )
            .animation(.interactiveSpring(), value: dragOffset)
    }

    @ViewBuilder
    private var swipeLabel: some View {
        let offset = dragOffset.width
        if abs(offset) > 20 {
            HStack {
                if offset < 0 {
                    Text("DON'T KNOW")
                        .font(.custom("Manrope", size: 18))
                        .fontWeight(.bold)
                        .foregroundStyle(.red)
                        .padding(10)
                        .background(.red.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .rotationEffect(.degrees(-15))
                        .opacity(Double(min(abs(offset) / 80, 1.0)))
                    Spacer()
                } else {
                    Spacer()
                    Text("KNOW IT")
                        .font(.custom("Manrope", size: 18))
                        .fontWeight(.bold)
                        .foregroundStyle(.green)
                        .padding(10)
                        .background(.green.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .rotationEffect(.degrees(15))
                        .opacity(Double(min(abs(offset) / 80, 1.0)))
                }
            }
            .padding(16)
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 48) {
            Button {
                if let tune = deck.first { swipe(tune: tune, known: false) }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.red)
                    Text("Don't Know")
                        .font(.custom("Manrope", size: 12))
                        .foregroundStyle(Color("AppOnSurfaceVariant"))
                }
            }

            Button {
                if let tune = deck.first { swipe(tune: tune, known: true) }
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.green)
                    Text("Know It")
                        .font(.custom("Manrope", size: 12))
                        .foregroundStyle(Color("AppOnSurfaceVariant"))
                }
            }
        }
    }

    // MARK: - Empty States

    private var emptyLibraryState: some View {
        VStack(spacing: 12) {
            Image(systemName: "music.note.list")
                .font(.system(size: 48))
                .foregroundStyle(Color("AppOnSurfaceVariant"))
            Text("Add tunes to your library\nto start practicing.")
                .font(.custom("NotoSerif-Regular", size: 16))
                .foregroundStyle(Color("AppOnSurface"))
                .multilineTextAlignment(.center)
        }
    }

    private var allDoneState: some View {
        VStack(spacing: 16) {
            Text("All done!")
                .font(.custom("NotoSerif-Bold", size: 28))
                .foregroundStyle(Color("AppOnSurface"))
            Text("Great practice session.")
                .font(.custom("Manrope", size: 16))
                .foregroundStyle(Color("AppOnSurfaceVariant"))
            Button("Start Over") { rebuildDeck() }
                .font(.custom("Manrope", size: 16))
                .fontWeight(.semibold)
                .foregroundStyle(Color("AppPrimary"))
                .padding(.horizontal, 24)
                .padding(.vertical, 10)
                .background(Color("AppPrimaryContainer"))
                .clipShape(Capsule())
        }
    }

    // MARK: - Logic

    private func swipe(tune: Tune, known: Bool) {
        audio.stop()
        if known {
            tune.knownCount += 1
        } else {
            tune.unknownCount += 1
        }
        withAnimation(.easeInOut(duration: 0.25)) {
            dragOffset = CGSize(width: known ? 500 : -500, height: 0)
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            deck.removeFirst()
            dragOffset = .zero
        }
    }

    private func rebuildDeck() {
        let items = tunes.map { (id: $0.id.hashValue, known: $0.knownCount, unknown: $0.unknownCount) }
        let sorted = FlashcardWeighting.sort(items)
        let idOrder = sorted.map { $0.id }
        deck = idOrder.compactMap { id in tunes.first { $0.id.hashValue == id } }
    }
}
