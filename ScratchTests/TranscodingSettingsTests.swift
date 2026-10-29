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

private struct SettingsUseCases: HasTranscodingUseCase, HasSessionUseCase, HasAppRoutingUseCase, HasCoordinator {
    let transcodingUseCase: TranscodingUseCase
    let coordinator: Coordinator
    var sessionUseCase: SessionUseCase = SessionUseCaseMock()
    var appRouting: AppRoutingUseCase = AppRoutingUseCaseSpy()
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

    // SRV-7

    @Test func showsTheServerAndSignsOut() async {
        let session = SessionUseCaseMock()
        let routing = AppRoutingUseCaseSpy()
        let viewModel = SettingsViewModel(useCases: SettingsUseCases(transcodingUseCase: TranscodingUseCaseMock(), coordinator: CoordinatorSpy(), sessionUseCase: session, appRouting: routing))
        #expect(viewModel.account == SavedServer.sample.account)

        _ = await viewModel.handleAction(.signOut)

        #expect(session.signOuts == 1 && viewModel.account == nil)
        #expect(routing.steps == [.library])
    }
}
