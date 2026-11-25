// ----------------------------------------------------------------------- //
//
// MODULE  : HistoryPalette.swift
//
// PURPOSE : Colors shared by the RAM popup's history charts
//
// CREATED : 10/9/2026
//
// ----------------------------------------------------------------------- //

import Cocoa
import Kit

// One OKHSL saturation and lightness for every default history color, so no hue outweighs another.
private let historySaturation: Double = 0.85
private let historyLightness: Double = 0.65
private let historyDefaultKey: String = "okhslDefault"

// Returns a color with its own OKHSL hue at the shared history saturation and lightness.
private func historyTone(_ color: NSColor) -> NSColor
{
    var okhsl = OKHSL(color)
    okhsl.saturation = historySaturation
    okhsl.lightness = historyLightness
    return okhsl.color
}

// A user-pickable color in the history charts.
internal enum HistoryRole: String, CaseIterable
{
    case normal
    case warning
    case critical
    case usage

    // Returns the system color whose hue the default is built from.
    var systemColor: NSColor
    {
        switch self
        {
        case .normal: return NSColor.systemGreen
        case .warning: return NSColor.systemYellow
        case .critical: return NSColor.systemRed
        case .usage: return NSColor.systemBlue
        }
    }

    // Returns the settings row title.
    var title: String
    {
        switch self
        {
        case .normal: return localizedString("Normal pressure color")
        case .warning: return localizedString("Warning pressure color")
        case .critical: return localizedString("Critical pressure color")
        case .usage: return localizedString("Combined usage color")
        }
    }

    // Returns the Store key holding the picked color.
    func storeKey(_ module: String) -> String
    {
        return "\(module)_history_\(self.rawValue)Color"
    }

    // Returns the dropdown entry that keeps the OKHSL default color.
    var defaultColor: SColor
    {
        return SColor.named(key: historyDefaultKey, value: "Default", color: historyTone(self.systemColor))
    }

    // Returns the dropdown entries: the OKHSL default, then every built-in color.
    var menuItems: [SColor]
    {
        return [self.defaultColor, SColor.separator2] + SColor.allColors
    }
}

// Returns the picked color drawn as-is, or nil when the pick is the OKHSL default.
internal func historyOverride(_ pick: SColor) -> NSColor?
{
    if pick.key == historyDefaultKey
    {
        return nil
    }
    return pick.additional as? NSColor
}

internal struct HistoryPalette
{
    private let colors: [HistoryRole: NSColor]

    // Resolves defaults under the current drawing appearance; overrides are drawn as picked.
    init(_ overrides: [HistoryRole: NSColor])
    {
        self.colors = Dictionary(uniqueKeysWithValues: HistoryRole.allCases.map
        { role in
            (role, overrides[role] ?? historyTone(role.systemColor))
        })
    }

    // Returns the picked color for a role, or its OKHSL default.
    func color(_ role: HistoryRole) -> NSColor
    {
        return self.colors[role] ?? role.systemColor
    }

    // Returns the color for a kernel memory pressure level (1 normal, 2 warning, 4 critical).
    func levelColor(_ level: Int) -> NSColor
    {
        switch level
        {
        case 2: return self.color(.warning)
        case 4: return self.color(.critical)
        default: return self.color(.normal)
        }
    }
}
