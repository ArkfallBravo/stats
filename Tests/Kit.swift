//
//  Kit.swift
//  Tests
//
//  Created by Serhiy Mytrovtsiy on 04/07/2026.
//  Using Swift 6.0.
//  Running on macOS 26.5.
//
//  Copyright © 2026 Serhiy Mytrovtsiy. All rights reserved.
//

import XCTest
import Kit

class KitTests: XCTestCase {
    func testIsNewestVersion_release() throws {
        XCTAssertFalse(isNewestVersion(currentVersion: "v2.11.0", latestVersion: "v2.11.0"))
        XCTAssertTrue(isNewestVersion(currentVersion: "v2.11.0", latestVersion: "v2.11.1"))
        XCTAssertFalse(isNewestVersion(currentVersion: "v2.11.1", latestVersion: "v2.11.0"))
        XCTAssertTrue(isNewestVersion(currentVersion: "v2.11.0", latestVersion: "v2.12.0"))
        XCTAssertFalse(isNewestVersion(currentVersion: "v2.12.0", latestVersion: "v2.11.5"))
        XCTAssertTrue(isNewestVersion(currentVersion: "v2.11.0", latestVersion: "v3.0.0"))
        XCTAssertFalse(isNewestVersion(currentVersion: "v3.0.0", latestVersion: "v2.99.99"))
    }
    
    func testIsNewestVersion_beta() throws {
        XCTAssertFalse(isNewestVersion(currentVersion: "v2.11.0-beta1", latestVersion: "v2.11.0-beta1"))
        XCTAssertFalse(isNewestVersion(currentVersion: "v2.11.0-beta2", latestVersion: "v2.11.0-beta1"))
        XCTAssertTrue(isNewestVersion(currentVersion: "v2.11.0-beta1", latestVersion: "v2.11.0-beta2"))
        XCTAssertTrue(isNewestVersion(currentVersion: "v2.11.0-beta1", latestVersion: "v2.11.0"))
        XCTAssertFalse(isNewestVersion(currentVersion: "v2.11.0-beta1", latestVersion: "v2.10.9"))
        XCTAssertFalse(isNewestVersion(currentVersion: "v2.11.0", latestVersion: "v2.11.1-beta1"))
        XCTAssertTrue(isNewestVersion(currentVersion: "v2.11.0-beta1", latestVersion: "v2.11.1-beta1"))
    }
    
    func testIsNewestVersion_malformed() throws {
        XCTAssertFalse(isNewestVersion(currentVersion: "v3", latestVersion: "v3.0.0"))
        XCTAssertTrue(isNewestVersion(currentVersion: "v3", latestVersion: "v3.0.1"))
        XCTAssertFalse(isNewestVersion(currentVersion: "v3.0", latestVersion: "v3.0.0"))
        XCTAssertFalse(isNewestVersion(currentVersion: "", latestVersion: ""))
    }
    
    func testUnitsGetReadableSpeed_byte() throws {
        XCTAssertEqual(Units(bytes: 0).getReadableSpeed(base: .byte), "0 KB/s")
        XCTAssertEqual(Units(bytes: 999).getReadableSpeed(base: .byte), "0 KB/s")
        XCTAssertEqual(Units(bytes: 1_000).getReadableSpeed(base: .byte), "1 KB/s")
        XCTAssertEqual(Units(bytes: 500_000).getReadableSpeed(base: .byte), "500 KB/s")
        XCTAssertEqual(Units(bytes: 2_500_000).getReadableSpeed(base: .byte), "2.5 MB/s")
        XCTAssertEqual(Units(bytes: 150_000_000).getReadableSpeed(base: .byte), "150 MB/s")
        XCTAssertEqual(Units(bytes: 2_000_000_000).getReadableSpeed(base: .byte), "2.0 GB/s")
        XCTAssertEqual(Units(bytes: 2_000_000_000_000).getReadableSpeed(base: .byte), "2.0 TB/s")
        XCTAssertEqual(Units(bytes: -5).getReadableSpeed(base: .byte), "0 KB/s")
    }
    
    func testUnitsGetReadableSpeed_bit() throws {
        XCTAssertEqual(Units(bytes: 100).getReadableSpeed(base: .bit), "0 Kb/s")
        XCTAssertEqual(Units(bytes: 50_000).getReadableSpeed(base: .bit), "400 Kb/s")
        XCTAssertEqual(Units(bytes: 500_000).getReadableSpeed(base: .bit), "4.0 Mb/s")
        XCTAssertEqual(Units(bytes: 200_000_000).getReadableSpeed(base: .bit), "1.6 Gb/s")
        XCTAssertEqual(Units(bytes: 200_000_000_000).getReadableSpeed(base: .bit), "1.6 Tb/s")
    }
    
    func testUnitsGetReadableSpeed_fixedUnit() throws {
        XCTAssertEqual(Units(bytes: 500_000).getReadableSpeed(base: .byte, unit: "KB"), "500 KB/s")
        XCTAssertEqual(Units(bytes: 500_000).getReadableSpeed(base: .byte, unit: "MB"), "0.5 MB/s")
        XCTAssertEqual(Units(bytes: 500_000).getReadableSpeed(base: .bit, unit: "MB"), "4 Mb/s")
    }

    func testRAMPressure_textColor() throws
    {
        XCTAssertEqual(RAMPressure.normal.textColor(), NSColor.textColor)
        XCTAssertEqual(RAMPressure.warning.textColor(), NSColor.systemOrange)
        XCTAssertEqual(RAMPressure.critical.textColor(), NSColor.systemRed)
    }

    func testRAMPressure_alertColor() throws
    {
        XCTAssertNil(RAMPressure.normal.alertColor())
        XCTAssertEqual(RAMPressure.warning.alertColor(), NSColor.systemOrange)
        XCTAssertEqual(RAMPressure.critical.alertColor(), NSColor.systemRed)
    }

    // Returns the sRGB components of a color.
    private func components(_ color: NSColor) -> [CGFloat]
    {
        let srgb = color.usingColorSpace(.sRGB)!
        return [srgb.redComponent, srgb.greenComponent, srgb.blueComponent]
    }

    func testOKHSL_roundTrip() throws
    {
        let colors: [NSColor] = [
            NSColor(srgbRed: 1, green: 0, blue: 0, alpha: 1),
            NSColor(srgbRed: 0, green: 1, blue: 0, alpha: 1),
            NSColor(srgbRed: 0, green: 0, blue: 1, alpha: 1),
            NSColor(srgbRed: 1, green: 1, blue: 0, alpha: 1),
            NSColor(srgbRed: 0.2, green: 0.6, blue: 0.4, alpha: 1),
            NSColor(srgbRed: 0.9, green: 0.3, blue: 0.7, alpha: 1),
            NSColor(srgbRed: 0.1, green: 0.15, blue: 0.2, alpha: 1)
        ]
        for color in colors
        {
            let roundTripped = self.components(OKHSL(color).color)
            for (index, expected) in self.components(color).enumerated()
            {
                XCTAssertEqual(roundTripped[index], expected, accuracy: 1e-6, "\(color)")
            }
        }
    }

    func testOKHSL_achromatic() throws
    {
        let gray = OKHSL(NSColor(srgbRed: 0.5, green: 0.5, blue: 0.5, alpha: 1))
        XCTAssertEqual(gray.saturation, 0, accuracy: 1e-4)

        let black = OKHSL(NSColor(srgbRed: 0, green: 0, blue: 0, alpha: 1))
        XCTAssertEqual(black.lightness, 0, accuracy: 1e-9)
        XCTAssertEqual(black.saturation, 0)

        let white = OKHSL(NSColor(srgbRed: 1, green: 1, blue: 1, alpha: 1))
        XCTAssertEqual(white.lightness, 1, accuracy: 1e-6)
        XCTAssertTrue(white.saturation.isFinite)
    }

    func testOKHSL_fullSaturationReachesGamutEdge() throws
    {
        for step in 0..<12
        {
            let color = OKHSL(hue: Double(step) / 12, saturation: 1, lightness: 0.6).color
            let channels = self.components(color)
            let onEdge = channels.contains { $0 <= 1e-3 || $0 >= 1 - 1e-3 }
            XCTAssertTrue(onEdge, "hue step \(step): \(channels)")
        }
    }

    func testOKHSL_keepsHueAcrossLightness() throws
    {
        let hue = OKHSL(NSColor(srgbRed: 0.2, green: 0.6, blue: 0.4, alpha: 1)).hue
        let lighter = OKHSL(OKHSL(hue: hue, saturation: 0.8, lightness: 0.8).color)
        XCTAssertEqual(lighter.hue, hue, accuracy: 1e-6)
        XCTAssertEqual(lighter.saturation, 0.8, accuracy: 1e-6)
        XCTAssertEqual(lighter.lightness, 0.8, accuracy: 1e-6)
    }

    func testHistoryRing_ordersOldestFirst() throws
    {
        let ring = HistoryRing<Int>(capacity: 3)
        ring.append(1)
        XCTAssertEqual(ring.ordered(), [nil, nil, 1])

        ring.append(2)
        ring.append(3)
        ring.append(4)
        XCTAssertEqual(ring.ordered(), [2, 3, 4])

        ring.reset(capacity: 2)
        XCTAssertEqual(ring.ordered(), [nil, nil])
        ring.append(5)
        ring.append(6)
        ring.append(7)
        XCTAssertEqual(ring.ordered(), [6, 7])
    }
}
