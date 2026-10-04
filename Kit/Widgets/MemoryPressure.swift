// ----------------------------------------------------------------------- //
//
// MODULE  : MemoryPressure.swift
//
// PURPOSE : The menu bar widget for memory pressure or memory headroom
//
// CREATED : 5/27/2026
//
// ----------------------------------------------------------------------- //

import Cocoa

/// A menu-bar widget that displays either memory pressure or memory headroom.
///
/// - Pressure mode  (`displayMode == "pressure"`): shows `100 - kern.memorystatus_level`
///   — the proportion of memory under pressure (0 = none, 100 = full).
/// - Headroom mode (`displayMode == "headroom"`): shows `kern.memorystatus_level`
///   — the available memory headroom (0 = none, 100 = fully available).
public class MemoryPressureWidget: LabeledPercentWidget
{
    private var displayMode: String = "pressure"

    public init(title: String, config: NSDictionary?, preview: Bool = false)
    {
        super.init(.memoryPressure, title: title, config: config, preview: preview)

        if !preview
        {
            self.displayMode = Store.shared.string(
                key: "\(self.title)_\(self.type.rawValue)_displayMode",
                defaultValue: self.displayMode
            )
        }
    }

    required public init?(coder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }

    public override func draw(_ dirtyRect: NSRect)
    {
        super.draw(dirtyRect)

        let rawPressure = self.currentPercent()
        let isHeadroom = self.displayMode == "headroom"
        let label = isHeadroom ? "ROOM" : "PRES"
        let displayValue = isHeadroom ? (100 - rawPressure) : rawPressure
        self.drawLabeledPercent(LabeledPercent(label: label, percent: displayValue, tint: nil))
    }

    // MARK: - Settings

    public override func settings() -> NSView {
        let view = SettingsContainerView()

        view.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Display mode"), component: selectView(
                action: #selector(self.toggleDisplayMode),
                items: [
                    KeyValue_t(key: "pressure", value: localizedString("Pressure")),
                    KeyValue_t(key: "headroom", value: localizedString("Headroom"))
                ],
                selected: self.displayMode
            ))
        ]))

        return view
    }

    @objc private func toggleDisplayMode(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.displayMode = key
        Store.shared.set(key: "\(self.title)_\(self.type.rawValue)_displayMode", value: key)
        self.scheduleRedraw()
    }
}
