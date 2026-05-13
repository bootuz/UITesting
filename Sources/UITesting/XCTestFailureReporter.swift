#if canImport(XCTest) && (os(iOS) || os(macOS) || os(tvOS) || os(visionOS))

import Foundation
import XCTest
import UITestingCore

/// `FailureReporter` that records `LocatorError`s as `XCTIssue`s on the
/// owning test case.
///
/// The reporter uses the captured `file`/`line` from the error to anchor
/// the failure marker to the user's source location in Xcode. Holds the
/// test case weakly to avoid reference cycles.
public final class XCTestFailureReporter: FailureReporter, @unchecked Sendable {
    private weak var testCase: XCTestCase?

    public init(testCase: XCTestCase) {
        self.testCase = testCase
    }

    public func record(_ error: LocatorError) {
        guard let testCase else { return }
        let filePath = String(describing: error.file)
        let location = XCTSourceCodeLocation(
            filePath: filePath,
            lineNumber: Int(error.line)
        )
        var issue = XCTIssue(
            type: .assertionFailure,
            compactDescription: error.description
        )
        issue.sourceCodeContext = XCTSourceCodeContext(location: location)
        issue.associatedError = error
        testCase.record(issue)
    }
}

#endif
