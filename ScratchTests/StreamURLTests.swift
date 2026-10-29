import Foundation
import Testing
@testable import Scratch

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
