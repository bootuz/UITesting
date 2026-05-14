import CoreGraphics

/// The result of a `Driver.resolve(_:)` call at a single tick in time.
public enum ElementSnapshot: Sendable, Equatable {
    case missing
    case present(ElementAttributes)

    public var isPresent: Bool {
        if case .present = self { return true }
        return false
    }

    public var attributes: ElementAttributes? {
        if case let .present(attrs) = self { return attrs }
        return nil
    }
}

/// Attributes read from an element in a single resolve pass.
///
/// New fields can be added without breaking existing `Driver` implementations
/// as long as they have safe defaults — this struct is intentionally a
/// value type with public letting so consumers can construct test fixtures.
public struct ElementAttributes: Sendable, Equatable {
    public let accID: String?
    public let label: String?
    public let value: String?
    public let isVisible: Bool
    public let isHittable: Bool
    public let frame: CGRect
    public let elementType: ElementKindTag

    public init(
        accID: String? = nil,
        label: String? = nil,
        value: String? = nil,
        isVisible: Bool = false,
        isHittable: Bool = false,
        frame: CGRect = .zero,
        elementType: ElementKindTag = .anyElement
    ) {
        self.accID = accID
        self.label = label
        self.value = value
        self.isVisible = isVisible
        self.isHittable = isHittable
        self.frame = frame
        self.elementType = elementType
    }
}
