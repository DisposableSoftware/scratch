import Foundation
@testable import Scratch

/// Answers every request of a stubbed URLSession from `responder`. Suites that use it run
/// `.serialized`, because the responder is shared.
nonisolated final class StubURLProtocol: URLProtocol {
    enum Reply {
        case http(status: Int, body: String)
        case image(String)
        case redirect(to: String)
        case failure(URLError.Code)
    }

    nonisolated(unsafe) static var responder: (URLRequest) -> Reply = { _ in .failure(.notConnectedToInternet) }
    nonisolated(unsafe) static var requests: [URLRequest] = []

    static func session(_ responder: @escaping (URLRequest) -> Reply) -> URLSession {
        Self.responder = responder
        Self.requests = []
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]

        return URLSession(configuration: configuration)
    }

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.requests.append(request)

        switch Self.responder(request) {
        case .http(let status, let body):
            let response = HTTPURLResponse(url: request.url ?? URL(fileURLWithPath: "/"), statusCode: status, httpVersion: nil, headerFields: nil)

            if let response {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }

            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)

        case .image(let body):
            if let url = request.url,
               let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "image/png"]) {
                client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            }

            client?.urlProtocol(self, didLoad: Data(body.utf8))
            client?.urlProtocolDidFinishLoading(self)

        case .redirect(let location):
            guard let url = request.url, let target = URL(string: location),
                  let response = HTTPURLResponse(url: url, statusCode: 302, httpVersion: nil, headerFields: ["Location": location])
            else { return }

            // If the session refuses the redirect, the 302 itself is the answer.
            client?.urlProtocol(self, wasRedirectedTo: URLRequest(url: target), redirectResponse: response)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: Data("<html>Moved</html>".utf8))
            client?.urlProtocolDidFinishLoading(self)

        case .failure(let code):
            client?.urlProtocol(self, didFailWithError: URLError(code))
        }
    }

    override func stopLoading() {}
}

enum SubsonicReply {
    static let ok = #"{"subsonic-response":{"status":"ok","version":"1.16.1","type":"navidrome","openSubsonic":true}}"#

    static func error(_ code: Int, _ message: String) -> String {
        #"{"subsonic-response":{"status":"failed","version":"1.16.1","error":{"code":\#(code),"message":"\#(message)"}}}"#
    }
}
