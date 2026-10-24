import Foundation

/// Controls what the menu bar displays when brand icon mode is enabled.
enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
    case percent
    case pace
    case both
    case resetTime
    case progressBar

    var id: String {
        self.rawValue
    }

    var label: String {
        switch self {
        case .percent: L("display_mode_percent")
        case .pace: L("display_mode_pace")
        case .both: L("display_mode_both")
        case .resetTime: L("display_mode_reset_time")
        case .progressBar: L("display_mode_progress_bar")
        }
    }

    var description: String {
        switch self {
        case .percent: L("display_mode_percent_desc")
        case .pace: L("display_mode_pace_desc")
        case .both: L("display_mode_both_desc")
        case .resetTime: L("display_mode_reset_time_desc")
        case .progressBar: L("display_mode_progress_bar_desc")
        }
    }
}
