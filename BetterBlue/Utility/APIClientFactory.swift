//
//  APIClientFactory.swift
//  BetterBlue
//
//  Created by Mark Schmidt on 8/21/25.
//

import BetterBlueKit
import Foundation
import SwiftData

// MARK: - EU Wrapper

/// Wrapper for Hyundai EU API Client that ensures device registration
@MainActor
final class HyundaiEUAPIClientWrapper: APIClientProtocol {
    private let client: HyundaiEUAPIClient
    private let provider: HyundaiEUAPIEndpointProvider
    private var deviceRegistrationCompleted = false

    init(client: HyundaiEUAPIClient, provider: HyundaiEUAPIEndpointProvider) {
        self.client = client
        self.provider = provider
    }

    func login() async throws -> AuthToken {
        print("🔐 [EUWrapper] Login...")
        let token = try await client.login()
        print("✅ [EUWrapper] Login successful")
        return token
    }

    func fetchVehicles(authToken: AuthToken) async throws -> [Vehicle] {
        try await ensureDeviceRegistered()
        print("🚗 [EUWrapper] Fetching vehicles...")
        return try await client.fetchVehicles(authToken: authToken)
    }

    func fetchVehicleStatus(for vehicle: Vehicle, authToken: AuthToken) async throws -> VehicleStatus {
        try await ensureDeviceRegistered()
        print("📊 [EUWrapper] Fetching status...")
        return try await client.fetchVehicleStatus(for: vehicle, authToken: authToken)
    }

    func sendCommand(for vehicle: Vehicle, command: VehicleCommand, authToken: AuthToken) async throws {
        try await ensureDeviceRegistered()
        print("📤 [EUWrapper] Sending command...")
        try await client.sendCommand(for: vehicle, command: command, authToken: authToken)
    }

    private func ensureDeviceRegistered() async throws {
        guard !deviceRegistrationCompleted else {
            return
        }

        print("🔧 [EUWrapper] Ensuring device registration...")
        try await provider.ensureDeviceRegistered()
        deviceRegistrationCompleted = true
        print("✅ [EUWrapper] Device registration complete")
    }
}

// MARK: - Configuration

struct APIClientFactoryConfiguration {
    let apiConfiguration: APIClientConfiguration
    let modelContext: ModelContext
    init(
        region: Region,
        brand: Brand,
        username: String,
        password: String,
        pin: String,
        accountId: UUID,
        modelContext: ModelContext,
        logSink: HTTPLogSink? = nil
    ) {
        apiConfiguration = APIClientConfiguration(
            region: region,
            brand: brand,
            username: username,
            password: password,
            pin: pin,
            accountId: accountId,
            logSink: logSink
        )
        self.modelContext = modelContext
    }
}

// MARK: - Factory

@MainActor
func createAPIClient(configuration: APIClientFactoryConfiguration) -> any APIClientProtocol {
    // Override brand selection for test account - always use fake client with app group storage
    let effectiveBrand = isTestAccount(
        username: configuration.apiConfiguration.username,
        password: configuration.apiConfiguration.password
    ) ? .fake : configuration.apiConfiguration.brand

    switch effectiveBrand {
    case .hyundai:
        // Region-based Hyundai client selection
        switch configuration.apiConfiguration.region {
        case .usa, .canada:
            print("🏗️ [APIClientFactory] Creating Hyundai US/Canada API client")
            let endpointProvider = HyundaiAPIEndpointProvider(configuration: configuration.apiConfiguration)
            let underlyingClient = HyundaiAPIClient(
                configuration: configuration.apiConfiguration,
                endpointProvider: endpointProvider
            )
            return CachedAPIClient(underlyingClient: underlyingClient)

        case .europe:
            print("🏗️ [APIClientFactory] Creating Hyundai EU API client")
            let endpointProvider = HyundaiEUAPIEndpointProvider(configuration: configuration.apiConfiguration)
            let client = HyundaiEUAPIClient(
                configuration: configuration.apiConfiguration,
                endpointProvider: endpointProvider
            )

            // Wrap with EU-specific wrapper that handles device registration
            let euWrapper = HyundaiEUAPIClientWrapper(client: client, provider: endpointProvider)

            // Then wrap with cache
            return CachedAPIClient(underlyingClient: euWrapper)

        case .australia, .china, .india:
            print("⚠️ [APIClientFactory] Region \(configuration.apiConfiguration.region) not yet implemented for Hyundai, falling back to US client")
            let endpointProvider = HyundaiAPIEndpointProvider(configuration: configuration.apiConfiguration)
            let underlyingClient = HyundaiAPIClient(
                configuration: configuration.apiConfiguration,
                endpointProvider: endpointProvider
            )
            return CachedAPIClient(underlyingClient: underlyingClient)
        }

    case .kia:
        print("🏗️ [APIClientFactory] Creating Kia API client")
        let endpointProvider = KiaAPIEndpointProvider(configuration: configuration.apiConfiguration)
        let underlyingClient = KiaAPIClient(
            configuration: configuration.apiConfiguration,
            endpointProvider: endpointProvider
        )
        return CachedAPIClient(underlyingClient: underlyingClient)

    case .fake:
        print("🏗️ [APIClientFactory] Creating SwiftData-based Fake API client")
        let vehicleProvider = SwiftDataFakeVehicleProvider(modelContext: configuration.modelContext)
        let underlyingClient = FakeAPIClient(
            configuration: configuration.apiConfiguration,
            vehicleProvider: vehicleProvider
        )
        return CachedAPIClient(underlyingClient: underlyingClient)
    }
}
