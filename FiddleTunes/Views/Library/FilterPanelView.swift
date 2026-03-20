// FiddleTunes/Views/Library/FilterPanelView.swift
import SwiftUI

struct FilterPanelView: View {
    @Binding var selectedGenre: String?
    @Binding var selectedType: String?
    @Binding var selectedKey: String?
    @Binding var selectedTuning: String?

    private let genres  = ["Old Time", "Scandi", "Celtic"]
    private let types   = ["Reel", "Jig", "Waltz", "Breakdown", "Hornpipe", "Other"]
    private let keys    = ["D Major", "G Major", "A Major", "E Major", "A minor", "D minor", "G minor", "Other"]
    private let tunings = ["Standard", "Cross-G", "AEAE", "Other"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            chipRow(label: "Genre",  options: genres,  selection: $selectedGenre)
            chipRow(label: "Type",   options: types,   selection: $selectedType)
            chipRow(label: "Key",    options: keys,    selection: $selectedKey)
            chipRow(label: "Tuning", options: tunings, selection: $selectedTuning)
        }
        .padding(.vertical, 12)
        .background(Color("AppSurfaceContainer"))
    }

    @ViewBuilder
    private func chipRow(label: String, options: [String], selection: Binding<String?>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.custom("Manrope", size: 11))
                .fontWeight(.semibold)
                .foregroundStyle(Color("AppOnSurfaceVariant"))
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(options, id: \.self) { option in
                        chip(option, isSelected: selection.wrappedValue == option) {
                            if selection.wrappedValue == option {
                                selection.wrappedValue = nil  // deselect
                            } else {
                                selection.wrappedValue = option
                            }
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func chip(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.custom("Manrope", size: 13))
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? Color.white : Color("AppOnSurface"))
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isSelected ? Color("AppPrimary") : Color("AppSurfaceContainerHigh"))
                .clipShape(Capsule())
        }
    }
}
