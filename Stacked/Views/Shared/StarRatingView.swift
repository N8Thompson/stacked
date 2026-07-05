//
//  StarRatingView.swift
//  Stacked
//
//  Personal 0–5 star rating with half-star support on repeat tap.
//

import SwiftUI

struct StarRatingView: View {
    @Binding var rating: Double
    var isEditable: Bool = true
    var maxRating: Int = 5

    var body: some View {
        HStack(spacing: 4) {
            ForEach(1...maxRating, id: \.self) { star in
                starButton(star)
            }
            if !isEditable, rating == 0 {
                Text("Not rated")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func starButton(_ star: Int) -> some View {
        let imageName = starImageName(for: star)
        if isEditable {
            Button {
                toggleRating(for: star)
            } label: {
                Image(systemName: imageName)
                    .font(.title2)
                    .foregroundStyle(rating > 0 ? Color.yellow : Color.secondary.opacity(0.35))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(star) star\(star == 1 ? "" : "s")")
        } else {
            Image(systemName: imageName)
                .font(.title2)
                .foregroundStyle(rating > 0 ? Color.yellow : Color.secondary.opacity(0.35))
        }
    }

    private func starImageName(for star: Int) -> String {
        let value = Double(star)
        if rating >= value {
            return "star.fill"
        }
        if rating >= value - 0.5 {
            return "star.leadinghalf.filled"
        }
        return "star"
    }

    private func toggleRating(for star: Int) {
        let value = Double(star)
        if rating == value {
            rating = value - 0.5
        } else if rating == value - 0.5 {
            rating = star == 1 ? 0 : value - 1
        } else {
            rating = value
        }
    }
}
