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

/// A menu-bar widget that displays the memory pressure percentage.
///
/// The value is derived as `100 - kern.memorystatus_level`, giving the
/// proportion of memory that is under pressure (0 = none, 100 = full).
public class MemoryPressureWidget: WidgetWrapper {
    private var pressurePercent: Int = 0

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

        self.canDrawConcurrently = true
    }

    required public init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    public override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        var value: Int = 0
        self.queue.sync { value = self.pressurePercent }

        let text = "\(value)%"
        let fontSize: CGFloat = 12
        let style = NSMutableParagraphStyle()
        style.alignment = .center

        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: fontSize, weight: .regular),
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: style
        ]

        let attrStr = NSAttributedString(string: text, attributes: attrs)
        let strSize = attrStr.boundingRect(
            with: CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading]
        )

        let width = (strSize.width + Constants.Widget.margin.x * 2).roundedUpToNearestTen()
        let originY: CGFloat = (Constants.Widget.height - fontSize - 1) / 2
        let rect = CGRect(
            x: Constants.Widget.margin.x,
            y: originY,
            width: width - (Constants.Widget.margin.x * 2),
            height: fontSize
        )
        attrStr.draw(with: rect)

        self.setWidth(width)
    }

    public func setValue(_ newValue: Int) {
        guard self.pressurePercent != newValue else { return }
        self.pressurePercent = newValue
        DispatchQueue.main.async(execute: {
            self.display()
        })
    }
}
