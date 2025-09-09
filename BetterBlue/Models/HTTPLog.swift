//
//  HTTPLog.swift
//  BetterBlue
//
//  Created by Mark Schmidt on 9/6/25.
//
import BetterBlueKit
import Foundation
import SwiftData

@Model
class BBHTTPLog {
    var log: HTTPLog = HTTPLog(
        timestamp: Date(),
        accountId: UUID(),
        requestType: .fetchVehicleStatus,
        method: "",
        url: "",
        requestHeaders: [:],
        requestBody: nil,
        responseStatus: nil,
        responseHeaders: [:],
        responseBody: nil,
        error: nil,
        duration: 0,
    )

    init(log: HTTPLog) {
        self.log = log
    }
}
