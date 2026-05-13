import Foundation

/// Timeout configuration used by Locator action auto-wait and matcher polling.
///
/// Override layers, last write wins:
///   package default → `Screen.timeoutPolicy` → per-call `.with(timeout:)`
public struct TimeoutPolicy: Sendable, Equatable {
    public var action: Duration
    public var assertion: Duration
    public var pollInterval: Duration

    public init(
        action: Duration = .seconds(5),
        assertion: Duration = .seconds(5),
        pollInterval: Duration = .milliseconds(50)
    ) {
        self.action = action
        self.assertion = assertion
        self.pollInterval = pollInterval
    }

    public static let `default` = TimeoutPolicy()
}
