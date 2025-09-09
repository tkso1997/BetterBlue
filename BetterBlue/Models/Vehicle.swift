//
//  Vehicle.swift
//  BetterBlue
//
//  Created by Mark Schmidt on 9/6/25.
//

import BetterBlueKit
import Foundation
import MapKit
import SwiftData
import SwiftUI

@Model
class BBVehicle {
    var id: UUID = UUID()
    var vin: String = ""

    // Vehicle fields (all required)
    var regId: String = ""
    var model: String = ""
    var accountId: UUID = UUID()
    var isElectric: Bool = false
    var generation: Int = 0
    var odometer: Distance = Distance(length: 0, units: .miles)

    // VehicleStatus fields (all optional since status might not be fetched)
    var lastUpdated: Date?
    var syncDate: Date?
    var gasRange: VehicleStatus.FuelRange?
    var evStatus: VehicleStatus.EVStatus?
    var location: VehicleStatus.Location?
    var lockStatus: VehicleStatus.LockStatus?
    var climateStatus: VehicleStatus.ClimateStatus?

    // Custom name and visibility (kept separate for easier queries)
    var customName: String?
    var isHidden: Bool = false
    var sortOrder: Int = 0
    var backgroundColorName: String = "default"
    var watchBackgroundColorName: String = "default"
    var debugConfiguration: BBDebugConfiguration?

    // Optional vehicle key for Kia vehicles
    @Transient var vehicleKey: String?

    @Relationship(inverse: \BBAccount.vehicles) var account: BBAccount?
    @Relationship(deleteRule: .cascade) var climatePresets: [ClimatePreset]? = []

    var safeClimatePresets: [ClimatePreset] {
        climatePresets ?? []
    }

    init(from vehicle: Vehicle, backgroundColorName: String? = nil) {
        id = UUID()
        vin = vehicle.vin
        regId = vehicle.regId
        model = vehicle.model
        accountId = vehicle.accountId
        isElectric = vehicle.isElectric
        generation = vehicle.generation
        odometer = vehicle.odometer

        // Initialize status fields as nil
        lastUpdated = nil
        syncDate = nil
        gasRange = nil
        evStatus = nil
        location = nil
        lockStatus = nil
        climateStatus = nil

        customName = nil
        isHidden = false
        vehicleKey = vehicle.vehicleKey
        if let color = backgroundColorName {
            self.backgroundColorName = color
        }
    }
}

// MARK: - Status Management

extension BBVehicle {
    @MainActor
    func updateStatus(with status: VehicleStatus) {
        // Wake up any waiting status change tasks (cancel them so they can restart immediately)
        wakeUpStatusWaiters()

        // Update all fields with the merged status
        lastUpdated = status.lastUpdated
        syncDate = status.syncDate

        // if gas range / ev status are empty, keep our existing values
        if let gasRange = status.gasRange {
            self.gasRange = gasRange
        }
        if let evStatus = status.evStatus {
            self.evStatus = evStatus
        }
        location = status.location
        lockStatus = status.lockStatus
        climateStatus = status.climateStatus
        if let odometer = status.odometer {
            self.odometer = odometer
        }
    }

    // MARK: - Status Change Waiting

    // Simple actor to manage wake-up continuations
    private actor StatusWaitingManager {
        private var wakeUpContinuations: [UUID: CheckedContinuation<Void, Never>] = [:]

        func setWakeUpContinuation(
            for vehicleId: UUID,
            continuation: CheckedContinuation<Void, Never>,
        ) {
            wakeUpContinuations[vehicleId] = continuation
        }

        func wakeUp(vehicleId: UUID) -> Bool {
            if let continuation = wakeUpContinuations.removeValue(forKey: vehicleId) {
                continuation.resume()
                return true
            }
            return false
        }

        func clearWakeUp(for vehicleId: UUID) {
            if let continuation = wakeUpContinuations.removeValue(forKey: vehicleId) {
                // Resume the continuation to prevent leak
                continuation.resume()
            }
        }
    }

    private static let statusWaitingManager = StatusWaitingManager()

    @MainActor
    func waitForStatusChange(
        modelContext: ModelContext,
        condition: @escaping @Sendable (VehicleStatus) -> Bool,
        statusMessageUpdater: (@Sendable (String) -> Void)? = nil,
        maxAttempts: Int = 3,
        initialDelaySeconds: Int = 10,
        retryDelaySeconds: Int = 10,
    ) async throws {
        // Initial delay to allow command to process
        statusMessageUpdater?("Command sent")
        try await interruptibleSleep(seconds: initialDelaySeconds)

        var currentAttempt = 0

        while currentAttempt < maxAttempts {
            try Task.checkCancellation()

            guard let account else {
                throw HyundaiKiaAPIError(message: "Account not found for vehicle")
            }

            let updatedStatus = try await account.fetchVehicleStatus(
                for: self,
                modelContext: modelContext,
            )

            // Update the vehicle's status
            updateStatus(with: updatedStatus)

            if condition(updatedStatus) {
                print(
                    "✅ [BBVehicle] Status condition met for vehicle \(displayName)",
                )
                return
            }

            currentAttempt += 1
            if currentAttempt < maxAttempts {
                statusMessageUpdater?(
                    "Waiting for vehicle (\(currentAttempt)/\(maxAttempts))"
                )
                try await interruptibleSleep(seconds: retryDelaySeconds)
            }
        }

        throw HyundaiKiaAPIError(
            message: "Status change condition not met after \(maxAttempts) attempts",
        )
    }

    @MainActor
    private func interruptibleSleep(seconds: Int) async throws {
        let vehicleId = id

        // Ensure any existing continuation is cleared before setting up a new one
        await Self.statusWaitingManager.clearWakeUp(for: vehicleId)

        try await withThrowingTaskGroup(of: Bool.self) { group in
            // Add timer task
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000)
                return false // Timer completed normally
            }

            // Add wake-up task
            group.addTask {
                await withCheckedContinuation { continuation in
                    Task {
                        await Self.statusWaitingManager.setWakeUpContinuation(
                            for: vehicleId,
                            continuation: continuation,
                        )
                    }
                }
                return true // Wake-up was triggered
            }

            // Wait for the first task to complete
            let wasWakeUp = try await group.next() ?? false

            // Cancel remaining tasks and ensure continuation cleanup
            group.cancelAll()
            await Self.statusWaitingManager.clearWakeUp(for: vehicleId)

            if wasWakeUp {
                print(
                    "⏰ [BBVehicle] Sleep interrupted by wake-up for vehicle \(self.displayName)",
                )
            }
        }
    }

    @MainActor
    func wakeUpStatusWaiters() {
        Task {
            let wasAwakened = await Self.statusWaitingManager.wakeUp(
                vehicleId: self.id,
            )
            if wasAwakened {
                print(
                    "🔔 [BBVehicle] Waking up status waiter for vehicle \(self.displayName)",
                )
            }
        }
    }

    @MainActor
    func clearPendingStatusWaiters() async {
        await Self.statusWaitingManager.clearWakeUp(for: id)
        print(
            "🧹 [BBVehicle] Cleared pending status waiters for vehicle \(displayName)",
        )
    }
}

// MARK: - UI and Display

extension BBVehicle {
    var displayName: String {
        customName?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false ?
            customName! : model
    }

    struct BackgroundOption {
        let name: String
        let displayName: String
        let gradient: [Color]
    }

    static let availableBackgrounds: [BackgroundOption] = [
        BackgroundOption(
            name: "default",
            displayName: "Default",
            gradient: [Color.gray.opacity(0.1), Color.gray.opacity(0.05)],
        ),
        BackgroundOption(
            name: "black",
            displayName: "Black",
            gradient: [Color.black.opacity(0.8), Color.black.opacity(0.4)],
        ),
        BackgroundOption(
            name: "gray",
            displayName: "Gray",
            gradient: [Color.gray.opacity(0.6), Color.gray.opacity(0.3)],
        ),
        BackgroundOption(
            name: "silver",
            displayName: "Silver",
            gradient: [
                Color(red: 0.75, green: 0.75, blue: 0.75),
                Color(red: 0.9, green: 0.9, blue: 0.9)
            ],
        ),
        BackgroundOption(
            name: "darkBlue",
            displayName: "Dark Blue",
            gradient: [Color.blue.opacity(0.7), Color.blue.opacity(0.4)],
        ),
        BackgroundOption(
            name: "lightBlue",
            displayName: "Light Blue",
            gradient: [Color.blue.opacity(0.4), Color.blue.opacity(0.2)],
        ),
        BackgroundOption(
            name: "darkGreen",
            displayName: "Dark Green",
            gradient: [Color.green.opacity(0.7), Color.green.opacity(0.4)],
        ),
        BackgroundOption(
            name: "red",
            displayName: "Red",
            gradient: [Color.red.opacity(0.6), Color.red.opacity(0.3)],
        ),
        BackgroundOption(
            name: "white",
            displayName: "White",
            gradient: [Color.white.opacity(0.9), Color.white.opacity(0.6)],
        )
    ]

    var backgroundGradient: [Color] {
        guard let background = Self.availableBackgrounds.first(where: {
            $0.name == backgroundColorName
        }) else {
            return Self.availableBackgrounds[0].gradient
        }
        return background.gradient
    }

    var watchBackgroundGradient: [Color] {
        guard let background = Self.availableBackgrounds.first(where: {
            $0.name == watchBackgroundColorName
        }) else {
            return Self.availableBackgrounds[0].gradient
        }
        return background.gradient
    }
}

// MARK: - Utility Methods

extension BBVehicle {
    var coordinate: CLLocationCoordinate2D? {
        guard let location else { return nil }
        return CLLocationCoordinate2D(
            latitude: location.latitude,
            longitude: location.longitude,
        )
    }

    func toVehicle() -> Vehicle {
        Vehicle(
            vin: vin,
            regId: regId,
            model: model,
            accountId: accountId,
            isElectric: isElectric,
            generation: generation,
            odometer: odometer,
            vehicleKey: vehicleKey,
        )
    }
}
