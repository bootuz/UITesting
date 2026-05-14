import Foundation

/// Begin an auto-retrying assertion against `locator`.
///
/// Chain a matcher (`.toBeVisible()`, `.toHaveLabel(_:)`, etc.) to perform
/// the assertion. The matcher polls the driver until the predicate is
/// satisfied (or its negation, if `.not` was used) or the assertion timeout
/// elapses.
///
/// ```swift
/// try expect(library.addButton).toBeVisible()
/// try expect(library.addButton).not.toBeHittable()
/// try expect(library.deckCell).with(timeout: .seconds(15)).toBeVisible()
/// ```
public func expect<K>(_ locator: Locator<K>) -> Expectation<K> {
    Expectation(
        locator: locator,
        timeout: locator.timeoutPolicy.assertion,
        pollInterval: locator.timeoutPolicy.pollInterval,
        isNegated: false
    )
}

/// A configured assertion target. Created by `expect(_:)`; immutable —
/// `.not` and `.with(timeout:)` return modified copies.
public struct Expectation<K: ElementKind>: Sendable {
    public let locator: Locator<K>
    public let timeout: Duration
    public let pollInterval: Duration
    public let isNegated: Bool

    public init(
        locator: Locator<K>,
        timeout: Duration,
        pollInterval: Duration,
        isNegated: Bool
    ) {
        self.locator = locator
        self.timeout = timeout
        self.pollInterval = pollInterval
        self.isNegated = isNegated
    }

    /// Inverts the next matcher's predicate. Chainable.
    public var not: Expectation<K> {
        Expectation(
            locator: locator,
            timeout: timeout,
            pollInterval: pollInterval,
            isNegated: !isNegated
        )
    }

    /// Override the timeout for the next matcher. Chainable.
    public func with(timeout: Duration) -> Expectation<K> {
        Expectation(
            locator: locator,
            timeout: timeout,
            pollInterval: pollInterval,
            isNegated: isNegated
        )
    }
}

// MARK: - Universal matchers

extension Expectation {
    public func toBeVisible(
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try evaluate(
            failureKind: .notVisible,
            file: file,
            line: line
        ) { snapshot in
            guard case let .present(attrs) = snapshot else { return false }
            return attrs.isVisible
        }
    }

    public func toBeHittable(
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try evaluate(
            failureKind: .notHittable,
            file: file,
            line: line
        ) { snapshot in
            guard case let .present(attrs) = snapshot else { return false }
            return attrs.isHittable
        }
    }

    public func toExist(
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try evaluate(
            failureKind: .notExist,
            file: file,
            line: line
        ) { snapshot in
            snapshot.isPresent
        }
    }

    public func toHaveLabel(
        _ expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try evaluate(
            failureKindBuilder: { snapshot in
                .labelMismatch(expected: expected, observed: snapshot.attributes?.label)
            },
            file: file,
            line: line
        ) { snapshot in
            snapshot.attributes?.label == expected
        }
    }

    public func toHaveValue(
        _ expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try evaluate(
            failureKindBuilder: { snapshot in
                .valueMismatch(expected: expected, observed: snapshot.attributes?.value)
            },
            file: file,
            line: line
        ) { snapshot in
            snapshot.attributes?.value == expected
        }
    }

    public func toContainText(
        _ expected: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try evaluate(
            failureKindBuilder: { snapshot in
                let observed = snapshot.attributes?.label ?? snapshot.attributes?.value
                return .textMismatch(expected: expected, observed: observed)
            },
            file: file,
            line: line
        ) { snapshot in
            guard let attrs = snapshot.attributes else { return false }
            if let label = attrs.label, label.contains(expected) { return true }
            if let value = attrs.value, value.contains(expected) { return true }
            return false
        }
    }
}

// MARK: - Kind-specific matchers

extension Expectation where K: ToggleableKind {
    public func toBeOn(
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try evaluate(
            failureKindBuilder: { snapshot in
                .toggleMismatch(expectedOn: true, observedOn: readToggleState(snapshot))
            },
            file: file,
            line: line
        ) { snapshot in
            readToggleState(snapshot) == true
        }
    }

    public func toBeOff(
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try evaluate(
            failureKindBuilder: { snapshot in
                .toggleMismatch(expectedOn: false, observedOn: readToggleState(snapshot))
            },
            file: file,
            line: line
        ) { snapshot in
            readToggleState(snapshot) == false
        }
    }
}

extension Expectation where K: TypingKind {
    public func toBeFocused(
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try evaluate(
            failureKind: .focusMismatch(expectedFocused: true),
            file: file,
            line: line
        ) { snapshot in
            // XCUITest exposes focus via the element's "hasFocus" trait,
            // surfaced through `value` for most controls. Heuristic until
            // we add a dedicated attribute.
            snapshot.attributes?.value == "1"
        }
    }
}

extension Expectation where K: AdjustableKind {
    public func toHaveValue(
        _ expected: Double,
        tolerance: Double = 0.001,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try evaluate(
            failureKindBuilder: { snapshot in
                let observedDouble = snapshot.attributes?.value.flatMap(Double.init)
                return .adjustableMismatch(
                    expected: expected,
                    observed: observedDouble,
                    tolerance: tolerance
                )
            },
            file: file,
            line: line
        ) { snapshot in
            guard
                let stringValue = snapshot.attributes?.value,
                let actual = Double(stringValue)
            else { return false }
            return abs(actual - expected) <= tolerance
        }
    }
}

// MARK: - Evaluation core

extension Expectation {
    /// Evaluate a predicate with a fixed failure-kind.
    fileprivate func evaluate(
        failureKind: LocatorError.Kind,
        file: StaticString,
        line: UInt,
        predicate: @escaping (ElementSnapshot) -> Bool
    ) throws {
        try evaluate(
            failureKindBuilder: { _ in failureKind },
            file: file,
            line: line,
            predicate: predicate
        )
    }

    /// Evaluate a predicate where the failure-kind depends on the last
    /// observed snapshot (e.g. for `*Mismatch` cases that include the
    /// observed value).
    fileprivate func evaluate(
        failureKindBuilder: @escaping (ElementSnapshot) -> LocatorError.Kind,
        file: StaticString,
        line: UInt,
        predicate: @escaping (ElementSnapshot) -> Bool
    ) throws {
        let driver = locator.driver
        let query = locator.query
        let isNegated = self.isNegated
        let start = Date()

        do {
            _ = try syncRetry(
                until: { () -> Bool? in
                    let snapshot = driver.resolve(query)
                    let satisfied = isNegated ? !predicate(snapshot) : predicate(snapshot)
                    return satisfied ? true : nil
                },
                timeout: timeout,
                pollInterval: pollInterval,
                onTimeout: {
                    let observed = driver.resolve(query)
                    let elapsed = Duration.seconds(Date().timeIntervalSince(start))
                    let error = LocatorError(
                        kind: failureKindBuilder(observed),
                        locator: locator.description,
                        observed: observed,
                        elapsed: elapsed,
                        file: file,
                        line: line,
                        isNegated: isNegated,
                        diagnostics: locator.makeDiagnostics(for: observed)
                    )
                    driver.reporter.record(error)
                    throw error
                }
            )
        } catch let locError as LocatorError {
            throw locError
        }
    }
}

/// Read toggle state from a Switch-like element.
///
/// XCUITest reports switch state through `value`: "1" = on, "0" = off.
fileprivate func readToggleState(_ snapshot: ElementSnapshot) -> Bool? {
    guard let value = snapshot.attributes?.value else { return nil }
    switch value {
    case "1", "true", "on": return true
    case "0", "false", "off": return false
    default: return nil
    }
}
