// FiddleTunes/Views/Flashcards/FlashcardsView.swift
import SwiftUI
import SwiftData

struct FlashcardsView: View {
    @Query private var tunes: [Tune]
    @EnvironmentObject var audio: AudioService
    @Environment(\.modelContext) private var modelContext

    @State private var deck: [Tune] = []
    @State private var dragOffset: CGSize = .zero
    /// 0 = cards at rest, 1 = next card fully risen to top position.
    /// Driven continuously by drag, then completed on swipe commit.
    @State private var riseProgress: CGFloat = 0

    var body: some View {
        NavigationStack {
            ZStack {
                Color("AppSurface").ignoresSafeArea()

                if tunes.isEmpty {
                    emptyLibraryState
                } else if deck.isEmpty {
                    allDoneState
                } else {
                    GeometryReader { geo in
                        let cardWidth  = geo.size.width - 56
                        let cardHeight = geo.size.height * 0.72
                        VStack(spacing: 0) {
                            Spacer()
                            cardStack(width: cardWidth, height: cardHeight)
                                .offset(y: -20)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationBarHidden(true)
            .onAppear { rebuildDeck() }
        }
    }

    // MARK: - Card Stack

    private func cardStack(width: CGFloat, height: CGFloat) -> some View {
        ZStack {
            ForEach(Array(deck.prefix(3).enumerated().reversed()), id: \.element.id) { index, tune in
                singleCard(tune: tune, index: index, width: width, height: height)
            }
        }
    }

    /// Renders every card — top and background — through the same view path so SwiftUI
    /// preserves view identity across swipes instead of destroying and recreating views.
    private func singleCard(tune: Tune, index: Int, width: CGFloat, height: CGFloat) -> some View {
        let isTop     = index == 0
        let rotations: [Double] = [0, -4.0, 5.5]
        let rise: CGFloat = index == 1 ? riseProgress : (index == 2 ? riseProgress * 0.5 : 0)

        let scale      = isTop ? 1.0 : 1.0 - CGFloat(index) * 0.06 + 0.06 * rise
        let rotation   = isTop ? Double(dragOffset.width) / 20.0 : rotations[index] * Double(1.0 - rise)
        let cardOffset = isTop ? dragOffset : CGSize(width: 0, height: CGFloat(index) * 14 * (1.0 - rise))
        let opacity    = isTop ? 1.0 : 1.0 - Double(index) * 0.12 + 0.12 * Double(rise)

        return FlashcardCardView(tune: tune, index: cardNumber(for: tune))
            .frame(width: width, height: height)
            .overlay { if isTop { swipeLabel } }
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .offset(cardOffset)
            .opacity(opacity)
            .zIndex(Double(3 - index))
            .allowsHitTesting(isTop)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        dragOffset = value.translation
                        riseProgress = min(abs(value.translation.width) / 80.0, 1.0)
                    }
                    .onEnded { value in
                        if value.translation.width > 80 {
                            swipe(tune: tune, known: true)
                        } else if value.translation.width < -80 {
                            swipe(tune: tune, known: false)
                        } else {
                            withAnimation(.spring(response: 0.4, dampingFraction: 0.75)) {
                                dragOffset = .zero
                                riseProgress = 0
                            }
                        }
                    }
            )
    }

    private func cardNumber(for tune: Tune) -> Int {
        (tunes.firstIndex(where: { $0.id == tune.id }) ?? 0) + 1
    }

    @ViewBuilder
    private var swipeLabel: some View {
        let offset = dragOffset.width
        if abs(offset) > 20 {
            HStack {
                if offset < 0 {
                    Text("DON'T KNOW")
                        .font(.system(size: 18))
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
                        .font(.system(size: 18))
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
        HStack(spacing: 32) {
            Button {
                if let tune = deck.first { swipe(tune: tune, known: false) }
            } label: {
                VStack(spacing: 6) {
                    ZStack {
                        Circle().fill(.red).frame(width: 56, height: 56)
                        Image(systemName: "xmark").font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                    }
                    Text("Don't Know").font(.system(size: 12)).foregroundStyle(Color("AppOnSurfaceVariant"))
                }
            }

            Button {
                if let tune = deck.first { swipe(tune: tune, known: true) }
            } label: {
                VStack(spacing: 6) {
                    ZStack {
                        Circle().fill(.green).frame(width: 56, height: 56)
                        Image(systemName: "checkmark").font(.system(size: 22, weight: .semibold)).foregroundStyle(.white)
                    }
                    Text("Know It").font(.system(size: 12)).foregroundStyle(Color("AppOnSurfaceVariant"))
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
                .font(.system(size: 16, design: .serif))
                .foregroundStyle(Color("AppOnSurface"))
                .multilineTextAlignment(.center)
        }
    }

    private var allDoneState: some View {
        VStack(spacing: 16) {
            Text("All done!")
                .font(.system(size: 28, weight: .bold, design: .serif))
                .foregroundStyle(Color("AppOnSurface"))
            Text("Great practice session.")
                .font(.system(size: 16))
                .foregroundStyle(Color("AppOnSurfaceVariant"))
            Button("Start Over") { rebuildDeck() }
                .font(.system(size: 16))
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
        if known { tune.knownCount += 1 } else { tune.unknownCount += 1 }

        let exitX: CGFloat = known ? 650 : -650
        let exitY = dragOffset.height - 30

        // Complete the background rise while the top card exits.
        withAnimation(.easeOut(duration: 0.22)) { riseProgress = 1.0 }
        withAnimation(.easeOut(duration: 0.25)) {
            dragOffset = CGSize(width: exitX, height: exitY)
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            // Batch deck removal + dragOffset reset in one render pass so the
            // exiting card is never seen snapping back to center.
            deck.removeFirst()
            dragOffset = .zero
            // Animate the third card drifting back to its rest position.
            withAnimation(.spring(response: 0.45, dampingFraction: 0.9)) {
                riseProgress = 0
            }
        }
    }

    private func rebuildDeck() {
        let items = tunes.map { (id: $0.id.hashValue, known: $0.knownCount, unknown: $0.unknownCount) }
        let sorted = FlashcardWeighting.sort(items)
        let idOrder = sorted.map { $0.id }
        deck = idOrder.compactMap { id in tunes.first { $0.id.hashValue == id } }
    }
}
