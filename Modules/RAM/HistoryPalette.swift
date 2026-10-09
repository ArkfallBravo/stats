// ----------------------------------------------------------------------- //
//
// MODULE  : HistoryPalette.swift
//
// PURPOSE : OKHSL colors shared by the RAM popup's history charts
//
// CREATED : 10/9/2026
//
// ----------------------------------------------------------------------- //

import Cocoa
import Kit

// One OKHSL saturation and lightness for every history color, so no hue outweighs another.
private let historySaturation: Double = 0.85
private let historyLightness: Double = 0.65

// Returns a color with its own OKHSL hue at the shared history saturation and lightness.
private func historyTone(_ color: NSColor) -> NSColor
{
    var okhsl = OKHSL(color)
    okhsl.saturation = historySaturation
    okhsl.lightness = historyLightness
    return okhsl.color
}

internal struct HistoryPalette
{
    let normal: NSColor
    let warning: NSColor
    let critical: NSColor
    let usage: NSColor

    // Takes the system hues as resolved under the current drawing appearance.
    init()
    {
        self.normal = historyTone(NSColor.systemGreen)
        self.warning = historyTone(NSColor.systemYellow)
        self.critical = historyTone(NSColor.systemRed)
        self.usage = historyTone(NSColor.systemBlue)
    }

    // Returns the color for a kernel memory pressure level (1 normal, 2 warning, 4 critical).
    func levelColor(_ level: Int) -> NSColor
    {
        switch level
        {
        case 2: return self.warning
        case 4: return self.critical
        default: return self.normal
        }
    }
}
