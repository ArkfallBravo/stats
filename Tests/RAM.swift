//
//  RAM.swift
//  Tests
//
//  Created by Serhiy Mytrovtsiy on 16/04/2022.
//  Using Swift 5.0.
//  Running on macOS 10.15.
//
//  Copyright © 2022 Serhiy Mytrovtsiy. All rights reserved.
//

import XCTest
import RAM

class RAM: XCTestCase {
    func testProcessReader_parseProcess() throws {
        var process = ProcessReader.parseProcess("3127  lldb-rpc-server  611M")
        XCTAssertEqual(process.pid, 3127)
        XCTAssertEqual(process.name, "lldb-rpc-server")
        XCTAssertEqual(process.usage, 611 * Double(1000 * 1000))
        
        process = ProcessReader.parseProcess("257   WindowServer     210M")
        XCTAssertEqual(process.pid, 257)
        XCTAssertEqual(process.name, "WindowServer")
        XCTAssertEqual(process.usage, 210 * Double(1000 * 1000))
        
        process = ProcessReader.parseProcess("7752  phpstorm         1819M")
        XCTAssertEqual(process.pid, 7752)
        XCTAssertEqual(process.name, "phpstorm")
        XCTAssertEqual(process.usage, 1819.0 / 1024 * 1000 * Double(1000 * 1000))
        
        process = ProcessReader.parseProcess("359   NotificationCent 62M")
        XCTAssertEqual(process.pid, 359)
        XCTAssertEqual(process.name, "NotificationCent")
        XCTAssertEqual(process.usage, 62 * Double(1000 * 1000))
        
        process = ProcessReader.parseProcess("623    SafariCloudHisto 1608K")
        XCTAssertEqual(process.pid, 623)
        XCTAssertEqual(process.name, "SafariCloudHisto")
        XCTAssertEqual(process.usage, (1608/1024) * Double(1000 * 1000))
        
        process = ProcessReader.parseProcess("174    WindowServer     1442M+ ")
        XCTAssertEqual(process.pid, 174)
        XCTAssertEqual(process.name, "WindowServer")
        XCTAssertEqual(process.usage, 1442 * Double(1000 * 1000))
        
        process = ProcessReader.parseProcess("329    Finder           488M+ ")
        XCTAssertEqual(process.pid, 329)
        XCTAssertEqual(process.name, "Finder")
        XCTAssertEqual(process.usage, 488 * Double(1000 * 1000))
        
        process = ProcessReader.parseProcess("7163* AutoCAD LT 2023  11G  ")
        XCTAssertEqual(process.pid, 7163)
        XCTAssertEqual(process.name, "AutoCAD LT 2023")
        XCTAssertEqual(process.usage, 11 * Double(1024 * 1000 * 1000))
    }
    
    func testKernelTask() throws {
        var process = ProcessReader.parseProcess("0      kernel_task      270M ")
        XCTAssertEqual(process.pid, 0)
        XCTAssertEqual(process.name, "kernel_task")
        XCTAssertEqual(process.usage, 270 * Double(1000 * 1000))
        
        process = ProcessReader.parseProcess("0     kernel_task      280M")
        XCTAssertEqual(process.pid, 0)
        XCTAssertEqual(process.name, "kernel_task")
        XCTAssertEqual(process.usage, 280 * Double(1000 * 1000))
    }
    
    func testSizes() throws {
        var process = ProcessReader.parseProcess("0  com.apple.Virtua 8463M")
        XCTAssertEqual(process.pid, 0)
        XCTAssertEqual(process.name, "com.apple.Virtua")
        XCTAssertEqual(process.usage, 8463.0 / 1024 * 1000 * 1000 * 1000)
        
        process = ProcessReader.parseProcess("0  Safari           658M")
        XCTAssertEqual(process.pid, 0)
        XCTAssertEqual(process.name, "Safari")
        XCTAssertEqual(process.usage, 658 * Double(1000 * 1000))
    }

    func testProcessReader_parsePSLine() throws
    {
        let process = ProcessReader.parsePSLine("  329  48812 /System/Library/CoreServices/Finder.app/Contents/MacOS/Finder")
        XCTAssertEqual(process?.pid, 329)
        XCTAssertEqual(process?.name, "/System/Library/CoreServices/Finder.app/Contents/MacOS/Finder")
        XCTAssertEqual(process?.usage, 48812 * 1024)

        XCTAssertEqual(ProcessReader.parsePSLine("7163 1024 AutoCAD LT 2023")?.name, "AutoCAD LT 2023")
        XCTAssertNil(ProcessReader.parsePSLine("  412      0 zombie"))
        XCTAssertNil(ProcessReader.parsePSLine("abc 1024 name"))
        XCTAssertNil(ProcessReader.parsePSLine("412 1024"))
        XCTAssertNil(ProcessReader.parsePSLine(""))
    }

    func testUsageReader_compressionPercent() throws
    {
        XCTAssertEqual(UsageReader.compressionPercent(compressedPages: 0, availablePages: 0), 0)
        XCTAssertEqual(UsageReader.compressionPercent(compressedPages: 0, availablePages: 1000), 0)
        XCTAssertEqual(UsageReader.compressionPercent(compressedPages: 1000, availablePages: 1000), 50)
        XCTAssertEqual(UsageReader.compressionPercent(compressedPages: 1000, availablePages: 0), 100)
        XCTAssertEqual(UsageReader.compressionPercent(compressedPages: 2, availablePages: 1), 66)
        XCTAssertEqual(UsageReader.compressionPercent(compressedPages: 4_000_000, availablePages: 1_000_000), 80)
    }
}
