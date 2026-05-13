import Foundation

/// A serializable description of a path through the element tree.
///
/// `Locator` composition produces longer queries; `Driver` translates them
/// into native queries at resolve time. Always describes a *path*, never
/// caches a resolved element — that's what makes locators "lazy."
public struct ElementQuery: Sendable, Hashable {
    public let steps: [Step]

    public init(steps: [Step]) {
        self.steps = steps
    }

    public func appending(_ step: Step) -> ElementQuery {
        ElementQuery(steps: steps + [step])
    }

    /// A single step in the query path.
    public indirect enum Step: Sendable, Hashable {
        case byTestID(String)
        case byLabel(String)
        case byText(String)
        case byKind(ElementKindTag)
        case descendant(ElementQuery)
        case first
        case nth(Int)
        case filter(LocatorPredicate)
    }
}

/// A predicate evaluated by the `Driver` during query resolution.
///
/// `NSPredicate` is used as the initial backing format because every Driver
/// we currently care about (XCUITest) speaks it natively. `LocatorPredicate`
/// wraps it so we can change the representation later without an API break.
///
/// `@unchecked Sendable`: `NSPredicate` is not Sendable, but the wrapped
/// instance is treated as immutable after init. UI tests are single-threaded.
public struct LocatorPredicate: @unchecked Sendable, Hashable {
    public let nsPredicate: NSPredicate
    public let descriptor: String

    public init(_ nsPredicate: NSPredicate, descriptor: String) {
        self.nsPredicate = nsPredicate
        self.descriptor = descriptor
    }

    public static func == (lhs: LocatorPredicate, rhs: LocatorPredicate) -> Bool {
        lhs.descriptor == rhs.descriptor
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(descriptor)
    }
}
