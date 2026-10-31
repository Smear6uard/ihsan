import IhsanDesignSystem
import SwiftUI

/// The privacy policy, inside the app.
///
/// App Review asks that a policy be reachable from within the app.
/// Carrying it here means the link can never rot, and the words are the
/// same ones `docs/privacy-policy.md` holds for the App Store Connect
/// field. Every sentence is drawn from what the code does — see
/// `docs/app-privacy.md` for the line-by-line derivation — so a change
/// to what the app stores or sends is a change to this file too.
struct PrivacyPolicyScreen: View {
    var body: some View {
        PickerScaffold(title: "Privacy Policy") {
            SettingsSectionCard("The short version") {
                SettingsDescriptionText("Ihsan collects no data. There is no account, no analytics, and no server run by the developer. What you record stays on your devices and in your own iCloud.")
            }

            SettingsSectionCard("What Ihsan keeps") {
                SettingsDescriptionText("Your prayer log, reflections, voice memos, settings, and any makeup or fasting ledgers live in a database on this device. When iCloud is signed in, eligible records sync to your private iCloud database, which only your own devices can read.")
                SettingsDescriptionText("A voice recording stays on the device that made it. Only its transcript and date travel with your other records.")
            }

            SettingsSectionCard("Location") {
                SettingsDescriptionText("Your location is used to compute prayer times, the qibla, and nearby masjids. Coordinates are used in the moment and are never written to storage. Only your city and country are saved, for display.")
                SettingsDescriptionText("Location is read while the app is open. Ihsan never asks for background access and does not know where you have been.")
                SettingsDescriptionText("If you set a masjid as yours, its position is kept so the app can show its times. That is the one coordinate in the store, and removing your masjid removes it.")
            }

            SettingsSectionCard("What leaves your device") {
                SettingsDescriptionText("Ihsan makes four kinds of requests. Three go to Apple: reverse geocoding turns coordinates into a city name; the nearby-masjid search sends your position to Apple Maps only while that sheet is open; a weather reading, only while something in the app uses it: the living sky (Set → Display, off by default) or the weather duas (Set → Adhkār, on by default). The fourth fetches a small file of prayer thresholds and reflection prompts from the developer's public GitHub repository; the same file ships inside the app, so nothing depends on it.")
                SettingsDescriptionText("None of these requests carries anything that identifies you, and nothing is sold, shared, or used for advertising.")
            }

            SettingsSectionCard("Microphone and speech") {
                SettingsDescriptionText("Recording a reflection uses the microphone. Transcription runs on this device with Apple's speech recognition; no audio leaves your phone.")
            }

            SettingsSectionCard("Notifications and alarms") {
                SettingsDescriptionText("Prayer notifications and wake alarms are scheduled on this device. Nothing is sent from a server, and every one of them is yours to switch off.")
            }

            SettingsSectionCard("Your data, your choice") {
                SettingsDescriptionText("Set → Privacy exports your prayer log and reflections as a file you own, and deletes everything with one confirmation. Removing Ihsan from a device removes its local data; what is in iCloud can be removed from iCloud settings.")
            }

            SettingsSectionCard("Changes and contact") {
                SettingsDescriptionText("This policy describes Ihsan 1.0. If it changes, the new version ships with the app and is dated here. Questions can reach the developer through Ihsan's App Store page.")
                SettingsDescriptionText("Effective 5 September 2026 · Sameer Studios LLC")
            }
        }
    }
}
