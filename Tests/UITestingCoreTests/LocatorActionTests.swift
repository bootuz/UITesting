import Testing
import Foundation
@testable import UITestingCore

@Suite("Locator actions")
struct LocatorActionTests {

    @Test func tap_performsActionOnDriver_whenElementHittable() throws {
        let driver = FakeDriver()
        let screen = TestScreen(driver: driver)
        let locator = screen.button("save")

        driver.script(
            [.present(.init(testID: "save", isVisible: true, isHittable: true))],
            for: locator.query
        )

        try locator.tap()

        #expect(driver.performedActions.count == 1)
        #expect(driver.performedActions.first?.action == .tap)
        #expect(driver.performedActions.first?.query == locator.query)
    }

    @Test func tap_throws_whenElementNeverHittable() {
        let reporter = RecordingFailureReporter()
        let driver = FakeDriver(reporter: reporter)
        let screen = TestScreen(driver: driver)
        let locator = TestScreen.lowTimeoutLocator(screen: screen, testID: "save")

        #expect(throws: LocatorError.self) {
            try locator.tap()
        }
        #expect(reporter.errors.count == 1)
        #expect(reporter.errors.first?.kind == .notExist)
        #expect(driver.performedActions.count == 0)
    }

    @Test func typeText_triggersActionOnTextField() throws {
        let driver = FakeDriver()
        let screen = TestScreen(driver: driver)
        let locator = screen.textField("name")

        driver.script(
            [.present(.init(testID: "name", isVisible: true, isHittable: true))],
            for: locator.query
        )

        try locator.typeText("Hello")

        #expect(driver.performedActions.count == 1)
        guard case let .typeText(text) = driver.performedActions.first?.action else {
            Issue.record("Expected .typeText action")
            return
        }
        #expect(text == "Hello")
    }

    @Test func scrollToVisible_doesNotRequireHittable() throws {
        let driver = FakeDriver()
        let screen = TestScreen(driver: driver)
        let locator = screen.cell(testID: "deepRow")

        driver.script(
            [.present(.init(testID: "deepRow", isVisible: false, isHittable: false))],
            for: locator.query
        )

        try locator.scrollToVisible()
        #expect(driver.performedActions.count == 1)
        #expect(driver.performedActions.first?.action == .scrollToVisible)
    }

    @Test func actionFailedFromDriver_isRecordedAsActionFailedError() {
        let reporter = RecordingFailureReporter()
        let driver = FakeDriver(reporter: reporter)
        let screen = TestScreen(driver: driver)
        let locator = screen.button("save")

        driver.script(
            [.present(.init(testID: "save", isVisible: true, isHittable: true))],
            for: locator.query
        )
        driver.performError = NSError(domain: "test", code: 1)

        #expect(throws: LocatorError.self) {
            try locator.tap()
        }
        let kind = reporter.errors.first?.kind
        if case .actionFailed = kind {
            // ok
        } else {
            Issue.record("Expected .actionFailed, got \(String(describing: kind))")
        }
    }
}

private struct TestScreen: Screen {
    let driver: any Driver

    static func lowTimeoutLocator(screen: TestScreen, testID: String) -> Locator<Button> {
        let base = screen.button(testID)
        var policy = TimeoutPolicy()
        policy.action = .milliseconds(100)
        policy.pollInterval = .milliseconds(20)
        return Locator<Button>(
            driver: base.driver,
            query: base.query,
            timeoutPolicy: policy,
            description: base.description
        )
    }
}
