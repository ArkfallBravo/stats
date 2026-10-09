// ----------------------------------------------------------------------- //
//
// MODULE  : HistoryRing.swift
//
// PURPOSE : Thread-safe fixed-capacity history of chart samples
//
// CREATED : 10/9/2026
//
// ----------------------------------------------------------------------- //

import Foundation

// Keeps the latest `capacity` samples, overwriting the oldest once full.
public final class HistoryRing<Element>
{
    private let queue: DispatchQueue = DispatchQueue(label: "eu.exelban.Stats.HistoryRing", attributes: .concurrent)
    private var slots: [Element?] = []
    private var head: Int = 0

    public init(capacity: Int)
    {
        self.slots = Array(repeating: nil, count: max(capacity, 0))
    }

    // Stores a sample in place of the oldest one.
    public func append(_ element: Element)
    {
        self.queue.async(flags: .barrier)
        {
            let count = self.slots.count
            guard count > 0 else
            {
                return
            }
            self.slots[self.head] = element
            self.head = (self.head + 1) % count
        }
    }

    // Drops every sample and resizes to `capacity` slots.
    public func reset(capacity: Int)
    {
        self.queue.async(flags: .barrier)
        {
            self.slots = Array(repeating: nil, count: max(capacity, 0))
            self.head = 0
        }
    }

    // Returns every slot from oldest to newest, with nil for slots not yet filled.
    public func ordered() -> [Element?]
    {
        return self.queue.sync
        {
            let count = self.slots.count
            return (0..<count).map { self.slots[(self.head + $0) % count] }
        }
    }
}
