//
//  HTTPLogView.swift
//  BetterBlue
//
//  Created by Mark Schmidt on 8/4/25.
//

import BetterBlueKit
import SwiftData
import SwiftUI

struct HTTPLogView: View {
    let accountId: UUID
    var transition: Namespace.ID?
    @Environment(\.modelContext) private var modelContext
    @Query private var allLogs: [BBHTTPLog]
    @State private var selectedRequestTypes: Set<HTTPRequestType> = Set(HTTPRequestType.allCases)
    @State private var showingFilterSheet = false
    @Namespace private var fallbackTransition

    init(accountId: UUID, transition: Namespace.ID? = nil) {
        self.accountId = accountId
        self.transition = transition
        // Query for logs belonging to this account, sorted by timestamp descending
        _allLogs = Query(
            filter: #Predicate<BBHTTPLog> { bbLog in
                bbLog.log.accountId == accountId
            },
            sort: [SortDescriptor(\BBHTTPLog.log.timestamp, order: .reverse)],
        )
    }

    var accountLogs: [HTTPLog] {
        allLogs
            .map(\.log)
            .filter { selectedRequestTypes.contains($0.requestType) }
    }

    var body: some View {
        List {
            if accountLogs.isEmpty {
                ContentUnavailableView(
                    "No HTTP Logs",
                    systemImage: "network.slash",
                    description: Text("HTTP requests will appear here when made by this account."),
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(accountLogs, id: \.id) { log in
                    NavigationLink(
                        destination: HTTPLogDetailView(log: log, transition: transition ?? fallbackTransition),
                    ) {
                        HTTPLogRowView(log: log)
                    }
                }
            }
        }
        .navigationTitle("HTTP Logs")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu("Actions") {
                    Button("Filter", systemImage: "line.3.horizontal.decrease.circle") {
                        showingFilterSheet = true
                    }

                    Divider()

                    Button("Clear All", systemImage: "trash", role: .destructive) {
                        clearAllLogs()
                    }
                }
            }
        }
        .sheet(isPresented: $showingFilterSheet) {
            HTTPLogFilterSheet(selectedRequestTypes: $selectedRequestTypes)
        }
    }

    private func clearAllLogs() {
        for bbLog in allLogs {
            modelContext.delete(bbLog)
        }
        try? modelContext.save()
    }
}

struct HTTPLogRowView: View {
    let log: HTTPLog

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                // Request Type Badge
                Text(log.requestType.displayName)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .foregroundColor(.primary)
                    .cornerRadius(4)

                // Method Badge
                Text(log.method)
                    .font(.caption)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .foregroundColor(.primary)
                    .cornerRadius(4)

                // Status Code Badge
                Text(log.responseStatus?.description ?? "Unknown")
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(statusColor.opacity(0.2))
                    .foregroundColor(statusColor)
                    .cornerRadius(4)

                Spacer()

                // Timestamp
                Text(DateFormatter.timeOnlyFormatter.string(from: log.timestamp))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // URL
            HStack {
                Text(log.url)
                    .font(.subheadline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            // Duration and Error
            HStack {
                // Duration
                Text(String(format: "%.2fs", log.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // Error indicator
                if log.error != nil {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .padding(.vertical, 2)
    }

    private var statusColor: Color {
        guard let status = log.responseStatus else { return .secondary }
        switch status {
        case 200 ... 299: return .green
        case 300 ... 399: return .orange
        case 400 ... 499: return .red
        case 500 ... 599: return .red
        default: return .secondary
        }
    }
}

private extension DateFormatter {
    static let timeOnlyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        return formatter
    }()
}

#Preview {
    struct PreviewWrapper: View {
        var body: some View {
            let testAccountId = UUID()

            // Create an in-memory model container for preview
            let modelConfiguration = ModelConfiguration(isStoredInMemoryOnly: true)
            let container: ModelContainer
            do {
                container = try ModelContainer(
                    for: BBAccount.self, BBVehicle.self, BBHTTPLog.self,
                    configurations: modelConfiguration
                )
            } catch {
                fatalError("Failed to create model container: \(error)")
            }

            // Add sample HTTP logs
            let context = ModelContext(container)

            // Create sample logs with different types and statuses
            let sampleLogs = [
                HTTPLog(
                    timestamp: Date().addingTimeInterval(-300),
                    accountId: testAccountId,
                    requestType: .login,
                    method: "POST",
                    url: "https://prd.eu-ccapi.hyundai.com/api/v1/user/oauth2/authorize",
                    requestHeaders: ["Content-Type": "application/json"],
                    requestBody: nil,
                    responseStatus: 200,
                    responseHeaders: ["Content-Type": "application/json"],
                    responseBody: "{\"access_token\":\"...\"}",
                    error: nil,
                    duration: 1.23,
                    stackTrace: nil
                ),
                HTTPLog(
                    timestamp: Date().addingTimeInterval(-120),
                    accountId: testAccountId,
                    requestType: .fetchVehicles,
                    method: "GET",
                    url: "https://prd.eu-ccapi.hyundai.com/api/v2/spa/vehicles",
                    requestHeaders: ["Authorization": "Bearer ..."],
                    requestBody: nil,
                    responseStatus: 200,
                    responseHeaders: ["Content-Type": "application/json"],
                    responseBody: "{\"vehicles\":[{\"vin\":\"...\"}]}",
                    error: nil,
                    duration: 0.89,
                    stackTrace: nil
                ),
                HTTPLog(
                    timestamp: Date().addingTimeInterval(-60),
                    accountId: testAccountId,
                    requestType: .fetchVehicleStatus,
                    method: "GET",
                    url: "https://prd.eu-ccapi.hyundai.com/api/v2/spa/vehicles/KMHL14JA5KA123456/status/latest",
                    requestHeaders: ["Authorization": "Bearer ..."],
                    requestBody: nil,
                    responseStatus: 200,
                    responseHeaders: ["Content-Type": "application/json"],
                    responseBody: "{\"vehicleStatus\":{\"battery\":{\"level\":85}}}",
                    error: nil,
                    duration: 2.15,
                    stackTrace: nil
                ),
                HTTPLog(
                    timestamp: Date().addingTimeInterval(-30),
                    accountId: testAccountId,
                    requestType: .sendCommand,
                    method: "POST",
                    url: "https://prd.eu-ccapi.hyundai.com/api/v2/spa/vehicles/KMHL14JA5KA123456/control/engine",
                    requestHeaders: ["Authorization": "Bearer ...", "Content-Type": "application/json"],
                    requestBody: "{\"action\":\"start\",\"hvacSettings\":{\"temperature\":20}}",
                    responseStatus: 404,
                    responseHeaders: ["Content-Type": "application/json"],
                    responseBody: "{\"error\":\"Vehicle not found\"}",
                    error: "Vehicle not found",
                    duration: 5.67,
                    stackTrace: "HTTPLogView.swift:42\nMainView.swift:156"
                )
            ]

            // Insert sample logs into the context
            for log in sampleLogs {
                let bbLog = BBHTTPLog(log: log)
                context.insert(bbLog)
            }

            do {
                try context.save()
            } catch {
                print("Failed to save preview context: \(error)")
            }

            return NavigationView {
                HTTPLogView(accountId: testAccountId)
            }
            .modelContainer(container)
        }
    }
    return PreviewWrapper()
}
