#if canImport(XCTest) && (os(iOS) || os(macOS) || os(tvOS) || os(visionOS))

import Foundation
import XCTest
import UITestingCore

/// Base class for UI tests using the `UITesting` library.
///
/// Subclass to inherit:
///   - A configured `XCUIApplication` (`app`) and matching `XCUITestDriver`
///     (`driver`) set up in `setUpWithError`.
///   - `continueAfterFailure = false` for hard-assertion semantics.
///   - Override of `record(_:)` that filters the duplicate `XCTIssue` the
///     runtime emits when a `LocatorError` propagates out of the test
///     method. Without dedup, Xcode would show two markers per failure.
///
/// To enable diagnostic mode, set `failureDiagnostics = .verbose` **before**
/// calling `super.setUpWithError()`, or override `setUpWithError` and assign
/// the property prior to driver construction.
open class UITestingTestCase: XCTestCase {

    public var app: XCUIApplication!
    public var driver: (any Driver)!
    public var failureDiagnostics: FailureDiagnostics = .standard

    private var recordedErrorIDs: Set<UUID> = []

    open override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
        recordedErrorIDs = []

        app = XCUIApplication()
        driver = XCUITestDriver(
            app: app,
            reporter: XCTestFailureReporter(testCase: self),
            diagnostics: failureDiagnostics
        )
    }

    open override func tearDownWithError() throws {
        driver = nil
        app = nil
        recordedErrorIDs = []
        try super.tearDownWithError()
    }

    /// Dedup: the runtime catches a propagated `LocatorError` and records its
    /// own `XCTIssue` for it. We already recorded the better one at the user's
    /// `file:line` from inside the matcher, so we drop the rethrown duplicate.
    open override func record(_ issue: XCTIssue) {
        if let error = issue.associatedError as? LocatorError {
            if !recordedErrorIDs.insert(error.id).inserted {
                return
            }
        }
        super.record(issue)
    }
}

#endif
