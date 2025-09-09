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
    static var httpLogSink: HTTPLogSink?

    var sharedModelContainer: ModelContainer = {
        do {
            let container = try createSharedModelContainer()

            // Set up global HTTPLogSink for the app
            BetterBlueApp.httpLogSink = { @Sendable httpLog in
                Task { @MainActor in
                    let context = container.mainContext
                    let bbHttpLog = BBHTTPLog(log: httpLog)
                    context.insert(bbHttpLog)

                    do {
                        try context.save()
                    } catch {
                        print("🔴 [HTTPLog] Failed to save HTTP log: \(error)")
                    }
                }
            }

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
