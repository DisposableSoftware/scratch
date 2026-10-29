import Foundation
import Network

/// Which network the device is on now (TRANS-3).
protocol NetworkGateway {
    var currentNetwork: NetworkKind { get }
}

/// Asks the path monitor each time, so the answer is right from launch rather than after its
/// first callback. Anything that isn't only cellular counts as Wi-Fi: wired and other networks,
/// and Wi-Fi Assist, are treated the same.
final class PathMonitorNetworkGateway: NetworkGateway {
    private let monitor = NWPathMonitor()

    init() {
        monitor.start(queue: DispatchQueue(label: "scratch.network"))
    }

    deinit {
        monitor.cancel()
    }

    var currentNetwork: NetworkKind {
        let path = monitor.currentPath
        return path.usesInterfaceType(.cellular) && !path.usesInterfaceType(.wifi) ? .cellular : .wifi
    }
}
