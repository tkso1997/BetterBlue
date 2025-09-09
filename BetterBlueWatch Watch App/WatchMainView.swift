//
//  WatchMainView.swift
//  BetterBlueWatch Watch App
//
//  Created by Mark Schmidt on 8/29/25.
//

import BetterBlueKit
import SwiftData
import SwiftUI

extension Color {
    var components: (red: Double, green: Double, blue: Double, opacity: Double) {
        #if canImport(UIKit)
            var r: CGFloat = 0
            var g: CGFloat = 0
            var b: CGFloat = 0
            var o: CGFloat = 0

            guard UIColor(self).getRed(&r, green: &g, blue: &b, alpha: &o) else {
                return (0, 0, 0, 1)
            }

            return (Double(r), Double(g), Double(b), Double(o))
        #else
            return (0, 0, 0, 1)
        #endif
    }
}

struct WatchMainView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(
        filter: #Predicate<BBVehicle> { vehicle in !vehicle.isHidden },
        sort: \BBVehicle.sortOrder,
    ) private var vehicles: [BBVehicle]
    @Query private var accounts: [BBAccount]

    var body: some View {
        NavigationStack {
            VStack {
                if vehicles.isEmpty {
                    WatchEmptyStateView()
                } else {
                    WatchVehicleCarouselView(vehicles: vehicles)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .fakeAccountConfigurationChanged)) { notification in
            guard let username = notification.object as? String else { return }

            print("🔄 [WatchMainView] Fake vehicle configuration changed for username: \(username)")
            Task {
                await refreshFakeAccount(username: username)
            }
        }
    }

    /// Refresh fake account when configuration changes
    private func refreshFakeAccount(username: String) async {
        // Find the fake account with the given username
        guard let fakeAccount = accounts.first(where: { $0.username == username && $0.brandEnum == .fake }) else {
            print("⚠️ [WatchMainView] No fake account found for username: \(username)")
            return
        }

        print("🔄 [WatchMainView] Refreshing fake account: \(username)")

        do {
            // Clear cached API data first
            fakeAccount.clearAPICache()

            // Reload vehicles with new configuration
            try await fakeAccount.initialize(modelContext: modelContext)
            try await fakeAccount.loadVehicles(modelContext: modelContext)

            print("✅ [WatchMainView] Successfully refreshed fake account: \(username)")

        } catch {
            print("❌ [WatchMainView] Failed to refresh fake account \(username): \(error)")
        }
    }
}

struct WatchEmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "car.fill")
                .font(.system(size: 40))
                .foregroundColor(.secondary)

            Text("No Vehicles")
                .font(.headline)
                .multilineTextAlignment(.center)

            Text("Add an account on your iPhone to get started")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }
}

struct WatchVehicleCarouselView: View {
    let vehicles: [BBVehicle]
    @State private var scrollOffset: Double = 0

    private var interpolatedGradient: [Color] {
        guard vehicles.count > 1 else {
            return vehicles.first?.watchBackgroundGradient ?? [Color.gray.opacity(0.1)]
        }

        // Clamp the scroll offset to valid vehicle indices
        let clampedOffset = max(0.0, min(Double(vehicles.count - 1), scrollOffset))

        let leftIndex = Int(floor(clampedOffset))
        let rightIndex = min(leftIndex + 1, vehicles.count - 1)
        let progress = clampedOffset - Double(leftIndex)

        // Ensure indices are valid
        guard leftIndex >= 0, leftIndex < vehicles.count, rightIndex >= 0, rightIndex < vehicles.count else {
            return vehicles.first?.watchBackgroundGradient ?? [Color.gray.opacity(0.1)]
        }

        let leftColors = vehicles[leftIndex].watchBackgroundGradient
        let rightColors = vehicles[rightIndex].watchBackgroundGradient

        // Interpolate between the two gradients
        return zip(leftColors, rightColors).map { leftColor, rightColor in
            Color(
                red: leftColor.components.red * (1 - progress) + rightColor.components.red * progress,
                green: leftColor.components.green * (1 - progress) + rightColor.components.green * progress,
                blue: leftColor.components.blue * (1 - progress) + rightColor.components.blue * progress,
                opacity: leftColor.components.opacity * (1 - progress) + rightColor.components.opacity * progress,
            )
        }
    }

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(Array(vehicles.enumerated()), id: \.element.id) { _, vehicle in
                    WatchVehicleView(vehicle: vehicle)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .onScrollGeometryChange(for: Double.self) { geometry in
            let pageWidth = geometry.containerSize.width
            let offset = geometry.contentOffset.x / pageWidth
            return offset
        } action: { offset, _ in
            scrollOffset = offset
        }
        .background(
            LinearGradient(
                gradient: Gradient(colors: interpolatedGradient),
                startPoint: .topLeading,
                endPoint: .bottomTrailing,
            ),
        )
    }
}

#Preview {
    WatchMainView()
}
