import SwiftUI
import Testing
@testable import Scratch

private final class StackPortSpy: NavigationStackPort {
    private(set) var kinds: [String] = []

    func stack(root: AnyView, pushing kind: String) -> AnyView {
        kinds.append(kind)
        return root
    }
}

struct PushStackHostTests {
    private func push(_ key: String) -> NavigationDestination { .push(key: key, AnyView(Text(key))) }

    private func host(_ kinds: String...) -> PushStackHost {
        let host = PushStackHost()

        for kind in kinds { _ = host.stack(root: AnyView(Text(kind)), pushing: kind) }

        return host
    }

    // ALB-8

    @Test func aPushIsAddedToThePath() {
        let host = host("album")

        #expect(host.handle(push("album:a1")))
        #expect(host.handle(push("album:a2")))
        #expect(host.paths["album"]?.map(\.key) == ["album:a1", "album:a2"])
    }

    @Test func theSameScreenIsNotPushedOnTopOfItself() {
        let host = host("album")

        #expect(host.handle(push("album:a1")))
        #expect(host.handle(push("album:a1")))
        #expect(host.paths["album"]?.count == 1)
    }

    @Test func theSameScreenCanBePushedAgainOnceSomethingElseIsOnTop() {
        let host = host("album")
        _ = host.handle(push("album:a1"))
        _ = host.handle(push("album:a2"))
        _ = host.handle(push("album:a1"))

        #expect(host.paths["album"]?.map(\.key) == ["album:a1", "album:a2", "album:a1"])
    }

    @Test func otherDestinationsAreLeftToOtherHandlers() {
        let host = host("album")

        #expect(!host.handle(.dismissSheet))
        #expect(!host.handle(.alert(AlertContent(title: "", message: ""))))
        #expect(!host.handle(.root(AnyView(Text("")))))
        #expect(host.paths["album"]?.isEmpty == true)
    }

    @Test func aNewStackStartsEmpty() {
        let host = host("album")
        _ = host.handle(push("album:a1"))

        _ = host.stack(root: AnyView(Text("root")), pushing: "album")

        #expect(host.paths["album"]?.isEmpty == true)
    }

    // PLST-6

    @Test func eachTabHasItsOwnPath() {
        let host = host("album", "playlist")

        #expect(host.handle(push("album:a1")))
        #expect(host.handle(push("playlist:p1")))
        #expect(host.paths["album"]?.map(\.key) == ["album:a1"])
        #expect(host.paths["playlist"]?.map(\.key) == ["playlist:p1"])
    }

    @Test func startingOneTabsStackLeavesTheOthersAlone() {
        let host = host("album", "playlist")
        _ = host.handle(push("album:a1"))

        _ = host.stack(root: AnyView(Text("root")), pushing: "playlist")

        #expect(host.paths["album"]?.count == 1)
    }

    @Test func aPushForNoStackIsNotTaken() {
        let host = host("album")

        #expect(!host.handle(push("playlist:p1")))
    }

    @Test func theMainScreenIsBuiltInsideTheHostsStacks() {
        let port = StackPortSpy()
        let factory = AppViewFactory()
        factory.useCases = TestContainer.build()
        factory.navigationStack = port

        guard case .root = factory.destination(for: .library, with: AppFlowData()) else {
            Issue.record("expected the main screen as the root")
            return
        }

        #expect(port.kinds == ["album", "playlist"])
    }
}
