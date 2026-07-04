//
//  notifications.swift
//  Battery
//
//  Created by Serhiy Mytrovtsiy on 17/12/2023
//  Using Swift 5.0
//  Running on macOS 14.2
//
//  Copyright © 2023 Serhiy Mytrovtsiy. All rights reserved.
//

import Cocoa
import Kit

class Notifications: NotificationsWrapper {
    private let lowID: String = "low"
    private let highID: String = "high"
    private let timeToDischargeID: String = "timeToDischarge"
    private var lowLevel: String = ""
    private var highLevel: String = ""
    private var timeToDischargeState: Bool = false
    private var timeToDischarge: Int = 75

    public init(_ module: ModuleType) {
        super.init(module, [self.lowID, self.highID, self.timeToDischargeID])
        
        if Store.shared.exist(key: "\(self.module)_lowLevelNotification") {
            let value = Store.shared.string(key: "\(self.module)_lowLevelNotification", defaultValue: self.lowID)
            Store.shared.set(key: "\(self.module)_notifications_low", value: value)
            Store.shared.remove("\(self.module)_lowLevelNotification")
        }
        if Store.shared.exist(key: "\(self.module)_highLevelNotification") {
            let value = Store.shared.string(key: "\(self.module)_highLevelNotification", defaultValue: self.highLevel)
            Store.shared.set(key: "\(self.module)_notifications_high", value: value)
            Store.shared.remove("\(self.module)_highLevelNotification")
        }
        
        self.lowLevel = Store.shared.string(key: "\(self.module)_notifications_low", defaultValue: self.lowLevel)
        self.highLevel = Store.shared.string(key: "\(self.module)_notifications_high", defaultValue: self.highLevel)
        self.timeToDischargeState = Store.shared.bool(key: "\(self.module)_notifications_timeToDischarge_state", defaultValue: self.timeToDischargeState)
        self.timeToDischarge = Store.shared.int(key: "\(self.module)_notifications_timeToDischarge_value", defaultValue: self.timeToDischarge)

        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Low level notification"), component: selectView(
                action: #selector(self.changeLowLevel),
                items: notificationLevels,
                selected: self.lowLevel
            )),
            PreferencesRow(localizedString("High level notification"), component: selectView(
                action: #selector(self.changeHighLevel),
                items: notificationLevels,
                selected: self.highLevel
            ))
        ]))

        self.addArrangedSubview(PreferencesSection([
            PreferencesRow(localizedString("Time to discharge (less than)"), component: PreferencesSwitch(
                action: self.toggleTimeToDischarge, state: self.timeToDischargeState, with: StepperInput(
                    self.timeToDischarge, range: NSRange(location: 1, length: 998), unit: "min",
                    callback: self.changeTimeToDischarge
                )
            ))
        ]))
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal func usageCallback(_ value: Battery_Usage) {
        if value.isCharging || !value.isBatteryPowered {
            self.hideNotification(self.lowID)
        }
        if let threshold = Double(self.lowLevel), !value.isCharging {
            let title = localizedString("Low battery")
            var subtitle = localizedString("Battery remaining", "\(Int(value.level*100))")
            if value.timeToEmpty > 0 {
                subtitle += " (\(Double(value.timeToEmpty*60).printSecondsToHoursMinutesSeconds()))"
            }
            self.checkDouble(id: self.lowID, value: value.level, threshold: threshold, title: title, subtitle: subtitle, less: true)
        }
        
        if value.isBatteryPowered {
            self.hideNotification(self.highID)
        }
        if let threshold = Double(self.highLevel), value.isCharging {
            let title = localizedString("High battery")
            var subtitle = localizedString("Battery remaining to full charge", "\(Int((1-value.level)*100))")
            if value.timeToCharge > 0 {
                subtitle += " (\(Double(value.timeToCharge*60).printSecondsToHoursMinutesSeconds()))"
            }
            self.checkDouble(id: self.highID, value: value.level, threshold: threshold, title: title, subtitle: subtitle)
        }

        if value.isCharging || !value.isBatteryPowered {
            self.hideNotification(self.timeToDischargeID)
        }
        if self.timeToDischargeState, value.timeToEmpty > 0, !value.isCharging {
            let title = localizedString("Low battery")
            let subtitle = localizedString("Time to discharge is", self.formatMinutes(value.timeToEmpty))
            self.checkDouble(id: self.timeToDischargeID, value: Double(value.timeToEmpty), threshold: Double(self.timeToDischarge), title: title, subtitle: subtitle, less: true)
        }
    }

    private func formatMinutes(_ totalMinutes: Int) -> String {
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        let hoursPart = hours == 1 ? localizedString("1 hour") : localizedString("%0 hours", "\(hours)")
        let minutesPart = minutes == 1 ? localizedString("1 minute") : localizedString("%0 minutes", "\(minutes)")

        if hours == 0 {
            return minutesPart
        }
        if minutes == 0 {
            return hoursPart
        }
        return "\(hoursPart), \(minutesPart)"
    }
    
    @objc private func changeLowLevel(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.lowLevel = key.isEmpty ? "" : "\(Double(key) ?? 0)"
        Store.shared.set(key: "\(self.module)_notifications_low", value: self.lowLevel)
    }
    @objc private func changeHighLevel(_ sender: NSMenuItem) {
        guard let key = sender.representedObject as? String else { return }
        self.highLevel = key.isEmpty ? "" : "\(Double(key) ?? 0)"
        Store.shared.set(key: "\(self.module)_notifications_high", value: self.highLevel)
    }

    @objc private func toggleTimeToDischarge(_ sender: NSControl) {
        self.timeToDischargeState = controlState(sender)
        Store.shared.set(key: "\(self.module)_notifications_timeToDischarge_state", value: self.timeToDischargeState)
    }
    @objc private func changeTimeToDischarge(_ newValue: Int) {
        self.timeToDischarge = newValue
        Store.shared.set(key: "\(self.module)_notifications_timeToDischarge_value", value: self.timeToDischarge)
    }
}
