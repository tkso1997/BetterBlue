//
//  SeatHeatControl.swift
//  BetterBlue
//
//  Created by Mark Schmidt on 8/25/25.
//

import SwiftUI

struct SeatHeatControl: View {
    @Binding var level: Int
    let position: String

    var imageText: String {
        level == 0 ? "carseat.\(position)" : "carseat.\(position).and.heat.waves"
    }

    var body: some View {
        Button {
            level = (level + 1) % 4 // Cycle through 0, 1, 2, 3
        } label: {
            HStack(spacing: 16) {
                // Large seat icon on the left
                Spacer()
                Image(systemName: imageText)
                    .font(.title)
                    .foregroundColor(level > 0 ? Color.orange : Color.secondary)
                    .frame(width: 24)

                // Text and heat indicator
                VStack(spacing: 4) {
                    Text(position.capitalized)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                    HStack(spacing: 4) {
                        ForEach(0 ..< 3, id: \.self) { index in
                            Rectangle()
                                .fill(level > index ? Color.orange : Color.gray.opacity(0.3))
                                .frame(width: 5, height: 12)
                                .cornerRadius(1.5)
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                level > 0 ?
                    Color.orange.opacity(0.1) :
                    Color.clear,
            )
            .animation(.easeInOut(duration: 0.2), value: level)
        }
        .buttonStyle(.plain)
    }
}
