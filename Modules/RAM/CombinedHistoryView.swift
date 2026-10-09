// ----------------------------------------------------------------------- //
//
// MODULE  : CombinedHistoryView.swift
//
// PURPOSE : Line chart of RAM usage, pressure, and compression history
//
// CREATED : 10/9/2026
//
// ----------------------------------------------------------------------- //

import Cocoa
import Kit

private let combinedLineWidth: CGFloat = 1.5
private let compressionDash: [CGFloat] = [3, 2]

// One tick of the combined chart, with every value in 0–1.
internal struct CombinedSample
{
    let usage: Double
    let pressure: Double
    let compression: Double
    let level: Int
}

// Lays out one value of each sample as chart points.
private struct CombinedSeries
{
    let samples: [CombinedSample?]
    let geometry: HistoryGeometry

    // Returns the plotted points of one value, nil where no sample exists yet.
    func points(_ value: KeyPath<CombinedSample, Double>) -> [CGPoint?]
    {
        return self.samples.enumerated().map
        { index, sample in
            sample.map { self.geometry.point(index: index, value: $0[keyPath: value]) }
        }
    }

    // Returns the plotted points of one value, tagged with each sample's pressure level.
    func levelPoints(_ value: KeyPath<CombinedSample, Double>) -> [LevelPoint?]
    {
        return self.samples.enumerated().map
        { index, sample in
            sample.map { LevelPoint(point: self.geometry.point(index: index, value: $0[keyPath: value]), level: $0.level) }
        }
    }
}

// Draws usage as a solid blue line, pressure as a solid level-colored line, and compression as a dotted level-colored line.
internal class CombinedHistoryView: NSView
{
    private let history: HistoryRing<CombinedSample>

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

    func addSample(_ sample: CombinedSample)
    {
        self.history.append(sample)
        self.redrawIfVisible()
    }

    // Resizes the history to `num` samples, clearing it.
    func reinit(_ num: Int)
    {
        self.history.reset(capacity: num)
        self.redrawIfVisible()
    }

    override func draw(_ dirtyRect: NSRect)
    {
        super.draw(dirtyRect)
        let samples = self.history.ordered()
        guard samples.count > 1 else
        {
            return
        }

        let series = CombinedSeries(samples: samples, geometry: HistoryGeometry(frame: self.frame, count: samples.count))
        let palette = HistoryPalette()
        self.stroke(HistoryRuns.polylines(series.points(\.usage)), color: palette.usage)
        self.strokeSolid(HistoryRuns.levelPolylines(series.levelPoints(\.pressure)), palette: palette)
        self.strokeDashed(HistoryRuns.levelPolylines(series.levelPoints(\.compression)), palette: palette)
    }

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

    private func linePath(_ points: [CGPoint]) -> NSBezierPath
    {
        let path = NSBezierPath()
        path.lineWidth = combinedLineWidth
        path.lineJoinStyle = .round
        path.move(to: points[0])
        for point in points.dropFirst()
        {
            path.line(to: point)
        }
        return path
    }

    private func stroke(_ polylines: [[CGPoint]], color: NSColor)
    {
        color.setStroke()
        for polyline in polylines
        {
            self.linePath(polyline).stroke()
        }
    }

    private func strokeSolid(_ runs: [LevelRun], palette: HistoryPalette)
    {
        for run in runs
        {
            palette.levelColor(run.level).setStroke()
            self.linePath(run.points).stroke()
        }
    }

    // Continues the dash pattern across runs so a level change doesn't restart it.
    private func strokeDashed(_ runs: [LevelRun], palette: HistoryPalette)
    {
        var travelled: CGFloat = 0
        for run in runs
        {
            let path = self.linePath(run.points)
            path.setLineDash(compressionDash, count: compressionDash.count, phase: travelled)
            palette.levelColor(run.level).setStroke()
            path.stroke()
            travelled += polylineLength(run.points)
        }
    }
}

private func polylineLength(_ points: [CGPoint]) -> CGFloat
{
    return zip(points, points.dropFirst()).reduce(0)
    { total, segment in
        total + hypot(segment.1.x - segment.0.x, segment.1.y - segment.0.y)
    }
}
