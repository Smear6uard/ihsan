//
//  ihsanApp.swift
//  ihsan
//
//  Created by Sameer Akhtar on 5/9/26.
//

import SwiftUI
import IhsanCore
import IhsanPrayerTimes

@main
struct ihsanApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .task {
                    do {
                        let provider = AdhanPrayerTimesProvider()
                        let times = try provider.dayTimes(
                            for: .now,
                            coordinates: Coordinates(latitude: 41.8781, longitude: -87.6298),
                            timeZone: .current,
                            calculationMethod: .isna,
                            madhab: .standard,
                            highLatitudeRule: .middleOfNight
                        )

                        let formatter = DateFormatter()
                        formatter.timeStyle = .short
                        formatter.timeZone = .current

                        print("Fajr: \(formatter.string(from: times.fajr.scheduledTime))")
                        print("Isha: \(formatter.string(from: times.isha.scheduledTime))")

                        let next = try provider.nextPrayer(
                            from: .now,
                            coordinates: Coordinates(latitude: 41.8781, longitude: -87.6298),
                            timeZone: .current,
                            calculationMethod: .isna,
                            madhab: .standard,
                            highLatitudeRule: .middleOfNight
                        )
                        print("Next: \(next.prayer.displayNameEnglish) at \(formatter.string(from: next.scheduledTime))")
                    } catch {
                        print("Prayer time smoke test error: \(error)")
                    }
                }
        }
    }
}
