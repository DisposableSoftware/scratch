import Foundation
import Testing
@testable import Scratch

struct ServerURLTests {
    @Test(arguments: [
        ("https://music.example.com", "https://music.example.com"),
        ("http://192.168.1.20:4533", "http://192.168.1.20:4533"),
        ("https://example.com/navidrome", "https://example.com/navidrome"),
        ("https://example.com/navidrome/", "https://example.com/navidrome"),
        ("music.example.com", "https://music.example.com"),
        ("localhost:4533", "https://localhost:4533"),
        ("  HTTPS://Music.Example.com:8443/nd  ", "https://Music.Example.com:8443/nd"),
        ("[::1]:4533", "https://[::1]:4533"),
        ("http://[fe80::1]:4533/nd", "http://[fe80::1]:4533/nd"),
    ])

    func acceptsServerAddresses(input: String, expected: String) throws {
        #expect(try ServerAddress.parse(input).absoluteString == expected)
    }

    @Test func rejectsEmptyInput() {
        #expect(throws: ServerAddressError.empty) { try ServerAddress.parse("   ") }
    }

    @Test func rejectsOtherSchemes() {
        #expect(throws: ServerAddressError.unsupportedScheme("ftp")) { try ServerAddress.parse("ftp://example.com") }
    }

    @Test func rejectsAMissingHost() {
        #expect(throws: ServerAddressError.missingHost) { try ServerAddress.parse("https://") }
    }

    @Test(arguments: ["http:/host", "Http//host", "https//example.com", "ftp:/x", "https:host"])
    func rejectsMistypedSchemesRatherThanTreatingThemAsHosts(input: String) {
        #expect(throws: ServerAddressError.invalid) { try ServerAddress.parse(input) }
    }

    @Test(arguments: ["https://example.com:99999", "https://example.com:0"])
    func rejectsPortsOutOfRange(input: String) {
        #expect(throws: ServerAddressError.invalid) { try ServerAddress.parse(input) }
    }

    @Test func rejectsQueriesFragmentsAndUserInfo() {
        #expect(throws: ServerAddressError.invalid) { try ServerAddress.parse("https://example.com/?a=1") }
        #expect(throws: ServerAddressError.invalid) { try ServerAddress.parse("https://example.com/#x") }
        #expect(throws: ServerAddressError.invalid) { try ServerAddress.parse("https://me:pw@example.com") }
    }
}
