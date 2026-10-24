import Foundation
import Testing
@testable import CodexBarCore

struct MenuBarProgressTextTests {
    @Test
    func `half progress fills the first five cells with blocks`() {
        #expect(MenuBarProgressText.bar(fraction: 0.5) == "▓▓▓▓▓░░░░░")
    }

    @Test
    func `zero progress renders an entirely empty bar`() {
        #expect(MenuBarProgressText.bar(fraction: 0) == "░░░░░░░░░░")
    }

    @Test
    func `full progress renders an entirely filled bar`() {
        #expect(MenuBarProgressText.bar(fraction: 1) == "▓▓▓▓▓▓▓▓▓▓")
    }

    @Test
    func `fractions above one clamp to a full bar`() {
        #expect(MenuBarProgressText.bar(fraction: 1.7, width: 4) == "▓▓▓▓")
        #expect(MenuBarProgressText.bar(fraction: 42, width: 4, glyphs: .circles) == "●●●●")
    }

    @Test
    func `negative fractions clamp to an empty bar`() {
        #expect(MenuBarProgressText.bar(fraction: -0.25, width: 6) == "░░░░░░")
        #expect(MenuBarProgressText.bar(fraction: -3, width: 3, glyphs: .squares) == "□□□")
    }

    @Test
    func `every glyph set exposes its documented characters`() {
        #expect(MenuBarProgressGlyphSet.blocks.filled == "▓")
        #expect(MenuBarProgressGlyphSet.blocks.empty == "░")
        #expect(MenuBarProgressGlyphSet.circles.filled == "●")
        #expect(MenuBarProgressGlyphSet.circles.empty == "○")
        #expect(MenuBarProgressGlyphSet.squares.filled == "■")
        #expect(MenuBarProgressGlyphSet.squares.empty == "□")
        #expect(MenuBarProgressGlyphSet.thin.filled == "▰")
        #expect(MenuBarProgressGlyphSet.thin.empty == "▱")
    }

    @Test
    func `each glyph set renders its own filled and empty characters`() {
        #expect(MenuBarProgressText.bar(fraction: 0.5, width: 4, glyphs: .blocks) == "▓▓░░")
        #expect(MenuBarProgressText.bar(fraction: 0.5, width: 4, glyphs: .circles) == "●●○○")
        #expect(MenuBarProgressText.bar(fraction: 0.5, width: 4, glyphs: .squares) == "■■□□")
        #expect(MenuBarProgressText.bar(fraction: 0.5, width: 4, glyphs: .thin) == "▰▰▱▱")
    }

    @Test
    func `glyph sets enumerate in their documented order`() {
        #expect(MenuBarProgressGlyphSet.allCases.map(\.rawValue) == ["blocks", "circles", "squares", "thin"])
    }

    @Test
    func `a one cell wide bar renders a single glyph`() {
        #expect(MenuBarProgressText.bar(fraction: 0.49, width: 1) == "░")
        #expect(MenuBarProgressText.bar(fraction: 0.5, width: 1) == "▓")
        #expect(MenuBarProgressText.bar(fraction: 1, width: 1, glyphs: .thin) == "▰")
    }

    @Test
    func `fraction is scaled by width before rounding`() {
        #expect(MenuBarProgressText.bar(fraction: 0.24, width: 10) == "▓▓░░░░░░░░")
        #expect(MenuBarProgressText.bar(fraction: 0.25, width: 10) == "▓▓▓░░░░░░░")
        #expect(MenuBarProgressText.bar(fraction: 0.16, width: 12) == "▓▓░░░░░░░░░░")
    }

    @Test
    func `non positive widths render an empty string`() {
        #expect(MenuBarProgressText.bar(fraction: 0.5, width: 0).isEmpty)
        #expect(MenuBarProgressText.bar(fraction: 0.5, width: -3).isEmpty)
    }

    @Test
    func `bars always contain exactly the requested width`() {
        for fraction in stride(from: 0.0, through: 1.0, by: 0.01) {
            #expect(MenuBarProgressText.bar(fraction: fraction, width: 7, glyphs: .circles).count == 7)
        }
    }

    // MARK: - Composed session and weekly lanes

    /// Session fixture for the acceptance example: a 5h window with 74% remaining.
    private static func makeSessionWindow(resetsAt: Date? = nil) -> RateWindow {
        RateWindow(usedPercent: 26, windowMinutes: 300, resetsAt: resetsAt, resetDescription: nil)
    }

    /// Weekly fixture for the acceptance example: a 7d window with 20% remaining.
    private static func makeWeeklyWindow() -> RateWindow {
        RateWindow(usedPercent: 80, windowMinutes: 10080, resetsAt: nil, resetDescription: nil)
    }

    @Test
    func `composed text options expose their documented defaults`() {
        let options = MenuBarProgressTextOptions()
        #expect(options.width == 10)
        #expect(options.glyphs == .blocks)
        #expect(options.companion == .percent)
        #expect(options.showUsed == false)
        #expect(options.weeklyWindow == nil)
    }

    @Test
    func `companion options enumerate in their documented order`() {
        #expect(MenuBarProgressCompanion.allCases.map(\.rawValue) == ["none", "percent", "time", "percentAndTime"])
    }

    @Test
    func `session and weekly lanes compose with the default percent companion`() {
        let text = MenuBarProgressText.text(
            session: Self.makeSessionWindow(),
            options: MenuBarProgressTextOptions(weeklyWindow: Self.makeWeeklyWindow()))
        #expect(text == "5h ▓▓▓▓▓▓▓░░░ · W ▓▓░░░░░░░░ · 74%")
    }

    @Test
    func `a missing session renders only the weekly lane`() {
        let weekly = RateWindow(usedPercent: 50, windowMinutes: 10080, resetsAt: nil, resetDescription: nil)
        let text = MenuBarProgressText.text(session: nil, options: MenuBarProgressTextOptions(weeklyWindow: weekly))
        #expect(text == "W ▓▓▓▓▓░░░░░ · 50%")
    }

    @Test
    func `a missing weekly window renders only the session lane`() {
        let text = MenuBarProgressText.text(
            session: Self.makeSessionWindow(),
            options: MenuBarProgressTextOptions(weeklyWindow: nil))
        #expect(text == "5h ▓▓▓▓▓▓▓░░░ · 74%")
    }

    @Test
    func `no lane at all renders nil`() {
        #expect(MenuBarProgressText.text(session: nil, options: MenuBarProgressTextOptions()) == nil)
        #expect(MenuBarProgressText.text(session: nil, options: MenuBarProgressTextOptions(weeklyWindow: nil)) == nil)
    }

    @Test
    func `session lane labels derive from the window length`() {
        let expectations: [(minutes: Int?, label: String)] = [
            (300, "5h"), (30, "30m"), (90, "90m"), (nil, "S"), (0, "S"),
        ]
        for expectation in expectations {
            let window = RateWindow(
                usedPercent: 0, windowMinutes: expectation.minutes, resetsAt: nil, resetDescription: nil)
            let text = MenuBarProgressText.text(
                session: window, options: MenuBarProgressTextOptions(companion: .none))
            #expect(text == "\(expectation.label) ▓▓▓▓▓▓▓▓▓▓")
        }
    }

    @Test
    func `the weekly lane always uses the W label`() {
        let weekly = RateWindow(usedPercent: 0, windowMinutes: 300, resetsAt: nil, resetDescription: nil)
        let text = MenuBarProgressText.text(
            session: nil, options: MenuBarProgressTextOptions(companion: .none, weeklyWindow: weekly))
        #expect(text == "W ▓▓▓▓▓▓▓▓▓▓")
    }

    @Test
    func `the none companion renders bars only`() {
        let text = MenuBarProgressText.text(
            session: Self.makeSessionWindow(),
            options: MenuBarProgressTextOptions(companion: .none, weeklyWindow: Self.makeWeeklyWindow()))
        #expect(text == "5h ▓▓▓▓▓▓▓░░░ · W ▓▓░░░░░░░░")
    }

    @Test
    func `the time companion renders the session countdown`() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let session = Self.makeSessionWindow(resetsAt: now.addingTimeInterval(3 * 3600 + 12 * 60))
        let text = MenuBarProgressText.text(
            session: session, options: MenuBarProgressTextOptions(companion: .time), now: now)
        #expect(text == "5h ▓▓▓▓▓▓▓░░░ · ↻ 3h 12m")
    }

    @Test
    func `the percent and time companions compose in that order`() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let session = Self.makeSessionWindow(resetsAt: now.addingTimeInterval(3 * 3600 + 12 * 60))
        let text = MenuBarProgressText.text(
            session: session,
            options: MenuBarProgressTextOptions(companion: .percentAndTime, weeklyWindow: Self.makeWeeklyWindow()),
            now: now)
        #expect(text == "5h ▓▓▓▓▓▓▓░░░ · W ▓▓░░░░░░░░ · 74% · ↻ 3h 12m")
    }

    @Test
    func `an absolute reset time companion drops the countdown phrasing`() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let session = Self.makeSessionWindow(resetsAt: now.addingTimeInterval(3 * 3600 + 12 * 60))
        let countdown = MenuBarProgressText.text(
            session: session, options: MenuBarProgressTextOptions(companion: .time), now: now)
        let absolute = MenuBarProgressText.text(
            session: session,
            options: MenuBarProgressTextOptions(companion: .time),
            resetTimeCountdown: false,
            now: now)
        #expect(countdown == "5h ▓▓▓▓▓▓▓░░░ · ↻ 3h 12m")
        #expect(absolute?.contains("↻ ") == true)
        #expect(absolute?.hasSuffix("3h 12m") == false)
    }

    @Test
    func `a missing reset time renders no time companion`() {
        let session = Self.makeSessionWindow(resetsAt: nil)
        let text = MenuBarProgressText.text(session: session, options: MenuBarProgressTextOptions(companion: .time))
        #expect(text == "5h ▓▓▓▓▓▓▓░░░")
    }

    @Test
    func `an elapsed reset time renders no time companion`() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        let session = Self.makeSessionWindow(resetsAt: now.addingTimeInterval(-60))
        let text = MenuBarProgressText.text(
            session: session, options: MenuBarProgressTextOptions(companion: .time), now: now)
        #expect(text == "5h ▓▓▓▓▓▓▓░░░")
    }

    @Test
    func `weekly only lanes take the companion from the weekly window`() {
        let weekly = RateWindow(usedPercent: 40, windowMinutes: 10080, resetsAt: nil, resetDescription: nil)
        let text = MenuBarProgressText.text(session: nil, options: MenuBarProgressTextOptions(weeklyWindow: weekly))
        #expect(text == "W ▓▓▓▓▓▓░░░░ · 60%")
    }

    @Test
    func `show used flips the bars and the companion percent`() {
        let text = MenuBarProgressText.text(
            session: Self.makeSessionWindow(),
            options: MenuBarProgressTextOptions(showUsed: true))
        #expect(text == "5h ▓▓▓░░░░░░░ · 26%")
    }

    @Test
    func `width and glyphs propagate to both lanes`() {
        let session = RateWindow(usedPercent: 50, windowMinutes: 300, resetsAt: nil, resetDescription: nil)
        let weekly = RateWindow(usedPercent: 75, windowMinutes: 10080, resetsAt: nil, resetDescription: nil)
        let text = MenuBarProgressText.text(
            session: session,
            options: MenuBarProgressTextOptions(width: 4, glyphs: .circles, companion: .none, weeklyWindow: weekly))
        #expect(text == "5h ●●○○ · W ●○○○")
    }

    @Test
    func `a non positive width drops the lane bars`() {
        let session = Self.makeSessionWindow()
        let options = MenuBarProgressTextOptions(width: 0, companion: .none, weeklyWindow: Self.makeWeeklyWindow())
        #expect(MenuBarProgressText.text(session: session, options: options) == nil)

        let withPercent = MenuBarProgressTextOptions(width: 0, weeklyWindow: Self.makeWeeklyWindow())
        #expect(MenuBarProgressText.text(session: session, options: withPercent) == "74%")
    }

    @Test
    func `an exhausted session lane keeps its entirely empty bar`() {
        let exhausted = RateWindow(usedPercent: 100, windowMinutes: 300, resetsAt: nil, resetDescription: nil)
        let text = MenuBarProgressText.text(session: exhausted, options: MenuBarProgressTextOptions())
        #expect(text == "5h ░░░░░░░░░░ · 0%")
    }

    @Test
    func `an overdrawn session clamps the remaining lane to an empty bar`() {
        let overdrawn = RateWindow(usedPercent: 120, windowMinutes: 300, resetsAt: nil, resetDescription: nil)
        let text = MenuBarProgressText.text(session: overdrawn, options: MenuBarProgressTextOptions())
        #expect(text == "5h ░░░░░░░░░░ · 0%")
    }

    @Test
    func `show used renders an overdrawn session as a full bar with the clamped percent`() {
        let overdrawn = RateWindow(usedPercent: 120, windowMinutes: 300, resetsAt: nil, resetDescription: nil)
        let text = MenuBarProgressText.text(session: overdrawn, options: MenuBarProgressTextOptions(showUsed: true))
        #expect(text == "5h ▓▓▓▓▓▓▓▓▓▓ · 100%")
    }

    @Test
    func `a one cell width renders one cell in each lane`() {
        let exhausted = RateWindow(usedPercent: 100, windowMinutes: 300, resetsAt: nil, resetDescription: nil)
        let unused = RateWindow(usedPercent: 0, windowMinutes: 10080, resetsAt: nil, resetDescription: nil)
        let text = MenuBarProgressText.text(
            session: exhausted, options: MenuBarProgressTextOptions(width: 1, weeklyWindow: unused))
        #expect(text == "5h ░ · W ▓ · 0%")

        let halfUsed = RateWindow(usedPercent: 50, windowMinutes: 300, resetsAt: nil, resetDescription: nil)
        let mostlyUsed = RateWindow(usedPercent: 75, windowMinutes: 10080, resetsAt: nil, resetDescription: nil)
        let rounded = MenuBarProgressText.text(
            session: halfUsed, options: MenuBarProgressTextOptions(width: 1, weeklyWindow: mostlyUsed))
        #expect(rounded == "5h ▓ · W ░ · 50%")
    }
}
