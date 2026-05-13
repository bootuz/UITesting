import Foundation
@testable import UITestingCore

/// Virtual clock that advances on `sleep` rather than waiting wall-time.
/// Lets retry-loop tests run in microseconds.
final class VirtualClock: SyncClock, @unchecked Sendable {
    private let queue = DispatchQueue(label: "VirtualClock")
    private var current: Date

    init(start: Date = Date(timeIntervalSinceReferenceDate: 0)) {
        self.current = start
    }

    func now() -> Date {
        queue.sync { current }
    }

    func sleep(_ duration: Duration) {
        queue.sync {
            current = current.addingTimeInterval(duration.seconds)
        }
    }

    /// Manually advance time without invoking `sleep` from production code.
    /// Useful for arranging "element appears at t=N" scenarios.
    func advance(by duration: Duration) {
        queue.sync {
            current = current.addingTimeInterval(duration.seconds)
        }
    }
}
