// ----------------------------------------------------------------------- //
//
// MODULE  : LabeledPercent.swift
//
// PURPOSE : The base menu bar widget that draws a caption above a percent
//
// CREATED : 10/3/2026
//
// ----------------------------------------------------------------------- //

import Cocoa

private let labelFont = NSFont.systemFont(ofSize: 7, weight: .light)
private let valueFont = NSFont.systemFont(ofSize: 12, weight: .regular)
private let defaultWidth: CGFloat = 34

public struct LabeledPercent
{
    let label: String
    let percent: Int
    let tint: NSColor? // Colors both caption and value; nil draws the default colors.
}

public class LabeledPercentWidget: WidgetWrapper
{
    private var percent: Int = 0

    // Creates the widget, showing the config's preview value when previewing.
    internal init(_ type: widget_t, title: String, config: NSDictionary?, preview: Bool)
    {
        if preview
        {
            self.percent = LabeledPercentWidget.previewPercent(config)
        }

        super.init(type, title: title, frame: CGRect(
            x: 0,
            y: Constants.Widget.margin.y,
            width: defaultWidth + (2 * Constants.Widget.margin.x),
            height: Constants.Widget.height - (2 * Constants.Widget.margin.y)
        ))

        self.canDrawConcurrently = true
    }

    required public init?(coder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }

    // Sets the percent to display, redrawing only when it changed.
    public func setValue(_ newValue: Int)
    {
        let updated = self.queue.sync
        { () -> Bool in
            if self.percent == newValue
            {
                return false
            }
            self.percent = newValue
            return true
        }
        if updated
        {
            self.scheduleRedraw()
        }
    }

    // Returns the percent last set, read under the widget's queue.
    internal func currentPercent() -> Int
    {
        return self.queue.sync { self.percent }
    }

    // Marks the widget for redraw on the main thread, coalescing repeated requests.
    internal func scheduleRedraw()
    {
        DispatchQueue.main.async
        {
            self.needsDisplay = true
        }
    }

    // Draws the caption above "<percent>%" and resizes the widget to fit.
    internal func drawLabeledPercent(_ content: LabeledPercent)
    {
        let labelColor = content.tint ?? (isDarkMode ? NSColor.white : NSColor.textColor)
        let valueColor = content.tint ?? NSColor.textColor
        let valueText = "\(content.percent)%"

        let textWidth = max(content.label.widthOfString(usingFont: labelFont), valueText.widthOfString(usingFont: valueFont))
        let width = (textWidth + Constants.Widget.margin.x * 2).roundedUpToNearestTen()
        let innerWidth = width - (Constants.Widget.margin.x * 2)

        NSAttributedString(string: content.label, attributes: [.font: labelFont, .foregroundColor: labelColor])
            .draw(with: CGRect(x: Constants.Widget.margin.x, y: 12, width: innerWidth, height: labelFont.pointSize))
        NSAttributedString(string: valueText, attributes: [.font: valueFont, .foregroundColor: valueColor])
            .draw(with: CGRect(x: Constants.Widget.margin.x, y: 1, width: innerWidth, height: valueFont.pointSize + 1))

        self.setWidth(width)
    }

    // Returns the config's "Preview" > "Value" percent, or 0 when it isn't set.
    private static func previewPercent(_ config: NSDictionary?) -> Int
    {
        let previewConfig = config?["Preview"] as? NSDictionary
        return previewConfig?["Value"] as? Int ?? 0
    }
}
