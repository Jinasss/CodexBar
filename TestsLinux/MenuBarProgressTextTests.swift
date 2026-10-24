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
}
