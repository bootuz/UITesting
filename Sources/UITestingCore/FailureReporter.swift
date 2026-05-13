import Foundation

/// Sink for `LocatorError` instances produced by matchers and Locator actions.
///
/// `UITestingCore` defines the protocol so matcher logic can live in the
/// framework-agnostic core. The `UITesting` adapter ships an XCTest-backed
/// implementation that calls `XCTIssue` with `error.file`/`error.line` so
/// Xcode pins the failure marker to the user's call site.
public protocol FailureReporter: Sendable {
    func record(_ error: LocatorError)
}

/// A no-op reporter, useful for unit-testing Locator and matcher behavior
/// independent of failure delivery. Records errors in memory for inspection.
public final class RecordingFailureReporter: FailureReporter, @unchecked Sendable {
    private let lock = NSLock()
    private var _errors: [LocatorError] = []

    public init() {}

    public func record(_ error: LocatorError) {
        lock.lock()
        defer { lock.unlock() }
        _errors.append(error)
    }

    public var errors: [LocatorError] {
        lock.lock()
        defer { lock.unlock() }
        return _errors
    }

    public func reset() {
        lock.lock()
        defer { lock.unlock() }
        _errors = []
    }
}

