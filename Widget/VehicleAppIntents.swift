//
//  VehicleAppIntents.swift
//  BetterBlueWidget
//
//  Created by Mark Schmidt on 8/29/25.
//

import AppIntents
import BetterBlueKit
import SwiftData
import UserNotifications
import WidgetKit

// MARK: - Vehicle Action Intents

struct LockVehicleIntent: AppIntent {
    static var title: LocalizedStringResource = "Lock Vehicle"
    static var description = IntentDescription("Lock your vehicle")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Vehicle", description: "The vehicle to lock")
    var vehicle: VehicleEntity?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            guard let vehicle else {
                throw NSError(
                    domain: "com.betterblue.app",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "No vehicle provided"],
                )
            }
            let targetVin = vehicle.vin
            let vehicleName = vehicle.displayName

            try await performVehicleActionWithVin(targetVin) { bbVehicle, account, context in
                try await account.lockVehicle(bbVehicle, modelContext: context)
            }

            await sendNotification(title: "Lock Request Sent", body: "Command sent to \(vehicleName)")

            WidgetCenter.shared.reloadTimelines(ofKind: "BetterBlueWidget")
            return .result(dialog: "Lock request sent to \(vehicleName)")
        } catch {
            throw error
        }
    }
}

struct UnlockVehicleIntent: AppIntent {
    static var title: LocalizedStringResource = "Unlock Vehicle"
    static var description = IntentDescription("Unlock your vehicle")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Vehicle", description: "The vehicle to unlock")
    var vehicle: VehicleEntity?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            guard let vehicle else {
                throw NSError(
                    domain: "com.betterblue.app",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "No vehicle provided"],
                )
            }
            let targetVin = vehicle.vin
            let vehicleName = vehicle.displayName

            try await performVehicleActionWithVin(targetVin) { bbVehicle, account, context in
                try await account.unlockVehicle(bbVehicle, modelContext: context)
            }

            // Send local notification for feedback
            await sendNotification(title: "Unlock Request Sent", body: "Command sent to \(vehicleName)")

            WidgetCenter.shared.reloadTimelines(ofKind: "BetterBlueWidget")
            return .result(dialog: "Unlock request sent to \(vehicleName)")
        } catch {
            throw error
        }
    }
}

struct StartClimateIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Climate Control"
    static var description = IntentDescription("Start climate control for your vehicle")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Vehicle", description: "The vehicle to start climate control")
    var vehicle: VehicleEntity?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            guard let vehicle else {
                throw NSError(
                    domain: "com.betterblue.app",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "No vehicle provided"],
                )
            }
            let targetVin = vehicle.vin
            let vehicleName = vehicle.displayName

            try await performVehicleActionWithVin(targetVin) { bbVehicle, account, context in
                try await account.startClimate(bbVehicle, modelContext: context)
            }

            await sendNotification(title: "Climate Start Request Sent", body: "Command sent to \(vehicleName)")

            WidgetCenter.shared.reloadTimelines(ofKind: "BetterBlueWidget")
            return .result(dialog: "Climate start request sent to \(vehicleName)")
        } catch {
            throw error
        }
    }
}

struct StopClimateIntent: AppIntent {
    static var title: LocalizedStringResource = "Stop Climate Control"
    static var description = IntentDescription("Stop climate control for your vehicle")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Vehicle", description: "The vehicle to stop climate control")
    var vehicle: VehicleEntity?

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        do {
            guard let vehicle else {
                throw NSError(
                    domain: "com.betterblue.app",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: "No vehicle provided"],
                )
            }
            let targetVin = vehicle.vin
            let vehicleName = vehicle.displayName

            try await performVehicleActionWithVin(targetVin) { bbVehicle, account, context in
                try await account.stopClimate(bbVehicle, modelContext: context)
            }

            await sendNotification(title: "Climate Stop Request Sent", body: "Command sent to \(vehicleName)")

            WidgetCenter.shared.reloadTimelines(ofKind: "BetterBlueWidget")
            return .result(dialog: "Climate stop request sent to \(vehicleName)")
        } catch {
            throw error
        }
    }
}

// MARK: - Siri Shortcut Intents

struct RefreshVehicleStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Vehicle Status"
    static var description = IntentDescription("Refresh the status of your vehicle")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Vehicle", description: "The vehicle to refresh")
    var vehicle: VehicleEntity

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        let modelContainer = try createSharedModelContainer()
        let context = ModelContext(modelContainer)

        let vehicles = try context.fetch(FetchDescriptor<BBVehicle>())

        guard let bbVehicle = vehicles.first(where: { $0.vin == vehicle.vin }),
              let account = bbVehicle.account
        else {
            throw IntentError.vehicleNotFound
        }

        try await account.fetchAndUpdateVehicleStatus(for: bbVehicle, modelContext: context)

        let unit = AppSettings.shared.preferredDistanceUnit
        let updatedVehicle = VehicleEntity(from: bbVehicle, with: unit)

        WidgetCenter.shared.reloadTimelines(ofKind: "BetterBlueWidget")

        return .result(dialog: "\(updatedVehicle.displayName) status updated. \(updatedVehicle.rangeText)")
    }
}

struct GetVehicleStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Vehicle Status"
    static var description = IntentDescription("Get the current status of your vehicle")
    static var openAppWhenRun: Bool = false

    @Parameter(title: "Vehicle", description: "The vehicle to check")
    var vehicle: VehicleEntity

    init() {}

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let lockStatus = vehicle.vin.contains("locked") ? "locked" : "unlocked" // This would need actual status
        let rangeInfo = vehicle.rangeText

        return .result(dialog: "\(vehicle.displayName) is \(lockStatus). Range: \(rangeInfo)")
    }
}

// MARK: - Helper Functions

@MainActor
private func performVehicleActionWithVin(
    _ vin: String,
    action: @escaping (BBVehicle, BBAccount, ModelContext) async throws -> Void,
) async throws {
    let modelContainer = try createSharedModelContainer()
    let context = ModelContext(modelContainer)

    let vehicles = try context.fetch(FetchDescriptor<BBVehicle>())

    guard let vehicle = vehicles.first(where: { $0.vin == vin }),
          let account = vehicle.account
    else {
        throw IntentError.vehicleNotFound
    }

    try await action(vehicle, account, context)
}

public func refreshWidgets() {
    WidgetCenter.shared.reloadAllTimelines()
}

private func sendNotification(title: String, body: String) async {
    #if canImport(UserNotifications) && !os(watchOS)
        // Check if notifications are enabled in settings
        let notificationsEnabled = await MainActor.run {
            AppSettings.shared.notificationsEnabled
        }

        guard notificationsEnabled else {
            print("ℹ️ [Notifications] Notifications disabled in settings")
            return
        }

        do {
            let center = UNUserNotificationCenter.current()

            // Check permission first
            let notificationSettings = await center.notificationSettings()
            guard notificationSettings.authorizationStatus == .authorized else {
                print("❌ [Notifications] Not authorized")
                return
            }

            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            content.sound = .default

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil,
            )

            try await center.add(request)
            print("✅ [Notifications] Sent: \(title)")
        } catch {
            print("❌ [Notifications] Failed to send: \(error)")
        }
    #else
        print("ℹ️ [Notifications] Notifications not available on this platform")
    #endif
}

// MARK: - Intent Errors

enum IntentError: Swift.Error, LocalizedError {
    case vehicleNotFound
    case accountNotFound
    case refreshFailed(String)

    var errorDescription: String? {
        switch self {
        case .vehicleNotFound:
            "Vehicle not found"
        case .accountNotFound:
            "Account not found for vehicle"
        case let .refreshFailed(message):
            "Failed to refresh vehicle status: \(message)"
        }
    }
}
