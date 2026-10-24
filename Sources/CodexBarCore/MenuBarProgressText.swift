import Foundation

/// Layout and content options for the composed menu bar progress line.
public struct MenuBarProgressTextOptions: Sendable {
    /// Number of cells in each lane's bar.
    public var width: Int = 10
    /// Character set used for the filled and empty bar cells.
    public var glyphs: MenuBarProgressGlyphSet = .blocks
    /// Information appended after the lanes.
    public var companion: MenuBarProgressCompanion = .percent
    /// Whether the bars and the companion percentage express used quota instead of remaining quota.
    public var showUsed: Bool = false
    /// Optional weekly quota lane, rendered after the session lane as "W <bar>".
    public var weeklyWindow: RateWindow?

    /// - Parameters:
    ///   - width: Number of cells in each lane's bar.
    ///   - glyphs: Character set used for the filled and empty bar cells.
    ///   - companion: Information appended after the lanes.
    ///   - showUsed: Whether the bars and the companion percentage express used quota instead of remaining quota.
    ///   - weeklyWindow: Optional weekly quota lane, rendered after the session lane as "W <bar>".
    public init(
        width: Int = 10,
        glyphs: MenuBarProgressGlyphSet = .blocks,
        companion: MenuBarProgressCompanion = .percent,
        showUsed: Bool = false,
        weeklyWindow: RateWindow? = nil)
    {
        self.width = width
        self.glyphs = glyphs
        self.companion = companion
        self.showUsed = showUsed
        self.weeklyWindow = weeklyWindow
    }
}

/// Extra information appended after the progress bar lanes.
public enum MenuBarProgressCompanion: String, CaseIterable, Sendable {
    /// Bars only; nothing is appended.
    case none
    /// Appends the primary lane percentage, e.g. " · 74%".
    case percent
    /// Appends the reset countdown, e.g. " · ↻ 3h 12m".
    case time
    /// Appends both the percentage and the reset countdown, in that order.
    case percentAndTime

    /// Whether the companion renders the primary lane percentage.
    var showsPercent: Bool {
        self == .percent || self == .percentAndTime
    }

    /// Whether the companion renders the reset countdown.
    var showsTime: Bool {
        self == .time || self == .percentAndTime
    }
}

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

    /// Renders the menu bar progress line: one bar per quota lane, plus optional companion text.
    ///
    /// Each lane bar expresses its window's remaining quota (`showUsed` flips it to the used quota), so an
    /// exhausted lane is an entirely empty bar rather than being dropped. The session lane is prefixed with
    /// its window length label ("5h", "30m", or "S" — mirroring the app-side
    /// `MenuBarDisplayText.sessionWindowLabel`, which `CodexBarCore` cannot reach) and the weekly lane with
    /// "W". `companion` appends percentage and reset text for the primary lane — the session lane when
    /// present, otherwise the weekly lane. The time companion renders only while the primary lane carries a
    /// still-future `resetsAt`; an elapsed or missing reset leaves the bars to speak for themselves. Lanes
    /// whose bar renders empty (a non-positive `width`) are skipped, and callers decide whether to hand over
    /// a synthetic placeholder lane (`RateWindow.measured`).
    ///
    /// - Parameters:
    ///   - session: Session quota lane, or nil when the provider reports no session usage.
    ///   - options: Bar layout and companion configuration.
    ///   - resetTimeCountdown: Whether the time companion is a countdown ("3h 12m"); `false` renders the
    ///     absolute reset time instead.
    ///   - now: Reference instant for countdowns.
    /// - Returns: A single-line menu bar string, or nil when no lane is supplied (or nothing renders).
    public static func text(
        session: RateWindow?,
        options: MenuBarProgressTextOptions,
        resetTimeCountdown: Bool = true,
        now: Date = .init()) -> String?
    {
        guard session != nil || options.weeklyWindow != nil else { return nil }

        var parts: [String] = []
        if let session {
            let bar = self.laneBar(window: session, options: options)
            if !bar.isEmpty {
                parts.append("\(self.sessionWindowLabel(window: session)) \(bar)")
            }
        }
        if let weeklyWindow = options.weeklyWindow {
            let bar = self.laneBar(window: weeklyWindow, options: options)
            if !bar.isEmpty {
                parts.append("W \(bar)")
            }
        }

        let primary = session ?? options.weeklyWindow
        if let primary {
            if options.companion.showsPercent {
                let percent = options.showUsed ? primary.usedPercent : primary.remainingPercent
                parts.append(UsageFormatter.percentString(percent))
            }
            if options.companion.showsTime, let resetsAt = primary.resetsAt, resetsAt > now {
                let description = resetTimeCountdown
                    ? UsageFormatter.resetCountdownDuration(from: resetsAt, now: now)
                    : UsageFormatter.resetDescription(from: resetsAt, now: now)
                parts.append("↻ \(description)")
            }
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    /// The bar for one lane: its remaining quota, or its used quota when `showUsed` is set.
    private static func laneBar(window: RateWindow, options: MenuBarProgressTextOptions) -> String {
        let percent = options.showUsed ? window.usedPercent : window.remainingPercent
        return self.bar(fraction: percent / 100, width: options.width, glyphs: options.glyphs)
    }

    /// Session lane label derived from the window length, replicating the app-side
    /// `MenuBarDisplayText.sessionWindowLabel` semantics (Core must not depend on the app target): whole
    /// hours collapse to "5h", non-hour windows to minutes ("30m", "90m"), and a missing or non-positive
    /// length falls back to "S" for an unnamed session window.
    private static func sessionWindowLabel(window: RateWindow) -> String {
        guard let minutes = window.windowMinutes, minutes > 0 else { return "S" }
        guard minutes.isMultiple(of: 60) else { return "\(minutes)m" }
        return "\(minutes / 60)h"
    }
}
