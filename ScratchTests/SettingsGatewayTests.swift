import Foundation
import Testing
@testable import Scratch

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
