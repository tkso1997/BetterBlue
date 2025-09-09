//
//  BetterBlueWidget.swift
//  BetterBlueWidget
//
//  Created by Mark Schmidt on 8/29/25.
//

import BetterBlueKit
import SwiftData
import SwiftUI
import WidgetKit

struct BetterBlueWidget: Widget {
    let kind: String = "BetterBlueWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: VehicleWidgetIntent.self,
            provider: VehicleTimelineProvider(),
        ) { entry in
            VehicleWidgetEntryView(entry: entry)
                .containerBackground(for: .widget) {
                    if let vehicle = entry.vehicle {
                        LinearGradient(
                            gradient: Gradient(colors: vehicle.backgroundGradient),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing,
                        )
                    } else {
                        Color.gray.opacity(0.1)
                    }
                }
        }
        .contentMarginsDisabled() // Here
        .configurationDisplayName("Vehicle Control")
        .description("Quick controls for your vehicle. Use Edit Widget to select a different vehicle.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
