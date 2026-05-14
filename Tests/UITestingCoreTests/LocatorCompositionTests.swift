import Testing
@testable import UITestingCore

@Suite("Locator composition")
struct LocatorCompositionTests {

    @Test func button_factoryProducesByAccIDQuery() {
        let driver = FakeDriver()
        let screen = TestScreen(driver: driver)

        let locator = screen.button("save")

        #expect(locator.query.steps == [
            .byKind(.button),
            .byAccID("save")
        ])
        #expect(locator.description.path == "button(accID: \"save\")")
    }

    @Test func buttonByLabel_factoryProducesByLabelQuery() {
        let driver = FakeDriver()
        let screen = TestScreen(driver: driver)

        let locator = screen.button(label: "Save")

        #expect(locator.query.steps == [
            .byKind(.button),
            .byLabel("Save")
        ])
    }

    @Test func text_factoryProducesByTextQuery() {
        let driver = FakeDriver()
        let screen = TestScreen(driver: driver)

        let locator = screen.text("Hello")

        #expect(locator.query.steps == [
            .byKind(.staticText),
            .byText("Hello")
        ])
    }

    @Test func first_appendsFirstStep() {
        let driver = FakeDriver()
        let screen = TestScreen(driver: driver)

        let locator = screen.button("save").first()

        #expect(locator.query.steps == [
            .byKind(.button),
            .byAccID("save"),
            .first
        ])
    }

    @Test func nth_appendsNthStep() {
        let driver = FakeDriver()
        let screen = TestScreen(driver: driver)

        let locator = screen.cell(accID: "row").nth(3)

        #expect(locator.query.steps == [
            .byKind(.cell),
            .byAccID("row"),
            .nth(3)
        ])
    }

    @Test func descendant_combinesQueriesAndDescription() {
        let driver = FakeDriver()
        let screen = TestScreen(driver: driver)

        let parent = screen.cell(accID: "deckCell")
        let child = screen.button("delete")
        let combined = parent.descendant(child)

        #expect(combined.query.steps == [
            .byKind(.cell),
            .byAccID("deckCell"),
            .descendant(child.query)
        ])
        #expect(combined.description.path.contains("deckCell"))
        #expect(combined.description.path.contains("delete"))
    }

    @Test func exists_returnsTrueWhenDriverResolvesPresent() {
        let driver = FakeDriver()
        let screen = TestScreen(driver: driver)
        let locator = screen.button("save")

        driver.script([.present(.init(accID: "save"))], for: locator.query)

        #expect(locator.exists())
    }

    @Test func exists_returnsFalseWhenMissing() {
        let driver = FakeDriver()
        let screen = TestScreen(driver: driver)
        let locator = screen.button("save")

        #expect(!locator.exists())
    }
}

private struct TestScreen: Screen {
    let driver: any Driver
}
