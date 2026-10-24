import CodexBarCore
import Foundation
import Testing
@testable import CodexBar

/// `MenuBarDisplayText.displayText` progress-bar coverage: the branch delegates bar shape to the Core
/// renderer (`MenuBarProgressText`) while quota semantics (`showUsed`, the weekly lane, the
/// exhausted-smart-reset branch and the estimate marker) stay owned by the call site parameters.
struct MenuBarProgressDisplayTests {
    /// The acceptance fixture: a 5h session window with 74% remaining.
    private static func sessionWindow(usedPercent: Double, resetsAt: Date? = nil) -> RateWindow {
        RateWindow(usedPercent: usedPercent, windowMinutes: 300, resetsAt: resetsAt, resetDescription: nil)
    }

    private static func weeklyWindow(usedPercent: Double) -> RateWindow {
        RateWindow(usedPercent: usedPercent, windowMinutes: 10080, resetsAt: nil, resetDescription: nil)
    }

    @Test
    func `progress bar mode renders the session lane bar with its percent companion`() {
        #expect(MenuBarDisplayText.displayText(
            mode: .progressBar,
            percentWindow: Self.sessionWindow(usedPercent: 26),
            showUsed: false) == "5h ▓▓▓▓▓▓▓░░░ · 74%")
    }

    @Test
    func `progress bar mode falls back to nil percent text without any lane`() {
        #expect(MenuBarDisplayText.displayText(mode: .progressBar, percentWindow: nil, showUsed: false) == nil)
    }

    @Test
    func `progress bar mode appends the weekly lane after the session lane`() {
        let text = MenuBarDisplayText.displayText(
            mode: .progressBar,
            percentWindow: Self.sessionWindow(usedPercent: 26),
            weeklyWindow: Self.weeklyWindow(usedPercent: 80),
            showUsed: false)
        #expect(text == "5h ▓▓▓▓▓▓▓░░░ · W ▓▓░░░░░░░░ · 74%")

        // Without a session lane the weekly lane becomes the primary and takes the companion percent.
        let weeklyOnly = MenuBarDisplayText.displayText(
            mode: .progressBar,
            percentWindow: nil,
            weeklyWindow: Self.weeklyWindow(usedPercent: 80),
            showUsed: false)
        #expect(weeklyOnly == "W ▓▓░░░░░░░░ · 20%")
    }

    @Test
    func `progress bar mode follows custom width glyphs and companion`() {
        let narrow = MenuBarDisplayText.displayText(
            mode: .progressBar,
            percentWindow: Self.sessionWindow(usedPercent: 26),
            progressOptions: MenuBarProgressTextOptions(width: 4, glyphs: .circles),
            showUsed: false)
        #expect(narrow == "5h ●●●○ · 74%")

        let barOnly = MenuBarDisplayText.displayText(
            mode: .progressBar,
            percentWindow: Self.sessionWindow(usedPercent: 26),
            progressOptions: MenuBarProgressTextOptions(width: 4, glyphs: .squares, companion: .none),
            showUsed: false)
        #expect(barOnly == "5h ■■■□")

        // The time companion keeps its live countdown for the primary lane.
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let countdown = MenuBarDisplayText.displayText(
            mode: .progressBar,
            percentWindow: Self.sessionWindow(usedPercent: 26, resetsAt: now.addingTimeInterval(3 * 3600 + 12 * 60)),
            progressOptions: MenuBarProgressTextOptions(companion: .time),
            showUsed: false,
            now: now)
        #expect(countdown == "5h ▓▓▓▓▓▓▓░░░ · ↻ 3h 12m")
    }

    @Test
    func `progress bar mode takes show used from the call site instead of the options`() {
        let window = Self.sessionWindow(usedPercent: 26)
        // Bar shape comes from settings via progressOptions, quota semantics stay with the call site, so a
        // stale showUsed captured inside the options must not win over the displayText parameter.
        let staleOptions = MenuBarProgressTextOptions(showUsed: true)
        #expect(MenuBarDisplayText.displayText(
            mode: .progressBar,
            percentWindow: window,
            progressOptions: staleOptions,
            showUsed: false) == "5h ▓▓▓▓▓▓▓░░░ · 74%")
        #expect(MenuBarDisplayText.displayText(
            mode: .progressBar,
            percentWindow: window,
            progressOptions: MenuBarProgressTextOptions(showUsed: false),
            showUsed: true) == "5h ▓▓▓░░░░░░░ · 26%")
    }

    @Test
    func `progress bar mode replaces an exhausted quota with the smart reset`() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let resetsAt = now.addingTimeInterval(2 * 3600 + 15 * 60)
        let window = Self.sessionWindow(usedPercent: 100, resetsAt: resetsAt)

        let countdown = MenuBarDisplayText.displayText(
            mode: .progressBar,
            percentWindow: window,
            showUsed: false,
            resetTimeDisplayStyle: .countdown,
            showsResetTimeWhenExhausted: true,
            now: now)
        #expect(countdown == "↻ in 2h 15m")

        let absolute = MenuBarDisplayText.displayText(
            mode: .progressBar,
            percentWindow: window,
            showUsed: false,
            resetTimeDisplayStyle: .absolute,
            showsResetTimeWhenExhausted: true,
            now: now)
        #expect(absolute == "↻ \(UsageFormatter.resetDescription(from: resetsAt, now: now))")
    }

    @Test
    func `progress bar mode keeps the entirely empty bar when the smart reset is disabled`() {
        #expect(MenuBarDisplayText.displayText(
            mode: .progressBar,
            percentWindow: Self.sessionWindow(usedPercent: 100),
            showUsed: false) == "5h ░░░░░░░░░░ · 0%")
    }

    @Test
    func `progress bar mode falls back to the percent text when the exhausted reset is unusable`() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        // An already elapsed reset cannot be scheduled, so the smart branch keeps the quota signal and never
        // reaches the bar rendering.
        let elapsed = Self.sessionWindow(usedPercent: 100, resetsAt: now.addingTimeInterval(-60))
        #expect(MenuBarDisplayText.displayText(
            mode: .progressBar,
            percentWindow: elapsed,
            showUsed: false,
            resetTimeDisplayStyle: .countdown,
            showsResetTimeWhenExhausted: true,
            now: now) == "0%")

        // Textual reset metadata alone is not schedulable either.
        let textual = RateWindow(usedPercent: 100, windowMinutes: 300, resetsAt: nil, resetDescription: "in 2h")
        #expect(MenuBarDisplayText.displayText(
            mode: .progressBar,
            percentWindow: textual,
            showUsed: false,
            showsResetTimeWhenExhausted: true) == "0%")
    }

    @Test
    func `estimated quota keeps the tilde in percent mode and leaves the bar text unmarked`() {
        let window = Self.sessionWindow(usedPercent: 26)
        #expect(MenuBarDisplayText.displayText(
            mode: .percent,
            percentWindow: window,
            showUsed: false,
            estimated: true) == "~74%")
        // The bar text carries no estimate marker today: the renderer conveys "~" through the accessibility
        // label, and a bar-level prefix is a deferred follow-up. This pins the current contract.
        #expect(MenuBarDisplayText.displayText(
            mode: .progressBar,
            percentWindow: window,
            showUsed: false,
            estimated: true) == "5h ▓▓▓▓▓▓▓░░░ · 74%")
    }
}
