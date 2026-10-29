import Foundation

/// The HTTP transport the app hands to the Container. `URLSession` is the real one.
protocol NetworkSession {
    func send(_ request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: NetworkSession {
    func send(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request, delegate: SameOriginRedirects())
    }
}

/// Every request carries a replayable token in its query, so a redirect may only stay on the same
/// scheme, host and port. Anything else (a single-sign-on page, an https to http downgrade) is
/// not followed: the redirect response itself comes back and reads as "not a Subsonic server".
/// Nonisolated with a completion handler: URLSession calls it off the main actor, and Swift 6.4
/// crashes compiling the async form of this method on a main-actor class.
nonisolated private final class SameOriginRedirects: NSObject, URLSessionTaskDelegate {
    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        willPerformHTTPRedirection response: HTTPURLResponse,
        newRequest request: URLRequest,
        completionHandler: @escaping @Sendable (URLRequest?) -> Void
    ) {
        guard let from = task.originalRequest?.url, let to = request.url,
              from.scheme?.lowercased() == to.scheme?.lowercased(),
              from.host()?.lowercased() == to.host()?.lowercased(),
              from.port == to.port
        else { return completionHandler(nil) }
        completionHandler(request)
    }
}
