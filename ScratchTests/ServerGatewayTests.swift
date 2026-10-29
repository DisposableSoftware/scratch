import Foundation
import Testing
@testable import Scratch

@Suite(.serialized)
struct ServerGatewayTests {
    private let baseURL = URL(string: "https://music.example.com")!
    private let credentials = SubsonicCredentials(username: "me", salt: "salt", token: "token")

    private func ping(_ reply: @escaping (URLRequest) -> StubURLProtocol.Reply) async throws(ServerError) {
        try await RemoteServerGateway(networkSession: StubURLProtocol.session(reply)).ping(baseURL: baseURL, credentials: credentials)
    }

    @Test func okIsSuccess() async throws {
        try await ping { _ in .http(status: 200, body: SubsonicReply.ok) }
        let url = try #require(StubURLProtocol.requests.first?.url)

        #expect(url.path == "/rest/ping")
        #expect(url.query?.contains("t=token") == true)
    }

    @Test func error40IsWrongCredentials() async {
        await #expect(throws: ServerError.wrongCredentials) {
            try await ping { _ in .http(status: 200, body: SubsonicReply.error(40, "Wrong username or password")) }
        }
    }

    @Test func otherErrorsCarryTheServersMessage() async {
        await #expect(throws: ServerError.failed(code: 41, message: "Token authentication not supported")) {
            try await ping { _ in .http(status: 200, body: SubsonicReply.error(41, "Token authentication not supported")) }
        }
    }

    @Test(arguments: [
        StubURLProtocol.Reply.http(status: 200, body: "<html>Welcome</html>"),
        .http(status: 404, body: "Not found"),
        .http(status: 200, body: #"{"something":"else"}"#),
    ])

    func anythingElseIsNotSubsonic(reply: StubURLProtocol.Reply) async {
        await #expect(throws: ServerError.notSubsonic) { try await ping { _ in reply } }
    }

    @Test(arguments: [502, 503, 504])
    func aProxyErrorPageIsUnreachable(status: Int) async {
        await #expect(throws: ServerError.unreachable) {
            try await ping { _ in .http(status: status, body: "<html>Bad Gateway</html>") }
        }
    }

    @Test func aFailedStatusWithoutAnErrorIsAServerFailure() async {
        await #expect(throws: ServerError.failed(code: 0, message: "")) {
            try await ping { _ in .http(status: 200, body: #"{"subsonic-response":{"status":"failed","version":"1.16.1"}}"#) }
        }
    }

    @Test func followsARedirectOnTheSameOrigin() async throws {
        try await ping { request in
            request.url?.path == "/rest/ping"
                ? .redirect(to: "https://music.example.com/moved/rest/ping?" + (request.url?.query ?? ""))
                : .http(status: 200, body: SubsonicReply.ok)
        }

        #expect(StubURLProtocol.requests.map { $0.url?.path } == ["/rest/ping", "/moved/rest/ping"])
    }

    @Test(arguments: ["https://sso.example.com/login?rd=x", "http://music.example.com/rest/ping", "https://music.example.com:8443/rest/ping"])
    func refusesRedirectsToAnotherOriginSoTheTokenStaysPut(location: String) async {
        await #expect(throws: ServerError.notSubsonic) {
            try await ping { request in
                request.url?.host() == "music.example.com" && request.url?.scheme == "https" && request.url?.port == nil
                    ? .redirect(to: location)
                    : .http(status: 200, body: SubsonicReply.ok)
            }
        }

        #expect(StubURLProtocol.requests.count == 1)
    }

    @Test(arguments: [URLError.Code.cannotFindHost, .cannotConnectToHost, .timedOut, .serverCertificateUntrusted])
    func transportFailuresAreUnreachable(code: URLError.Code) async {
        await #expect(throws: ServerError.unreachable) { try await ping { _ in .failure(code) } }
    }
}
