import Foundation
import Testing
@testable import Scratch

struct TranscodingSettingsTests {
    @Test func defaultsAreOriginalOnWiFiAndMP3At192OnCellular() {
        #expect(TranscodingSettings.defaults.wifi == StreamQuality(format: .original, maxBitRate: nil))
        #expect(TranscodingSettings.defaults.cellular == StreamQuality(format: .mp3, maxBitRate: 192))
    }

    @Test func theOptionsAreTheOnesTheSpecLists() {
        #expect(StreamQuality.Format.allCases == [.original, .mp3, .aac])
        #expect(StreamQuality.bitRates == [320, 256, 192, 128, 96, 64])
    }

    @Test func originalIsNeverCapped() {
        var quality = StreamQuality(format: .original, maxBitRate: 128)
        #expect(quality.maxBitRate == nil)
        quality.maxBitRate = 96
        #expect(quality.maxBitRate == nil)

        quality = StreamQuality(format: .mp3, maxBitRate: 128)
        quality.format = .original
        #expect(quality.maxBitRate == nil)
    }

    @Test func savedOriginalWithACapLoadsUncapped() throws {
        let data = Data(#"{"wifi":{"format":"raw","maxBitRate":96},"cellular":{"format":"mp3","maxBitRate":64}}"#.utf8)
        let settings = try JSONDecoder().decode(TranscodingSettings.self, from: data)
        #expect(settings.wifi == StreamQuality(format: .original, maxBitRate: nil))
        #expect(settings.cellular == StreamQuality(format: .mp3, maxBitRate: 64))
    }

    @Test func theNetworkPicksTheQuality() {
        let network = NetworkGatewayStub()
        let useCase = DefaultTranscodingUseCase(settingsGateway: SettingsGatewayMock(), networkGateway: network)
        #expect(useCase.qualityForNextTrack() == useCase.settings.wifi)
        network.currentNetwork = .cellular
        #expect(useCase.qualityForNextTrack() == useCase.settings.cellular)
    }

    @Test func changesAreSavedAndLoadedAtStart() {
        let gateway = SettingsGatewayMock()
        let changed = TranscodingSettings(wifi: StreamQuality(format: .aac, maxBitRate: 256), cellular: StreamQuality(format: .mp3, maxBitRate: 64))

        DefaultTranscodingUseCase(settingsGateway: gateway, networkGateway: NetworkGatewayStub()).update(changed)
        #expect(gateway.saved == changed)
        #expect(DefaultTranscodingUseCase(settingsGateway: gateway, networkGateway: NetworkGatewayStub()).settings == changed)
    }

    @Test func nothingSavedMeansTheDefaults() {
        #expect(DefaultTranscodingUseCase(settingsGateway: SettingsGatewayMock(), networkGateway: NetworkGatewayStub()).settings == .defaults)
    }
}

/// The real UserDefaults, under a throwaway suite.
struct SettingsGatewayTests {
    @Test func roundTripsAcrossInstances() {
        let environment = AppEnvironment.fresh()
        defer { environment.remove() }
        let changed = TranscodingSettings(wifi: StreamQuality(format: .aac, maxBitRate: 256), cellular: StreamQuality(format: .mp3, maxBitRate: 64))

        #expect(UserDefaultsSettingsGateway(environment: environment).transcoding() == nil)
        UserDefaultsSettingsGateway(environment: environment).saveTranscoding(changed)
        #expect(UserDefaultsSettingsGateway(environment: environment).transcoding() == changed)
    }

    @Test func unreadableDataIsNothingSaved() {
        let environment = AppEnvironment.fresh()
        defer { environment.remove() }
        environment.defaults.set(Data("not json".utf8), forKey: "settings.transcoding")
        #expect(UserDefaultsSettingsGateway(environment: environment).transcoding() == nil)
    }
}

struct StreamURLTests {
    private func query(_ quality: StreamQuality) throws -> [String: String] {
        let url = try SubsonicRequest.stream(trackID: "t1", quality: quality).url(baseURL: try ServerAddress.parse("example.com"), credentials: .init(username: "u", salt: "s", token: "t"))
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)
        #expect(url.path == "/rest/stream")
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }

    @Test func originalUnlimitedAsksForTheRawFile() throws {
        let q = try query(StreamQuality(format: .original, maxBitRate: nil))
        #expect(q["id"] == "t1" && q["format"] == "raw" && q["estimateContentLength"] == "true")
        #expect(q["maxBitRate"] == nil)
    }

    @Test(arguments: [(StreamQuality.Format.mp3, "mp3"), (.aac, "aac")])
    func formatAndCapAreSent(format: StreamQuality.Format, expected: String) throws {
        let q = try query(StreamQuality(format: format, maxBitRate: 128))
        #expect(q["format"] == expected && q["maxBitRate"] == "128" && q["estimateContentLength"] == "true")
    }

    @Test func mp3UnlimitedSendsNoCap() throws {
        let q = try query(StreamQuality(format: .mp3, maxBitRate: nil))
        #expect(q["format"] == "mp3" && q["maxBitRate"] == nil)
    }
}

private struct SettingsUseCases: HasTranscodingUseCase, HasCoordinator {
    let transcodingUseCase: TranscodingUseCase
    let coordinator: Coordinator
}

struct SettingsViewModelTests {
    @Test func changesAreSavedPerNetwork() async {
        let transcoding = TranscodingUseCaseMock()
        let viewModel = SettingsViewModel(useCases: SettingsUseCases(transcodingUseCase: transcoding, coordinator: CoordinatorSpy()))

        _ = await viewModel.handleAction(.formatChanged(.cellular, .aac))
        _ = await viewModel.handleAction(.maxBitRateChanged(.cellular, 96))
        _ = await viewModel.handleAction(.maxBitRateChanged(.wifi, 320))

        #expect(transcoding.settings.cellular == StreamQuality(format: .aac, maxBitRate: 96))
        #expect(transcoding.settings.wifi == StreamQuality(format: .original, maxBitRate: nil))
        #expect(viewModel.transcoding == transcoding.settings)
    }

    @Test func switchingToOriginalDropsTheCap() async {
        let transcoding = TranscodingUseCaseMock()
        let viewModel = SettingsViewModel(useCases: SettingsUseCases(transcodingUseCase: transcoding, coordinator: CoordinatorSpy()))
        _ = await viewModel.handleAction(.formatChanged(.cellular, .original))
        #expect(transcoding.settings.cellular == StreamQuality(format: .original, maxBitRate: nil))
    }

    @Test func doneClosesTheSheet() async {
        let coordinator = CoordinatorSpy()
        let viewModel = SettingsViewModel(useCases: SettingsUseCases(transcodingUseCase: TranscodingUseCaseMock(), coordinator: coordinator))
        _ = await viewModel.handleAction(.done)
        guard case .dismissSheet = coordinator.destinations.last else {
            Issue.record("expected dismissSheet, got \(coordinator.destinations)")
            return
        }
    }
}
