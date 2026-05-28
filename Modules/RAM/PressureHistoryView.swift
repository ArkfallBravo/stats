//
//  PressureHistoryView.swift
//  Memory
//
//  Created by Helena Simson.
//

import Cocoa

/// A line-chart view for memory pressure history.
/// Each time-slice is coloured green (normal), yellow (warning), or red (critical)
/// matching Activity Monitor's memory pressure graph.
internal class PressureHistoryView: NSView {
    private struct Point {
        let value: Double  // 0.0 – 1.0
        let level: Int     // 1 = normal, 2 = warning, 4 = critical
        let ts: Date
    }

    private let queue = DispatchQueue(label: "PressureHistoryView", attributes: .concurrent)
    private var points: [Point?]
    private var head: Int = 0

    init(frame: NSRect, num: Int) {
        self.points = Array(repeating: nil, count: num)
        super.init(frame: frame)
        self.wantsLayer = true
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    // MARK: - Public API

    func addValue(value: Double, level: Int) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            let n = self.points.count
            guard n > 0 else { return }
            self.points[self.head] = Point(value: value, level: level, ts: Date())
            self.head = (self.head + 1) % n
        }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window?.isVisible ?? false else { return }
            self.display()
        }
    }

    /// Resize the ring buffer to `num` slots (clears existing data).
    func reinit(_ num: Int) {
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            self.points = Array(repeating: nil, count: num)
            self.head = 0
        }
        DispatchQueue.main.async { [weak self] in
            guard let self, self.window?.isVisible ?? false else { return }
            self.display()
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else { return }

        var ordered: [Point?] = []
        queue.sync { [weak self] in
            guard let self else { return }
            let n = self.points.count
            for i in 0..<n {
                ordered.append(self.points[(self.head + i) % n])
            }
        }

        let n = ordered.count
        guard n > 1 else { return }

        let pixelScale: CGFloat = NSScreen.main?.backingScaleFactor ?? 1
        let offset: CGFloat = 1 / pixelScale
        let height: CGFloat = frame.height - offset
        let xRatio: CGFloat = frame.width / CGFloat(n - 1)

        // --- filled colored trapezoids between consecutive non-nil points ---
        for i in 0..<(n - 1) {
            guard let pt = ordered[i], let next = ordered[i + 1] else { continue }

            let x0 = CGFloat(i) * xRatio
            let x1 = CGFloat(i + 1) * xRatio
            let y0 = CGFloat(pt.value) * height + offset
            let y1 = CGFloat(next.value) * height + offset

            let fillColor = pressureColor(for: pt.level, alpha: 0.7)
            context.setFillColor(fillColor.cgColor)

            context.beginPath()
            context.move(to: CGPoint(x: x0, y: offset))
            context.addLine(to: CGPoint(x: x0, y: y0))
            context.addLine(to: CGPoint(x: x1, y: y1))
            context.addLine(to: CGPoint(x: x1, y: offset))
            context.closePath()
            context.fillPath()
        }

        // --- line on top ---
        var segments: [[CGPoint]] = []
        var current: [CGPoint] = []
        for (i, pt) in ordered.enumerated() {
            guard let pt else {
                if !current.isEmpty { segments.append(current); current = [] }
                continue
            }
            let x = CGFloat(i) * xRatio
            let y = CGFloat(pt.value) * height + offset
            current.append(CGPoint(x: x, y: y))
        }
        if !current.isEmpty { segments.append(current) }

        for seg in segments {
            guard seg.count >= 2 else { continue }
            let path = NSBezierPath()
            path.move(to: seg[0])
            for pt in seg.dropFirst() { path.line(to: pt) }
            NSColor.white.withAlphaComponent(0.8).set()
            path.lineWidth = offset
            path.stroke()
        }
    }

    // MARK: - Helpers

    private func pressureColor(for level: Int, alpha: CGFloat) -> NSColor {
        switch level {
        case 2: return NSColor.systemYellow.withAlphaComponent(alpha)
        case 4: return NSColor.systemRed.withAlphaComponent(alpha)
        default: return NSColor.systemGreen.withAlphaComponent(alpha)
        }
    }
}
