// ----------------------------------------------------------------------- //
//
// MODULE  : PressureHistoryView.swift
//
// PURPOSE : Line chart of a percent history colored by memory pressure level
//
// CREATED : 5/28/2026
//
// ----------------------------------------------------------------------- //

import Cocoa
import Kit

/// A line-chart view for a 0–1 history whose time-slices are colored by memory pressure level.
/// Each time-slice is filled green (normal), yellow (warning), or red (critical),
/// matching Activity Monitor's memory pressure graph.
internal class PressureHistoryView: NSView
{
    private struct Point
    {
        let value: Double  // 0.0 – 1.0
        let level: Int     // 1 = normal, 2 = warning, 4 = critical
    }

    private let history: HistoryRing<Point>

    init(frame: NSRect, num: Int)
    {
        self.history = HistoryRing(capacity: num)
        super.init(frame: frame)
        self.wantsLayer = true
    }

    required init?(coder: NSCoder)
    {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public API

    func addValue(value: Double, level: Int)
    {
        self.history.append(Point(value: value, level: level))
        self.redrawIfVisible()
    }

    /// Resize the ring buffer to `num` slots (clears existing data).
    func reinit(_ num: Int)
    {
        self.history.reset(capacity: num)
        self.redrawIfVisible()
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect)
    {
        super.draw(dirtyRect)
        guard let context = NSGraphicsContext.current?.cgContext else
        {
            return
        }

        let ordered = self.history.ordered()
        guard ordered.count > 1 else
        {
            return
        }
        let geometry = HistoryGeometry(frame: self.frame, count: ordered.count)
        let palette = HistoryPalette()

        // --- filled colored trapezoids between consecutive non-nil points ---
        for i in 0..<(ordered.count - 1)
        {
            guard let pt = ordered[i], let next = ordered[i + 1] else
            {
                continue
            }
            let start = geometry.point(index: i, value: pt.value)
            let end = geometry.point(index: i + 1, value: next.value)

            context.setFillColor(palette.levelColor(pt.level).withAlphaComponent(0.7).cgColor)
            context.beginPath()
            context.move(to: CGPoint(x: start.x, y: geometry.offset))
            context.addLine(to: start)
            context.addLine(to: end)
            context.addLine(to: CGPoint(x: end.x, y: geometry.offset))
            context.closePath()
            context.fillPath()
        }

        // --- line on top ---
        let points = ordered.enumerated().map
        { index, pt in
            pt.map { geometry.point(index: index, value: $0.value) }
        }
        NSColor.white.withAlphaComponent(0.8).set()
        for polyline in HistoryRuns.polylines(points)
        {
            let path = NSBezierPath()
            path.move(to: polyline[0])
            for point in polyline.dropFirst()
            {
                path.line(to: point)
            }
            path.lineWidth = geometry.offset
            path.stroke()
        }
    }

    // MARK: - Helpers

    private func redrawIfVisible()
    {
        DispatchQueue.main.async
        { [weak self] in
            guard let self, self.window?.isVisible ?? false else
            {
                return
            }
            self.display()
        }
    }
}
