//
//  HTTPLogSinkManager.swift
//  BetterBlue
//
//  Created by Mark Schmidt on 9/11/25.
//

import BetterBlueKit
import Foundation
import SwiftData

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#elseif os(watchOS)
import WatchKit
#endif

@MainActor
class HTTPLogSinkManager {
    static let shared = HTTPLogSinkManager()
    private var modelContainer: ModelContainer?
    private var deviceType: DeviceType?

    private init() {}

    func configure(with container: ModelContainer, deviceType: DeviceType) {
        self.modelContainer = container
        self.deviceType = deviceType
    }

    func createLogSink() -> HTTPLogSink? {
        guard let modelContainer, let deviceType else { return nil }

        return { httpLog in
            Task { @MainActor in
                let context = modelContainer.mainContext
                let bbHttpLog = BBHTTPLog(log: httpLog, deviceType: deviceType)
                context.insert(bbHttpLog)

                do {
                    try context.save()
                } catch {
                    print("🔴 [HTTPLog] Failed to save HTTP log: \(error)")
                }
            }
        }
    }

    static func detectMainAppDeviceType() -> DeviceType {
        #if os(macOS)
        return .mac
        #elseif os(iOS)
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .iPad
        } else {
            return .iPhone
        }
        #else
        return .iPhone
        #endif
    }
}
