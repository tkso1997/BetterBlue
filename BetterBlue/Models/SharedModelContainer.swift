//
//  SharedModelContainer.swift
//  BetterBlue
//
//  Created by Mark Schmidt on 9/4/25.
//

import Foundation
import SwiftData

func getSimulatorStoreURL() -> URL {
    // In simulator, use a fixed shared location to work around App Group container isolation
    let sharedSimulatorPath = "/tmp/BetterBlue_Shared"
    try? FileManager.default.createDirectory(
        atPath: sharedSimulatorPath,
        withIntermediateDirectories: true,
        attributes: nil,
    )
    return URL(fileURLWithPath: sharedSimulatorPath).appendingPathComponent("BetterBlue.sqlite")
}

func getAppGroupStoreURL() throws -> URL {
    let appGroupID = "group.com.betterblue.shared"
    if let appGroupURL = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) {
        return appGroupURL.appendingPathComponent("BetterBlue.sqlite")
    } else {
        print("⚠️ [BetterBlue] App Group container not accessible from current context")
        throw NSError(
            domain: "BetterBlue",
            code: 1001,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Vehicle data not accessible. Please open the BetterBlue app first to sync your vehicles.",
                NSLocalizedRecoverySuggestionErrorKey:
                    "Open the BetterBlue app and try again."
            ],
        )
    }
}

/// Creates a shared ModelContainer for use across main app, widget, and watch app
func createSharedModelContainer() throws -> ModelContainer {
    let schema = Schema([
        BBAccount.self,
        BBVehicle.self,
        BBHTTPLog.self,
        ClimatePreset.self
    ], version: .init(1, 0, 6))

    let storeURL: URL

    #if targetEnvironment(simulator)
        storeURL = getSimulatorStoreURL()
        print("📱 [BetterBlue] Using shared temp storage at: \(storeURL)")
    #else
        // On device, try App Group container first, with better error handling
        storeURL = try getAppGroupStoreURL()
        print("✅ [BetterBlue] Using App Group container: \(storeURL)")
    #endif

    do {
        let modelConfiguration = ModelConfiguration(url: storeURL, cloudKitDatabase: .automatic)
        return try ModelContainer(for: schema, configurations: [modelConfiguration])
    } catch {
        print("❌ [BetterBlue] Failed to create ModelContainer: \(error)")
        throw NSError(
            domain: "BetterBlue",
            code: 1002,
            userInfo: [
                NSLocalizedDescriptionKey:
                    "Failed to create data storage",
                NSLocalizedRecoverySuggestionErrorKey:
                    "Try restarting the app. If the problem persists, contact support."
            ],
        )
    }
}
