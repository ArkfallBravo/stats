// ----------------------------------------------------------------------- //
//
// MODULE  : GPU.swift
//
// PURPOSE : Tests for the GPU module's per-process usage sampling
//
// CREATED : 9/2/2026
//
// ----------------------------------------------------------------------- //

import XCTest
@testable import GPU

class GPU: XCTestCase {
    func testParseClient() throws {
        let client = ProcessReader.parseClient([
            "IOUserClientCreator": "pid 630, WindowServer",
            "AppUsage": [["accumulatedGPUTime": NSNumber(value: 100)], ["accumulatedGPUTime": NSNumber(value: 50)]]
        ])
        XCTAssertEqual(client?.pid, 630)
        XCTAssertEqual(client?.name, "WindowServer")
        XCTAssertEqual(client?.gpuTime, 150)
        XCTAssertEqual(client?.queues, 2)
    }

    func testParseClientFallsBackToPidName() throws {
        let client = ProcessReader.parseClient([
            "IOUserClientCreator": "pid 42",
            "AppUsage": [["accumulatedGPUTime": NSNumber(value: 1)]]
        ])
        XCTAssertEqual(client?.name, "42")
    }

    func testParseClientRejectsMalformedInput() throws {
        let usage: [[String: Any]] = [["accumulatedGPUTime": NSNumber(value: 1)]]
        XCTAssertNil(ProcessReader.parseClient(["IOUserClientCreator": "PID 630, WindowServer", "AppUsage": usage]))
        XCTAssertNil(ProcessReader.parseClient(["IOUserClientCreator": "pid abc, WindowServer", "AppUsage": usage]))
        XCTAssertNil(ProcessReader.parseClient(["IOUserClientCreator": "pid 0, kernel", "AppUsage": usage]))
        XCTAssertNil(ProcessReader.parseClient(["IOUserClientCreator": "pid 630, WindowServer", "AppUsage": [[String: Any]]()]))
        XCTAssertNil(ProcessReader.parseClient(["AppUsage": usage]))
    }

    func testSampleNeedsBaseline() throws {
        var usage = ProcessReader.Usage()
        let clients = [UInt64(1): ProcessReader.Client(pid: 630, name: "WindowServer", gpuTime: 0, queues: 1)]
        XCTAssertNil(usage.sample(clients, at: 1_000_000_000, interval: 1))
        XCTAssertEqual(usage.timestamp, 1_000_000_000)
    }

    func testSampleSumsClientsPerProcess() throws {
        var usage = ProcessReader.Usage()
        _ = usage.sample([
            1: ProcessReader.Client(pid: 630, name: "WindowServer", gpuTime: 0, queues: 1),
            2: ProcessReader.Client(pid: 630, name: "WindowServer", gpuTime: 0, queues: 1),
            3: ProcessReader.Client(pid: 42, name: "iTerm2", gpuTime: 0, queues: 1)
        ], at: 1_000_000_000, interval: 1)
        // Over a 1 s window: 0.2 s + 0.05 s for pid 630 is 25%; 0.1 s for pid 42 is 10%.
        let processes = usage.sample([
            1: ProcessReader.Client(pid: 630, name: "WindowServer", gpuTime: 200_000_000, queues: 1),
            2: ProcessReader.Client(pid: 630, name: "WindowServer", gpuTime: 50_000_000, queues: 1),
            3: ProcessReader.Client(pid: 42, name: "iTerm2", gpuTime: 100_000_000, queues: 1)
        ], at: 2_000_000_000, interval: 1)
        XCTAssertEqual(processes?.map { $0.pid }, [630, 42])
        XCTAssertEqual(processes?[0].usage ?? .nan, 25, accuracy: 1e-9)
        XCTAssertEqual(processes?[1].usage ?? .nan, 10, accuracy: 1e-9)
    }

    func testSampleSkipsResetAndChangedClients() throws {
        var usage = ProcessReader.Usage()
        _ = usage.sample([
            1: ProcessReader.Client(pid: 1, name: "a", gpuTime: 900, queues: 1),
            2: ProcessReader.Client(pid: 2, name: "b", gpuTime: 0, queues: 1),
            3: ProcessReader.Client(pid: 3, name: "c", gpuTime: 0, queues: 1)
        ], at: 1_000_000_000, interval: 1)
        let processes = usage.sample([
            1: ProcessReader.Client(pid: 1, name: "a", gpuTime: 100, queues: 1), // counter went backwards
            2: ProcessReader.Client(pid: 2, name: "b", gpuTime: 100, queues: 2), // queue count changed
            3: ProcessReader.Client(pid: 9, name: "c", gpuTime: 100, queues: 1), // id reused by another pid
            4: ProcessReader.Client(pid: 4, name: "d", gpuTime: 100, queues: 1) // no previous sample
        ], at: 2_000_000_000, interval: 1)
        XCTAssertEqual(processes?.isEmpty, true)
    }

    func testSampleRebaselinesAfterLongGap() throws {
        var usage = ProcessReader.Usage()
        let clients = [UInt64(1): ProcessReader.Client(pid: 1, name: "a", gpuTime: 0, queues: 1)]
        _ = usage.sample(clients, at: 1_000_000_000, interval: 1)
        XCTAssertNil(usage.sample(clients, at: 5_000_000_000, interval: 1))
        XCTAssertEqual(usage.timestamp, 5_000_000_000)
    }

    func testSampleIgnoresTooShortWindow() throws {
        var usage = ProcessReader.Usage()
        let clients = [UInt64(1): ProcessReader.Client(pid: 1, name: "a", gpuTime: 0, queues: 1)]
        _ = usage.sample(clients, at: 1_000_000_000, interval: 1)
        XCTAssertNil(usage.sample(clients, at: 1_100_000_000, interval: 1))
        XCTAssertEqual(usage.timestamp, 1_000_000_000)
    }
}
