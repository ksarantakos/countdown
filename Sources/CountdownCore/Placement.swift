import CoreGraphics

public struct ScreenInfo: Equatable, Sendable {
    public let id: UInt32
    public let name: String
    public let visibleFrame: CGRect

    public init(id: UInt32, name: String, visibleFrame: CGRect) {
        self.id = id
        self.name = name
        self.visibleFrame = visibleFrame
    }
}

/// A widget position relative to the screen it was placed on.
public struct SavedPlacement: Codable, Equatable, Sendable {
    public var screenID: UInt32
    public var screenName: String
    /// Window origin minus the screen's visibleFrame origin.
    public var offsetX: Double
    public var offsetY: Double

    public init(screenID: UInt32, screenName: String, offsetX: Double, offsetY: Double) {
        self.screenID = screenID
        self.screenName = screenName
        self.offsetX = offsetX
        self.offsetY = offsetY
    }
}

public enum Placement {
    public static let defaultMargin: CGFloat = 24

    /// Where the widget should be. `screens.first` is the primary display, used when the saved
    /// screen is gone. The result is always clamped inside a visible frame.
    public static func frame(for size: CGSize, saved: SavedPlacement?, screens: [ScreenInfo]) -> CGRect? {
        guard let primary = screens.first else { return nil }
        guard let saved else {
            let visible = primary.visibleFrame
            let origin = CGPoint(x: visible.maxX - size.width - defaultMargin, y: visible.maxY - size.height - defaultMargin)
            return clamp(CGRect(origin: origin, size: size), into: visible)
        }
        let screen = screens.first { $0.id == saved.screenID }
            ?? screens.first { $0.name == saved.screenName }
            ?? primary
        let visible = screen.visibleFrame
        let origin = CGPoint(x: visible.minX + saved.offsetX, y: visible.minY + saved.offsetY)
        return clamp(CGRect(origin: origin, size: size), into: visible)
    }

    /// Moves `frame` fully inside `bounds`. Oversized frames align to the top-left.
    public static func clamp(_ frame: CGRect, into bounds: CGRect) -> CGRect {
        var result = frame
        result.origin.x = frame.width >= bounds.width
            ? bounds.minX
            : min(max(frame.minX, bounds.minX), bounds.maxX - frame.width)
        result.origin.y = frame.height >= bounds.height
            ? bounds.maxY - frame.height
            : min(max(frame.minY, bounds.minY), bounds.maxY - frame.height)
        return result
    }

    /// The screen showing most of `frame`, else the primary.
    public static func screen(for frame: CGRect, among screens: [ScreenInfo]) -> ScreenInfo? {
        let best = screens.max { area($0.visibleFrame.intersection(frame)) < area($1.visibleFrame.intersection(frame)) }
        if let best, area(best.visibleFrame.intersection(frame)) > 0 { return best }
        return screens.first
    }

    public static func saved(for frame: CGRect, on screen: ScreenInfo) -> SavedPlacement {
        SavedPlacement(
            screenID: screen.id,
            screenName: screen.name,
            offsetX: Double(frame.minX - screen.visibleFrame.minX),
            offsetY: Double(frame.minY - screen.visibleFrame.minY)
        )
    }

    private static func area(_ rect: CGRect) -> CGFloat {
        rect.isNull ? 0 : rect.width * rect.height
    }
}
