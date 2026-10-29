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

    @Test func albumsPerRowRoundTripsAcrossInstances() {
        let environment = AppEnvironment.fresh()
        defer { environment.remove() }

        #expect(UserDefaultsSettingsGateway(environment: environment).albumsPerRow() == nil)
        UserDefaultsSettingsGateway(environment: environment).saveAlbumsPerRow(4)

        #expect(UserDefaultsSettingsGateway(environment: environment).albumsPerRow() == 4)
    }

    @Test func aNumericStringCountsAsTheChoice() {
        // What `-settings.albumsPerRow 5` on the launch command line puts in the defaults.
        let environment = AppEnvironment.fresh()
        defer { environment.remove() }
        environment.defaults.set("5", forKey: "settings.albumsPerRow")

        #expect(UserDefaultsSettingsGateway(environment: environment).albumsPerRow() == 5)
    }

    @Test(arguments: ["abc", "", "3.7x", "five"])
    func aGarbageStringCountsAsNothingSaved(text: String) {
        let environment = AppEnvironment.fresh()
        defer { environment.remove() }
        environment.defaults.set(text, forKey: "settings.albumsPerRow")

        #expect(UserDefaultsSettingsGateway(environment: environment).albumsPerRow() == nil)
    }

    @Test func aBlobCountsAsNothingSaved() {
        let environment = AppEnvironment.fresh()
        defer { environment.remove() }
        environment.defaults.set(Data([1, 2, 3]), forKey: "settings.albumsPerRow")

        #expect(UserDefaultsSettingsGateway(environment: environment).albumsPerRow() == nil)
    }

    @Test func aNumericStringWithSpacesStillCounts() {
        let environment = AppEnvironment.fresh()
        defer { environment.remove() }
        environment.defaults.set(" 4 ", forKey: "settings.albumsPerRow")

        #expect(UserDefaultsSettingsGateway(environment: environment).albumsPerRow() == 4)
    }
}
