//
//  VehicleInfoComponents.swift
//  BetterBlue
//
//  Created by Mark Schmidt on 9/8/25.
//

import BetterBlueKit
import SwiftData
import SwiftUI

struct VehicleBasicInfoSection: View {
    let bbVehicle: BBVehicle
    @State private var appSettings = AppSettings.shared
    @Binding var showingCopiedMessage: Bool
    @Binding var showingCopiedMileageMessage: Bool

    var body: some View {
        Section("Basic Information") {
            HStack {
                Text("Original Name")
                Spacer()
                Text(bbVehicle.model)
                    .foregroundColor(.secondary)
            }

            HStack {
                Text("Brand")
                Spacer()
                if let account = bbVehicle.account {
                    Text(account.brandEnum.displayName)
                        .foregroundColor(.secondary)
                }
            }

            HStack {
                Text("VIN")
                Spacer()
                Text(bbVehicle.vin)
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                copyVINToClipboard()
            }

            HStack {
                Text("Mileage")
                Spacer()
                Text(bbVehicle.odometer.units.format(
                    bbVehicle.odometer.length,
                    to: appSettings.preferredDistanceUnit,
                ))
                .foregroundColor(.secondary)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                copyMileageToClipboard()
            }

            HStack {
                Text("Last Sync")
                Spacer()
                if let syncDate = bbVehicle.syncDate {
                    Text(formatSyncDate(syncDate))
                        .foregroundColor(.secondary)
                } else {
                    Text("Unknown")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func copyVINToClipboard() {
        UIPasteboard.general.string = bbVehicle.vin

        withAnimation(.easeInOut(duration: 0.3)) {
            showingCopiedMessage = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingCopiedMessage = false
            }
        }
    }

    private func copyMileageToClipboard() {
        let mileage = Int(bbVehicle.odometer.units.convert(
            bbVehicle.odometer.length,
            to: appSettings.preferredDistanceUnit,
        ))
        UIPasteboard.general.string = String(mileage)

        withAnimation(.easeInOut(duration: 0.3)) {
            showingCopiedMileageMessage = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                showingCopiedMileageMessage = false
            }
        }
    }

    private func formatSyncDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let timeFormatter = DateFormatter()
        timeFormatter.timeStyle = .short

        if calendar.isDateInToday(date) {
            return "Today at \(timeFormatter.string(from: date))"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday at \(timeFormatter.string(from: date))"
        } else {
            let dayFormatter = DateFormatter()
            dayFormatter.dateStyle = .medium
            dayFormatter.timeStyle = .short
            return dayFormatter.string(from: date)
        }
    }
}

struct VehicleWidgetConfigSection: View {
    let bbVehicle: BBVehicle

    var body: some View {
        Section {
            NavigationLink(destination: BackgroundSelectionView(bbVehicle: bbVehicle)) {
                HStack {
                    Text("Background")
                    Spacer()
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(LinearGradient(
                                gradient: Gradient(colors: bbVehicle.backgroundGradient),
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing,
                            ))
                            .frame(width: 24, height: 16)
                        Text(BBVehicle.availableBackgrounds.first(
                            where: { $0.name == bbVehicle.backgroundColorName },
                        )?.displayName ?? "Default")
                            .foregroundColor(.secondary)
                    }
                }
            }
        } header: {
            Text("Widget Appearance")
        }
    }
}
