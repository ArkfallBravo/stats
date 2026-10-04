// ----------------------------------------------------------------------- //
//
// MODULE  : CompressionRatio.swift
//
// PURPOSE : The menu bar widget for the compressed share of pageable memory
//
// CREATED : 10/3/2026
//
// ----------------------------------------------------------------------- //

import Cocoa

/// A menu-bar widget that displays C/(A+C), the ratio the kernel's memory pressure levels test,
/// tinted by the kernel's reported pressure level.
public class CompressionRatioWidget: LabeledPercentWidget
{
    private var pressureLevel: RAMPressure = .normal

    public init(title: String, config: NSDictionary?, preview: Bool = false)
    {
        super.init(.compressionRatio, title: title, config: config, preview: preview)
    }

    required public init?(coder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }

    public override func draw(_ dirtyRect: NSRect)
    {
        super.draw(dirtyRect)

        let level = self.queue.sync { self.pressureLevel }
        self.drawLabeledPercent(LabeledPercent(label: "CMPR", percent: self.currentPercent(), tint: level.alertColor()))
    }

    // Sets the kernel pressure level used to tint the widget.
    public func setPressure(_ newLevel: RAMPressure)
    {
        let updated = self.queue.sync
        { () -> Bool in
            if self.pressureLevel == newLevel
            {
                return false
            }
            self.pressureLevel = newLevel
            return true
        }
        if updated
        {
            self.scheduleRedraw()
        }
    }
}
