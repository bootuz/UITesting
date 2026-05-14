import Testing
@testable import UITestingCore

@Suite("expect matchers")
struct ExpectMatcherTests {

    @Test func toBeVisible_succeedsImmediately_whenAttributeMatches() throws {
        let reporter = RecordingFailureReporter()
        let driver = FakeDriver(reporter: reporter)
        let screen = TestScreen(driver: driver)
        let locator = screen.button("save")

        driver.script(
            [.present(.init(accID: "save", isVisible: true, isHittable: true))],
            for: locator.query
        )

        try expect(locator)
            .with(timeout: .milliseconds(100))
            .toBeVisible()
        #expect(reporter.errors.isEmpty)
    }

    @Test func toBeVisible_throwsAndRecords_whenPredicateNeverSatisfied() {
        let reporter = RecordingFailureReporter()
        let driver = FakeDriver(reporter: reporter)
        let screen = TestScreen(driver: driver)
        let locator = screen.button("save")

        #expect(throws: LocatorError.self) {
            try expect(locator)
                .with(timeout: .milliseconds(100))
                .toBeVisible()
        }
        #expect(reporter.errors.count == 1)
        #expect(reporter.errors.first?.kind == .notVisible)
    }

    @Test func not_invertsPredicate() throws {
        let reporter = RecordingFailureReporter()
        let driver = FakeDriver(reporter: reporter)
        let screen = TestScreen(driver: driver)
        let locator = screen.button("save")

        // Element is missing => .not.toBeVisible() should succeed
        try expect(locator)
            .with(timeout: .milliseconds(50))
            .not
            .toBeVisible()
    }

    @Test func toHaveLabel_matchesAttributeValue() throws {
        let driver = FakeDriver()
        let screen = TestScreen(driver: driver)
        let locator = screen.button("save")

        driver.script(
            [.present(.init(accID: "save", label: "Save"))],
            for: locator.query
        )

        try expect(locator)
            .with(timeout: .milliseconds(100))
            .toHaveLabel("Save")
    }

    @Test func toHaveLabel_reportsMismatch_withObservedValue() {
        let reporter = RecordingFailureReporter()
        let driver = FakeDriver(reporter: reporter)
        let screen = TestScreen(driver: driver)
        let locator = screen.button("save")

        driver.script(
            [.present(.init(accID: "save", label: "Submit"))],
            for: locator.query
        )

        #expect(throws: LocatorError.self) {
            try expect(locator)
                .with(timeout: .milliseconds(50))
                .toHaveLabel("Save")
        }

        let firstError = reporter.errors.first
        guard case let .labelMismatch(expected, observed) = firstError?.kind else {
            Issue.record("Expected labelMismatch, got \(String(describing: firstError?.kind))")
            return
        }
        #expect(expected == "Save")
        #expect(observed == "Submit")
    }

    @Test func capturesFileAndLineForUserCallSite() {
        let reporter = RecordingFailureReporter()
        let driver = FakeDriver(reporter: reporter)
        let screen = TestScreen(driver: driver)
        let locator = screen.button("save")

        let expectedLine: UInt = #line + 4
        #expect(throws: LocatorError.self) {
            try expect(locator)
                .with(timeout: .milliseconds(50))
                .toBeVisible(
                    line: expectedLine
                )
        }
        #expect(reporter.errors.first?.line == expectedLine)
    }
}

private struct TestScreen: Screen {
    let driver: any Driver
}
