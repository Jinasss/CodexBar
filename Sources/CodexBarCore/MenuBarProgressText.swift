import Foundation

/// Character pairs available for rendering a menu bar progress bar as plain text.
public enum MenuBarProgressGlyphSet: String, CaseIterable, Sendable {
    /// Heavy shade blocks, the densest default ("▓" / "░").
    case blocks
    /// Filled and hollow circles ("●" / "○").
    case circles
    /// Filled and hollow squares ("■" / "□").
    case squares
    /// Slender filled and hollow parallelogram segments ("▰" / "▱").
    case thin

    /// The character drawn for the completed portion of the bar.
    public var filled: Character {
        switch self {
        case .blocks: "▓"
        case .circles: "●"
        case .squares: "■"
        case .thin: "▰"
        }
    }

    /// The character drawn for the remaining portion of the bar.
    public var empty: Character {
        switch self {
        case .blocks: "░"
        case .circles: "○"
        case .squares: "□"
        case .thin: "▱"
        }
    }
}

/// Pure text rendering helpers for the menu bar progress bar display.
public enum MenuBarProgressText {
    /// Renders `fraction` as a single-line progress bar.
    ///
    /// `fraction` is clamped to 0...1, so over- or under-shooting values still produce a valid
    /// bar. The filled cell count is `Int((fraction * Double(width)).rounded())` and the result
    /// always contains exactly `width` glyphs (empty for a non-positive `width`).
    ///
    /// - Parameters:
    ///   - fraction: Completion between 0 and 1; values outside the range are clamped.
    ///   - width: Number of cells in the bar.
    ///   - glyphs: Character set used for the filled and empty cells.
    /// - Returns: A string of exactly `width` glyph characters.
    public static func bar(fraction: Double, width: Int = 10, glyphs: MenuBarProgressGlyphSet = .blocks) -> String {
        guard width > 0 else { return "" }
        let clamped = min(1, max(0, fraction))
        let filledCount = Int((clamped * Double(width)).rounded())
        return String(repeating: glyphs.filled, count: filledCount)
            + String(repeating: glyphs.empty, count: width - filledCount)
    }
}
