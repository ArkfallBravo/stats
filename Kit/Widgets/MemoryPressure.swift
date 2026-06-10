//
//  MemoryPressure.swift
//  Kit
//
//  Created by Helena Simson on 27/05/2026
//  Using Swift 5.0
//  Running on macOS 14.0
//
//  Copyright © 2026 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa

/// A menu-bar widget that displays either memory pressure or memory headroom.
///
/// - Pressure mode  (`displayMode == "pressure"`): shows `100 - kern.memorystatus_level`
///   — the proportion of memory under pressure (0 = none, 100 = full).
/// - Headroom mode (`displayMode == "headroom"`): shows `kern.memorystatus_level`
///   — the available memory headroom (0 = none, 100 = fully available).
public class MemoryPressureWidget: WidgetWrapper {
    private var pressurePercent: Int = 0
    private var displayMode: String = "pressure"

    public init(title: String, config: NSDictionary?, preview: Bool = false) {
        if preview {
            self.pressurePercent = 42
        }

        super.init(.memoryPressure, title: title, frame: CGRect(
            x: 0,
            y: Constants.Widget.margin.y,
            width: 34 + (2 * Constants.Widget.margin.x),
            height: Constants.Widget.height - (2 * Constants.Widget.margin.y)
        ))

        if !preview {
            self.displayMode = Store.shared.string(
                key: "\(self.title)_\(self.type.rawValue)_displayMode",
                defaultValue: self.displayMode
            )
        }

        self.canDrawConcurrently = true
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        var rawPressure: Int = 0
        self.queue.sync { rawPressure = self.pressurePercent }

        let displayValue = self.displayMode == "headroom" ? (100 - rawPressure) : rawPressure

        let label = self.displayMode == "headroom" ? "ROOM" : "PRES"
        let labelFontSize: CGFloat = 7
        let valueFontSize: CGFloat = 12
        let style = NSMutableParagraphStyle()
        style.alignment = .left

        let labelAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: labelFontSize, weight: .light),
            .foregroundColor: isDarkMode ? NSColor.white : NSColor.textColor,
            .paragraphStyle: style
        ]
        let valueAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: valueFontSize, weight: .regular),
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: style
        ]

        let labelStr = NSAttributedString(string: label, attributes: labelAttrs)
        let valueStr = NSAttributedString(string: "\(displayValue)%", attributes: valueAttrs)

        let measure = { (s: NSAttributedString) -> CGFloat in
            s.boundingRect(
                with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin, .usesFontLeading]
            ).width
        }

        let width = (max(measure(labelStr), measure(valueStr)) + Constants.Widget.margin.x * 2).roundedUpToNearestTen()
        let innerWidth = width - (Constants.Widget.margin.x * 2)

        labelStr.draw(with: CGRect(x: Constants.Widget.margin.x, y: 12, width: innerWidth, height: labelFontSize))
        valueStr.draw(with: CGRect(x: Constants.Widget.margin.x, y: 1, width: innerWidth, height: valueFontSize + 1))

        self.setWidth(width)
    }

    public func setValue(_ newValue: Int) {
        guard self.pressurePercent != newValue else { return }
        self.pressurePercent = newValue
        DispatchQueue.main.async(execute: {
            self.display()
        })
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
        DispatchQueue.main.async(execute: {
            self.display()
        })
    }
}
