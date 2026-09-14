//
//  GPU.swift
//  Tests
//
//  Created by Helena Simson on 02/09/2026.
//  Using Swift 5.0.
//  Running on macOS 15.0.
//
//  Copyright © 2026 Serhiy Mytrovtsiy. All rights reserved.
//

import XCTest
import GPU

class GPU: XCTestCase {
    func testParseCreator() throws {
        var parsed = ProcessReader.parseCreator("pid 630, WindowServer")
        XCTAssertEqual(parsed?.pid, 630)
        XCTAssertEqual(parsed?.name, "WindowServer")

        parsed = ProcessReader.parseCreator("pid 47527, com.apple.WebKit.GPU")
        XCTAssertEqual(parsed?.pid, 47527)
        XCTAssertEqual(parsed?.name, "com.apple.WebKit.GPU")

        parsed = ProcessReader.parseCreator("pid 1, ")
        XCTAssertEqual(parsed?.pid, 1)
        XCTAssertEqual(parsed?.name, "")

        XCTAssertNil(ProcessReader.parseCreator("PID 630, WindowServer"))
        XCTAssertNil(ProcessReader.parseCreator("pid abc, WindowServer"))
        XCTAssertNil(ProcessReader.parseCreator(""))
    }

    func testAggregate() throws {
        let clients = [
            GPUProcessUsage(pid: 630, name: "WindowServer", gpuTime: 100),
            GPUProcessUsage(pid: 630, name: "WindowServer", gpuTime: 50),
            GPUProcessUsage(pid: 42, name: "", gpuTime: 10),
            GPUProcessUsage(pid: 42, name: "iTerm2", gpuTime: 5)
        ]

        let aggregated = ProcessReader.aggregate(clients)
        XCTAssertEqual(aggregated[630]?.gpuTime, 150)
        XCTAssertEqual(aggregated[630]?.name, "WindowServer")
        XCTAssertEqual(aggregated[42]?.gpuTime, 15)
        XCTAssertEqual(aggregated[42]?.name, "iTerm2")
    }

    func testUsages() throws {
        // 1 second of GPU time over a 4 second window is 25%.
        let usage = ProcessReader.usages(
            current: [630: 2_000_000_000, 42: 1_000_000_000],
            previous: [630: 1_000_000_000, 42: 1_000_000_000],
            elapsed: 4
        )
        XCTAssertEqual(usage[630], 25)
        XCTAssertEqual(usage[42], 0)
    }

    func testUsagesIgnoresUnseenAndResetProcesses() throws {
        let usage = ProcessReader.usages(
            current: [1: 500, 2: 100],
            previous: [2: 900],
            elapsed: 1
        )
        XCTAssertNil(usage[1]) // no previous sample
        XCTAssertNil(usage[2]) // counter went backwards
    }

    func testUsagesClampsAndGuardsInterval() throws {
        XCTAssertTrue(ProcessReader.usages(current: [1: 10], previous: [1: 0], elapsed: 0).isEmpty)

        let usage = ProcessReader.usages(current: [1: 5_000_000_000], previous: [1: 0], elapsed: 1)
        XCTAssertEqual(usage[1], 100)
    }
}
