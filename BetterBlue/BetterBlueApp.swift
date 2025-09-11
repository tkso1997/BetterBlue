//
//  BetterBlueApp.swift
//  BetterBlue
//
//  Created by Mark Schmidt on 6/12/25.
//

import AppIntents
import BetterBlueKit
import SwiftData
import SwiftUI
import UserNotifications

extension Notification.Name {
    static let fakeAccountConfigurationChanged = Notification.Name("FakeAccountConfigurationChanged")
    static let selectVehicle = Notification.Name("SelectVehicle")
}

@main
struct BetterBlueApp: App {
    var sharedModelContainer: ModelContainer = {
        do {
            let container = try createSharedModelContainer()

            // Configure the HTTP log sink manager with auto-detected device type
            let deviceType = HTTPLogSinkManager.detectMainAppDeviceType()
            HTTPLogSinkManager.shared.configure(with: container, deviceType: deviceType)

            return container
        } catch {
            print("💥 [MainApp] Failed to create ModelContainer: \(error)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainView()
                .onOpenURL { url in
                    handleDeepLink(url)
                }
        }
        .modelContainer(sharedModelContainer)
    }

    private func handleDeepLink(_ url: URL) {
        guard url.scheme == "betterblue" else { return }

        if url.host == "vehicle",
           let vin = url.pathComponents.dropFirst().first {
            NotificationCenter.default.post(
                name: .selectVehicle,
                object: vin,
            )
        }
    }
}
