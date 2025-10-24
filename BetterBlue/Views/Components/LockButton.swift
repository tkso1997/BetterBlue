//
//  LockButton.swift
//  BetterBlue
//
//  Created by Mark Schmidt on 8/25/25.
//

import BetterBlueKit
import SwiftData
import SwiftUI

struct LockButton: View {
    let bbVehicle: BBVehicle
    var transition: Namespace.ID?
    @Environment(\.modelContext) private var modelContext

    var isLocked: Bool {
        guard bbVehicle.modelContext != nil else {
            print(
                "⚠️ [LockButton] BBVehicle \(bbVehicle.vin) is detached from context"
            )
            return false
        }
        return bbVehicle.lockStatus == .locked
    }

    var body: some View {
        let unlock = MainVehicleAction(
            action: { statusUpdater in
                try await setLock(false, statusUpdater: statusUpdater)
            },
            icon: "lock.fill",
            label: "Unlock",
            inProgressLabel: "Unlocking",
            completedText: "Unlocked",
            color: .red
        )
        let lock = MainVehicleAction(
            action: { statusUpdater in
                try await setLock(true, statusUpdater: statusUpdater)
            },
            icon: "lock.open.fill",
            label: "Lock",
            inProgressLabel: "Locking",
            completedText: "Locked",
            color: .green
        )

        VehicleControlButton(
            actions: [unlock, lock],
            currentActionDeterminant: { isLocked ? unlock : lock },
            transition: transition,
            bbVehicle: bbVehicle
        )
    }

    @MainActor
    private func setLock(
        _ shouldLock: Bool,
        statusUpdater: @escaping @Sendable (String) -> Void
    ) async throws {
        guard let account = bbVehicle.account else {
            throw HyundaiKiaAPIError(message: "Account not found for vehicle")
        }

        let context = modelContext

        // Send command to vehicle
        if shouldLock {
            try await account.lockVehicle(bbVehicle, modelContext: context)
        } else {
            try await account.unlockVehicle(bbVehicle, modelContext: context)
        }

        // Command was successful! Update status optimistically
        // This provides immediate UI feedback instead of waiting 30+ seconds
        let newLockStatus: VehicleStatus.LockStatus = shouldLock ? .locked : .unlocked
        bbVehicle.lockStatus = newLockStatus

        print("✅ [LockButton] Lock command successful, status set to \(shouldLock ? "locked" : "unlocked")")

        // Refresh status in background to verify (non-blocking)
        Task {
            do {
                // Wait a few seconds before checking
                try await Task.sleep(nanoseconds: 5_000_000_000)

                // Fetch updated status from vehicle
                let status = try await account.fetchVehicleStatus(
                    for: bbVehicle,
                    modelContext: context
                )
                bbVehicle.updateStatus(with: status)

                print("✅ [LockButton] Background status refresh completed")
            } catch {
                print("⚠️ [LockButton] Background status refresh failed: \(error)")
                // Not critical - we trust the command was successful
            }
        }
    }
}
