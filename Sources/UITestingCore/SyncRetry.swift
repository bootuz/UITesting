import Foundation

/// Clock abstraction so `syncRetry` can be driven by a virtual clock in
/// tests (instant time advance) and by wall time in production.
public protocol SyncClock: Sendable {
    func now() -> Date
    func sleep(_ duration: Duration)
}

/// Wall-clock implementation that blocks the current thread via `Thread.sleep`.
/// UI tests run on a dedicated test thread; blocking it is fine.
public struct WallClock: SyncClock {
    public init() {}

    public func now() -> Date { Date() }

    public func sleep(_ duration: Duration) {
        Thread.sleep(forTimeInterval: duration.seconds)
    }
}

/// Synchronous polling primitive shared by Locator action auto-wait and
/// Expectation matchers.
///
/// Returns the predicate's non-nil value on success, or throws the supplied
/// timeout error if the deadline passes without satisfaction. The predicate
/// is run once more after the deadline to ensure we don't time out on a UI
/// state that became valid in the last poll interval.
public func syncRetry<T>(
    until predicate: () throws -> T?,
    timeout: Duration,
    pollInterval: Duration,
    clock: any SyncClock = WallClock(),
    onTimeout: () throws -> Never
) throws -> T {
    let start = clock.now()
    let deadline = start.addingTimeInterval(timeout.seconds)

    while clock.now() < deadline {
        if let value = try predicate() { return value }
        clock.sleep(pollInterval)
    }
    if let value = try predicate() { return value }
    try onTimeout()
}

extension Duration {
    /// Seconds as `TimeInterval`. Convenient for bridging to Foundation APIs.
    public var seconds: TimeInterval {
        Double(components.seconds) +
        Double(components.attoseconds) / 1e18
    }
}
