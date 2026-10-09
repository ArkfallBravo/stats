// ----------------------------------------------------------------------- //
//
// MODULE  : HistoryGeometry.swift
//
// PURPOSE : Point layout and polyline splitting for the RAM history charts
//
// CREATED : 10/9/2026
//
// ----------------------------------------------------------------------- //

import Cocoa

// A plotted point tagged with the kernel memory pressure level of its sample.
public struct LevelPoint
{
    public let point: CGPoint
    public let level: Int

    public init(point: CGPoint, level: Int)
    {
        self.point = point
        self.level = level
    }
}

// A polyline whose every segment takes one pressure level's color.
public struct LevelRun: Equatable
{
    public let level: Int
    public var points: [CGPoint]

    public init(level: Int, points: [CGPoint])
    {
        self.level = level
        self.points = points
    }
}

public enum HistoryRuns
{
    // Splits points into polylines at nil gaps, dropping lone points.
    public static func polylines(_ points: [CGPoint?]) -> [[CGPoint]]
    {
        var lines: [[CGPoint]] = []
        var current: [CGPoint] = []
        for point in points
        {
            if let point
            {
                current.append(point)
                continue
            }
            lines.append(current)
            current = []
        }
        lines.append(current)
        return lines.filter { $0.count >= 2 }
    }

    // Splits points into polylines at nil gaps and level changes; each segment takes its starting point's level.
    public static func levelPolylines(_ points: [LevelPoint?]) -> [LevelRun]
    {
        var runs: [LevelRun] = []
        var lastAppended: Int = -1
        for index in points.indices.dropLast()
        {
            guard let start = points[index], let end = points[index + 1] else
            {
                continue
            }
            if lastAppended == index, let last = runs.last, last.level == start.level
            {
                runs[runs.count - 1].points.append(end.point)
            }
            else
            {
                runs.append(LevelRun(level: start.level, points: [start.point, end.point]))
            }
            lastAppended = index + 1
        }
        return runs
    }
}

// Maps sample indices and 0–1 values to view coordinates.
internal struct HistoryGeometry
{
    let offset: CGFloat
    let height: CGFloat
    let xRatio: CGFloat

    init(frame: NSRect, count: Int)
    {
        self.offset = 1 / (NSScreen.main?.backingScaleFactor ?? 1)
        self.height = frame.height - self.offset
        self.xRatio = frame.width / CGFloat(max(count - 1, 1))
    }

    // Returns the view position of a 0–1 value at a sample index.
    func point(index: Int, value: Double) -> CGPoint
    {
        return CGPoint(x: CGFloat(index) * self.xRatio, y: CGFloat(value) * self.height + self.offset)
    }
}
