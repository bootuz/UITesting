import Foundation

/// A lazy, type-safe description of an element to find.
///
/// `Locator` holds a `Driver` reference, an `ElementQuery` describing the
/// path through the element tree, and a `TimeoutPolicy`. Every action or
/// matcher re-resolves the query through the driver — there is no cached
/// element. Compose locators via `first()`, `nth(_:)`, `descendant(_:)`,
/// and `filter(_:)`; actions are gated by capability protocols so
/// type-incompatible combinations (e.g. `.typeText` on a static text) fail
/// to compile.
public struct Locator<Kind: ElementKind>: Sendable {
    public let driver: any Driver
    public let query: ElementQuery
    public let timeoutPolicy: TimeoutPolicy
    public let description: LocatorDescription

    public init(
        driver: any Driver,
        query: ElementQuery,
        timeoutPolicy: TimeoutPolicy,
        description: LocatorDescription
    ) {
        self.driver = driver
        self.query = query
        self.timeoutPolicy = timeoutPolicy
        self.description = description
    }

    // MARK: - Composition

    public func first() -> Locator<Kind> {
        Locator(
            driver: driver,
            query: query.appending(.first),
            timeoutPolicy: timeoutPolicy,
            description: LocatorDescription(path: "\(description.path) › first")
        )
    }

    public func nth(_ index: Int) -> Locator<Kind> {
        Locator(
            driver: driver,
            query: query.appending(.nth(index)),
            timeoutPolicy: timeoutPolicy,
            description: LocatorDescription(path: "\(description.path) › nth(\(index))")
        )
    }

    public func filter(_ predicate: LocatorPredicate) -> Locator<Kind> {
        Locator(
            driver: driver,
            query: query.appending(.filter(predicate)),
            timeoutPolicy: timeoutPolicy,
            description: LocatorDescription(path: "\(description.path) › filter(\(predicate.descriptor))")
        )
    }

    public func descendant<K2: ElementKind>(_ child: Locator<K2>) -> Locator<K2> {
        Locator<K2>(
            driver: driver,
            query: query.appending(.descendant(child.query)),
            timeoutPolicy: timeoutPolicy,
            description: LocatorDescription(path: "\(description.path) › \(child.description.path)")
        )
    }

    // MARK: - Fast probes (no auto-wait)

    /// Immediate, non-blocking existence check. Use for branching on optional
    /// UI presence. For "wait until exists or fail", use
    /// `expect(...).toExist()` or any action — both auto-wait.
    public func exists() -> Bool {
        driver.resolve(query).isPresent
    }

    /// Immediate snapshot. Use sparingly — most reads should go through the
    /// matcher engine which polls.
    public func snapshot() -> ElementSnapshot {
        driver.resolve(query)
    }
}

// MARK: - Internal action plumbing

extension Locator {
    /// Shared auto-wait body for sync actions: wait for actionability, then
    /// perform the action. On timeout, records a `LocatorError` with the
    /// captured source location.
    func performWithAutoWait(
        _ action: ElementAction,
        requireHittable: Bool = true,
        file: StaticString,
        line: UInt
    ) throws {
        let start = Date()
        do {
            _ = try syncRetry(
                until: { () throws -> Bool? in
                    let snapshot = driver.resolve(query)
                    guard case let .present(attrs) = snapshot else { return nil }
                    if requireHittable && !attrs.isHittable { return nil }
                    return true
                },
                timeout: timeoutPolicy.action,
                pollInterval: timeoutPolicy.pollInterval,
                onTimeout: {
                    let observed = driver.resolve(query)
                    let elapsed = Duration.seconds(Date().timeIntervalSince(start))
                    let kind: LocatorError.Kind = {
                        switch observed {
                        case .missing: return .notExist
                        case .present: return requireHittable ? .notHittable : .timeout
                        }
                    }()
                    let diagnostics = makeDiagnostics(for: observed)
                    let error = LocatorError(
                        kind: kind,
                        locator: description,
                        observed: observed,
                        elapsed: elapsed,
                        file: file,
                        line: line,
                        diagnostics: diagnostics
                    )
                    driver.reporter.record(error)
                    throw error
                }
            )
        } catch {
            // Re-throw — recorder already received the error inside onTimeout.
            throw error
        }

        do {
            try driver.perform(action, on: query)
        } catch {
            let elapsed = Duration.seconds(Date().timeIntervalSince(start))
            let observed = driver.resolve(query)
            let locError = LocatorError(
                kind: .actionFailed(String(describing: error)),
                locator: description,
                observed: observed,
                elapsed: elapsed,
                file: file,
                line: line,
                diagnostics: makeDiagnostics(for: observed)
            )
            driver.reporter.record(locError)
            throw locError
        }
    }

    /// Builds `DiagnosticInfo` when the driver is in verbose mode.
    func makeDiagnostics(for observed: ElementSnapshot) -> LocatorError.DiagnosticInfo? {
        guard driver.diagnostics == .verbose else { return nil }
        let candidates = driver.enumerate(kind: Kind.tag)
        let closest = closestTestIDMatch(candidates: candidates, target: targetTestID())
        return LocatorError.DiagnosticInfo(candidates: candidates, closestMatch: closest)
    }

    /// Extract a test-ID hint from the query (heuristic — used only for
    /// "did you mean" suggestions, not correctness).
    func targetTestID() -> String? {
        for step in query.steps.reversed() {
            if case let .byTestID(id) = step { return id }
        }
        return nil
    }

    func closestTestIDMatch(
        candidates: [ElementAttributes],
        target: String?
    ) -> ElementAttributes? {
        guard let target else { return nil }
        var best: (attrs: ElementAttributes, distance: Int)?
        for attrs in candidates {
            guard let id = attrs.testID else { continue }
            let distance = levenshteinDistance(id, target)
            if best == nil || distance < best!.distance {
                best = (attrs, distance)
            }
        }
        return best?.attrs
    }

    private func levenshteinDistance(_ a: String, _ b: String) -> Int {
        let aChars = Array(a)
        let bChars = Array(b)
        if aChars.isEmpty { return bChars.count }
        if bChars.isEmpty { return aChars.count }

        var prev = Array(0...bChars.count)
        var curr = [Int](repeating: 0, count: bChars.count + 1)

        for i in 1...aChars.count {
            curr[0] = i
            for j in 1...bChars.count {
                let cost = aChars[i - 1] == bChars[j - 1] ? 0 : 1
                curr[j] = min(
                    curr[j - 1] + 1,        // insertion
                    prev[j] + 1,            // deletion
                    prev[j - 1] + cost      // substitution
                )
            }
            swap(&prev, &curr)
        }
        return prev[bChars.count]
    }
}

// MARK: - Capability-gated actions

extension Locator where Kind: TappableKind {
    public func tap(file: StaticString = #filePath, line: UInt = #line) throws {
        try performWithAutoWait(.tap, file: file, line: line)
    }

    public func doubleTap(file: StaticString = #filePath, line: UInt = #line) throws {
        try performWithAutoWait(.doubleTap, file: file, line: line)
    }

    public func longPress(
        duration: Duration = .seconds(0.5),
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try performWithAutoWait(.longPress(duration: duration), file: file, line: line)
    }
}

extension Locator where Kind: TypingKind {
    public func typeText(
        _ text: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try performWithAutoWait(.typeText(text), file: file, line: line)
    }

    public func clearText(file: StaticString = #filePath, line: UInt = #line) throws {
        try performWithAutoWait(.clearText, file: file, line: line)
    }
}

extension Locator where Kind: ToggleableKind {
    public func setOn(file: StaticString = #filePath, line: UInt = #line) throws {
        try performWithAutoWait(.setSwitch(on: true), file: file, line: line)
    }

    public func setOff(file: StaticString = #filePath, line: UInt = #line) throws {
        try performWithAutoWait(.setSwitch(on: false), file: file, line: line)
    }
}

extension Locator where Kind: SwipeableKind {
    public func swipe(
        _ direction: SwipeDirection,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try performWithAutoWait(.swipe(direction), file: file, line: line)
    }
}

extension Locator where Kind: ScrollableKind {
    public func scrollToVisible(
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        // Scroll doesn't require hittability — we're scrolling to *make* it visible.
        try performWithAutoWait(.scrollToVisible, requireHittable: false, file: file, line: line)
    }
}

extension Locator where Kind: AdjustableKind {
    public func setValue(
        _ value: Double,
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try performWithAutoWait(.setSliderValue(value), file: file, line: line)
    }
}

extension Locator where Kind: KeyInputKind {
    public func pressKey(
        _ key: Key,
        modifiers: KeyModifiers = [],
        file: StaticString = #filePath,
        line: UInt = #line
    ) throws {
        try performWithAutoWait(.pressKey(key, modifiers: modifiers), file: file, line: line)
    }
}
