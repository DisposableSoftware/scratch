import Foundation
import Testing
@testable import Scratch

struct SubsonicRequestTests {
    @Test func tokenMatchesTheSubsonicDocumentationExample() {
        // From the Subsonic API docs: password "sesame", salt "c19b2d".
        let credentials = SubsonicCredentials.derive(username: "admin", password: "sesame", salt: "c19b2d")

        #expect(credentials.token == "26719a1196d2a940705a59634eb18eab")
    }

    @Test func eachDerivationGetsAFreshSalt() {
        let a = SubsonicCredentials.derive(username: "me", password: "pw")
        let b = SubsonicCredentials.derive(username: "me", password: "pw")

        #expect(a.salt.count == 32)
        #expect(a.salt != b.salt && a.token != b.token)
    }

    @Test func signsTheRequestAndAsksForJSON() throws {
        let credentials = SubsonicCredentials(username: "me", salt: "abc", token: "def")
        let url = try SubsonicRequest(method: "ping").url(
            baseURL: try ServerAddress.parse("https://example.com/navidrome"),
            credentials: credentials
        )
        let components = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })

        #expect(components.path == "/navidrome/rest/ping")
        #expect(query == ["u": "me", "t": "def", "s": "abc", "v": "1.16.1", "c": "Scratch", "f": "json"])
    }

    @Test func neverCarriesThePassword() throws {
        let credentials = SubsonicCredentials.derive(username: "me", password: "hunter2")
        let url = try SubsonicRequest(method: "ping").url(baseURL: try ServerAddress.parse("example.com"), credentials: credentials)

        #expect(!url.absoluteString.contains("hunter2"))
        #expect(!url.absoluteString.contains("p="))
    }

    @Test func appendsMethodParametersAfterAuth() throws {
        let request = SubsonicRequest(method: "search3", parameters: [URLQueryItem(name: "query", value: "a b&c")])
        let url = try request.url(baseURL: try ServerAddress.parse("example.com"), credentials: .init(username: "u", salt: "s", token: "t"))
        let items = try #require(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems)

        #expect(items.last == URLQueryItem(name: "query", value: "a b&c"))
        #expect(url.absoluteString.contains("query=a%20b%26c"))
    }

    @Test func encodesPlusSoServersDontReadItAsASpace() throws {
        let credentials = SubsonicCredentials(username: "a+b&c=d é", salt: "s", token: "t")
        let request = SubsonicRequest(method: "search3", parameters: [URLQueryItem(name: "query", value: "AC+DC")])
        let url = try request.url(baseURL: try ServerAddress.parse("example.com"), credentials: credentials)

        #expect(url.absoluteString.contains("u=a%2Bb%26c%3Dd%20%C3%A9"))
        #expect(url.absoluteString.contains("query=AC%2BDC"))

        // Form-style decoding, as Go's url.ParseQuery (Navidrome) does it: + would mean space.
        let query = try #require(url.query(percentEncoded: true))
        let decoded = query.split(separator: "&").map {
            $0.replacingOccurrences(of: "+", with: " ").removingPercentEncoding ?? ""
        }

        #expect(decoded.contains("u=a+b&c=d é"))
        #expect(decoded.contains("query=AC+DC"))
    }
}
