//
//  BetterBlueWatchApp.swift
//  BetterBlueWatch Watch App
//
//  Created by Mark Schmidt on 8/28/25.
//

import BetterBlueKit
import Foundation
import SwiftData
import SwiftUI

extension Notification.Name {
    static let fakeAccountConfigurationChanged = Notification.Name("FakeAccountConfigurationChanged")
}

@main
struct BetterBlueWatch_Watch_AppApp: App {
    var sharedModelContainer: ModelContainer = {
        do {
            let container = try createSharedModelContainer()
            print("✅ [WatchApp] Created shared ModelContainer")
            return container
        } catch {
            print("❌ [WatchApp] Failed to create ModelContainer: \(error)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()
}

extension BetterBlueWatch_Watch_AppApp {
    var body: some Scene {
        WindowGroup {
            WatchMainView()
        }
        .modelContainer(sharedModelContainer)
    }
}
