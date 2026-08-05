import SwiftUI
import SwiftData
import UIKit
import UserNotifications
import IhsanCore
import IhsanDesignSystem
import IhsanFiqhConfig
import IhsanInsights
import IhsanLocation
import IhsanNotifications
import IhsanPrayerTimes

@MainActor
struct SettingsScreen: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL

    @Query private var settingsRows: [UserSettings]
    @Query(sort: \PauseInterval.startDate, order: .reverse) private var pauses: [PauseInterval]
    @Query(sort: \TravelInterval.startDate, order: .reverse) private var travels: [TravelInterval]
    @Query(sort: \PrayerLog.prayerDate, order: .reverse) private var prayerLogs: [PrayerLog]
    @Query(sort: \Reflection.forDate, order: .reverse) private var reflections: [Reflection]

    @State private var path: [SettingsRoute] = []
    @State private var latestPlace: LocatedPlace?
    @State private var refreshMessage: String?
    @State private var pauseDescription = ""
    @State private var travelDescription = ""
    @State private var confirmingPauseEnable = false
    @State private var confirmingTravelEnable = false
    @State private var confirmingDeleteAllData = false
    @State private var exportItem: ExportItem?
    @State private var exportError: String?
    @State private var showingRepairSetup = false
    @State private var nightWakeUsesFallback = false

    #if DEBUG
    @State private var showingCoordinates = false
    #endif

    private let locationCoordinator = CoreLocationCoordinator.shared

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
                    header

                    if let settings {
                        LocationSection(
                            settings: settings,
                            latestPlace: latestPlace,
                            refreshMessage: refreshMessage,
                            onCityTap: showCoordinatesIfAvailable,
                            onAutomaticLocationChanged: setAutomaticLocationUpdates(_:for:),
                            onRefresh: { refreshLocation(for: settings) }
                        )

                        CalculationSection(settings: settings, path: $path)
                        MadhabSection(settings: settings, path: $path)
                        HighLatitudeSection(settings: settings, path: $path)
                        NotificationsSection(settings: settings, path: $path, onToggleNotifications: setNotificationsEnabled(_:for:))
                        PauseModeSection(
                            activePause: activePause,
                            description: pauseDescription,
                            onToggle: handlePauseToggle(_:)
                        )
                        TravelModeSection(
                            activeTravel: activeTravel,
                            description: travelDescription,
                            path: $path,
                            onToggle: handleTravelToggle(_:)
                        )
                        MakeupPrayersSection(
                            settings: settings,
                            onBeginSetup: {
                                Haptics.impact(.light)
                                showingRepairSetup = true
                            }
                        )
                        SunnahSection(
                            settings: settings,
                            path: $path,
                            wakeFallbackNote: nightWakeFallbackNote,
                            onWakeSettingsChanged: { refreshNightWake(for: settings) }
                        )
                        AdhkarSection(settings: settings, path: $path)
                        FastingSection(settings: settings)
                        DisplaySection(settings: settings, path: $path)
                        ReflectionSyncSection(settings: settings)
                        if InsightAvailability.isAvailable {
                            OnDeviceInsightsSection(settings: settings)
                        }
                        PrivacySection(
                            onExport: exportData,
                            onDelete: {
                                Haptics.impact(.light)
                                confirmingDeleteAllData = true
                            }
                        )
                        AboutSection(openURL: openURL)
                    } else {
                        ProgressView()
                            .tint(IhsanPageChrome.tokens(at: NowProvider.active.now()).leafGold)
                            .frame(maxWidth: .infinity)
                            .padding(.top, IhsanSpacing.xxl)
                    }

                    Color.clear.frame(height: IhsanSpacing.xl)
                }
                .padding(.horizontal, IhsanSpacing.md)
                .padding(.top, IhsanSpacing.md)
            }
            .ihsanManuscriptPage()
            .navigationDestination(for: SettingsRoute.self) { route in
                if let settings {
                    destination(for: route, settings: settings)
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .task {
            bootstrapSettings()
            latestPlace = locationCoordinator.mostRecentResolvedPlace()
            nightWakeUsesFallback = NightWakeService.shared.usesNotificationFallback
            await loadFiqhFraming()
            #if DEBUG
            openDebugRoute()
            #endif
        }
        // Every settings mutation stamps `modifiedAt`, so this one
        // observer republishes the widget snapshot for all of them —
        // calculation method, madhab, high-latitude rule, tuning,
        // Hijri offset, fasting rhythms. Widgets must never keep
        // yesterday's madhab while the app shows today's.
        .onChange(of: settings?.modifiedAt) { previous, current in
            guard previous != nil, current != nil, previous != current else { return }
            WidgetSnapshotService.republish(using: modelContext)
        }
        .fullScreenCover(isPresented: $showingRepairSetup) {
            RepairSetupFlow()
        }
        .confirmationDialog(
            "Pause prayer tracking?",
            isPresented: $confirmingPauseEnable,
            titleVisibility: .visible
        ) {
            Button("Enable Pause Mode") { createPauseInterval() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Ihsan will mark this period as paused until you turn Pause Mode off.")
        }
        .confirmationDialog(
            "Enable Travel Mode?",
            isPresented: $confirmingTravelEnable,
            titleVisibility: .visible
        ) {
            Button("Enable Travel Mode") { createTravelInterval() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Ihsan will mark this period as travel until you turn Travel Mode off.")
        }
        .confirmationDialog(
            "Delete all Ihsan data?",
            isPresented: $confirmingDeleteAllData,
            titleVisibility: .visible
        ) {
            Button("Delete All Data", role: .destructive, action: deleteAllData)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This removes prayer logs, reflections, pause and travel intervals, summaries, and settings from this device.")
        }
        .sheet(item: $exportItem) { item in
            ActivityView(activityItems: [item.url])
                .presentationDetents([.medium, .large])
        }
        .alert("Export failed", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "")
        }
        #if DEBUG
        .sheet(isPresented: $showingCoordinates) {
            CoordinatesDebugSheet(place: latestPlace)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
                .presentationBackground(.thinMaterial)
        }
        #endif
    }

    private var settings: UserSettings? {
        settingsRows.first
    }

    #if DEBUG
    /// `-IhsanDebugSettingsRoute calculationMethod` — the screenshot
    /// harness opens a settings subscreen directly, so a gallery frame
    /// does not depend on a chain of taps. DEBUG only; release builds
    /// never compile this.
    private func openDebugRoute() {
        let arguments = ProcessInfo.processInfo.arguments
        guard
            let index = arguments.firstIndex(of: "-IhsanDebugSettingsRoute"),
            arguments.indices.contains(index + 1),
            let route = SettingsRoute(debugName: arguments[index + 1])
        else { return }
        path = [route]
    }
    #endif

    private var activePause: PauseInterval? {
        pauses.first(where: \.isActive)
    }

    private var activeTravel: TravelInterval? {
        travels.first(where: \.isActive)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Quiet preferences")
                .font(.system(size: 32, weight: .medium, design: .serif))
                .foregroundStyle(IhsanPageChrome.tokens(at: NowProvider.active.now()).ink)
                .accessibilityAddTraits(.isHeader)
            Text("SETTINGS")
                .font(IhsanFont.inscription)
                .tracking(2.0)
                .foregroundStyle(IhsanPageChrome.tokens(at: NowProvider.active.now()).inkSecondary)
            OrnamentalDivider(
                tint: IhsanPageChrome.tokens(at: NowProvider.active.now()).metal,
                opacity: 0.5
            )
                .padding(.top, IhsanSpacing.xs)
        }
    }

    @ViewBuilder
    private func destination(for route: SettingsRoute, settings: UserSettings) -> some View {
        switch route {
        case .calculationMethod:
            CalculationMethodPicker(settings: settings)
        case .madhab:
            MadhabPicker(settings: settings)
        case .highLatitudeRule:
            HighLatitudeRulePicker(settings: settings)
        case .adhanSound:
            AdhanSoundPicker(settings: settings)
        case .jamPolicy:
            if let activeTravel {
                JamPolicyPicker(travel: activeTravel)
            }
        case .theme:
            ThemePicker(settings: settings)
        case .rawatibCounts:
            RawatibCountsPicker(settings: settings)
        case .duhaWindow:
            DuhaWindowPicker(settings: settings)
        case .adhkarWindows:
            AdhkarWindowsPicker(settings: settings)
        }
    }

    private var nightWakeFallbackNote: String? {
        guard settings?.nightWakeEnabled == true, nightWakeUsesFallback else { return nil }
        return "Alarms aren't permitted on this device, so the wake arrives as a time-sensitive notification instead."
    }

    /// Re-syncs the standing wake after any wake-related change in Set,
    /// requesting alarm permission the moment the user turns it on.
    private func refreshNightWake(for settings: UserSettings) {
        Task {
            if settings.nightWakeEnabled {
                await NightWakeService.shared.requestAlarmAuthorizationIfNeeded()
            }
            await NightWakeService.shared.refresh(using: modelContext)
            nightWakeUsesFallback = NightWakeService.shared.usesNotificationFallback
        }
    }

    private func bootstrapSettings() {
        do {
            _ = try UserSettings.fetchOrCreate(in: modelContext)
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func loadFiqhFraming() async {
        do {
            let framing = try await FiqhConfigService.shared.currentConfig().framing
            pauseDescription = framing.pauseModeDescription
            travelDescription = framing.travelModeDescription
        } catch {
            pauseDescription = "Pause Mode keeps a period out of prayer-log expectations. Ihsan does not ask why."
            travelDescription = "Travel Mode marks a travel period and exposes jam and qasr controls."
        }
    }

    private func showCoordinatesIfAvailable() {
        #if DEBUG
        Haptics.impact(.medium)
        showingCoordinates = true
        #endif
    }

    private func setAutomaticLocationUpdates(_ isEnabled: Bool, for settings: UserSettings) {
        Haptics.impact(.light)
        settings.automaticLocationUpdatesEnabled = isEnabled
        settings.modifiedAt = .now
        Task {
            do {
                if isEnabled {
                    _ = try await locationCoordinator.requestAlwaysAuthorization()
                    try await locationCoordinator.startMonitoringSignificantChanges()
                    refreshMessage = "Automatic updates enabled"
                } else {
                    await locationCoordinator.stopMonitoringSignificantChanges()
                    refreshMessage = "Automatic updates disabled"
                }
            } catch let error as LocationError {
                if error == .permissionDenied || error == .permissionRestricted {
                    Haptics.notification(.warning)
                }
                refreshMessage = error.userFacingMessage
            } catch {
                refreshMessage = error.localizedDescription
            }
        }
    }

    private func refreshLocation(for settings: UserSettings) {
        Haptics.impact(.light)
        refreshMessage = "Refreshing location..."
        Task {
            do {
                _ = try await locationCoordinator.requestWhenInUseAuthorization()
                let place = try await locationCoordinator.currentPlace(timeout: 12, staleAfter: 0)
                latestPlace = place
                settings.lastResolvedCityName = place.cityName
                settings.lastResolvedCountryCode = place.countryCode
                settings.modifiedAt = .now
                refreshMessage = "Location refreshed"
            } catch let error as LocationError {
                if error == .permissionDenied || error == .permissionRestricted {
                    Haptics.notification(.warning)
                }
                refreshMessage = error.userFacingMessage
            } catch {
                refreshMessage = error.localizedDescription
            }
        }
    }

    private func setNotificationsEnabled(_ isEnabled: Bool, for settings: UserSettings) {
        settings.notificationsEnabled = isEnabled
        settings.modifiedAt = .now
        guard isEnabled else { return }

        Task {
            do {
                let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
                if !granted {
                    settings.notificationsEnabled = false
                    settings.modifiedAt = .now
                }
            } catch {
                settings.notificationsEnabled = false
                settings.modifiedAt = .now
            }
        }
    }

    private func handlePauseToggle(_ isEnabled: Bool) {
        if isEnabled {
            confirmingPauseEnable = true
        } else {
            closePauseInterval()
        }
    }

    private func createPauseInterval() {
        guard activePause == nil else { return }
        Haptics.impact(.medium)
        let now = Date.now
        modelContext.insert(PauseInterval(
            startDate: now,
            loggedTimeZoneIdentifier: TimeZone.current.identifier,
            createdAt: now,
            modifiedAt: now
        ))
        Haptics.notification(.success)
        rebuildNotificationSchedule()
    }

    private func closePauseInterval() {
        guard let activePause else { return }
        let now = Date.now
        activePause.endDate = now
        activePause.modifiedAt = now
        Haptics.notification(.success)
        rebuildNotificationSchedule()
    }

    /// Prayer notifications suppress for the duration of a pause and return
    /// untouched when it ends; the schedule is derived, so a rebuild is all
    /// either transition needs.
    private func rebuildNotificationSchedule() {
        Task {
            try? await NotificationScheduler.shared.rebuildSchedule()
            // The gentle wake honors the same pause the notification
            // schedule does — re-sync it whenever the schedule rebuilds.
            await NightWakeService.shared.refresh(using: modelContext)
        }
        // Pause and travel transitions change what a widget may show
        // (a paused day carries no logging surface at all).
        WidgetSnapshotService.republish(using: modelContext)
    }

    private func handleTravelToggle(_ isEnabled: Bool) {
        if isEnabled {
            confirmingTravelEnable = true
        } else {
            closeTravelInterval()
        }
    }

    private func createTravelInterval() {
        guard activeTravel == nil else { return }
        Haptics.impact(.medium)
        let now = Date.now
        modelContext.insert(TravelInterval(
            startDate: now,
            loggedTimeZoneIdentifier: TimeZone.current.identifier,
            createdAt: now,
            modifiedAt: now
        ))
        Haptics.notification(.success)
    }

    private func closeTravelInterval() {
        guard let activeTravel else { return }
        let now = Date.now
        activeTravel.endDate = now
        activeTravel.modifiedAt = now
        Haptics.notification(.success)
    }

    private func exportData() {
        Haptics.impact(.medium)
        do {
            let payload = SettingsExportPayload(
                exportedAt: .now,
                prayerLogs: prayerLogs.map(ExportPrayerLog.init),
                reflections: reflections.map(ExportReflection.init)
            )
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(payload)
            let url = FileManager.default.temporaryDirectory
                .appendingPathComponent("ihsan-export-\(Self.exportFilenameDate()).json")
            try data.write(to: url, options: [.atomic])
            settings?.lastDataExportAt = .now
            settings?.modifiedAt = .now
            exportItem = ExportItem(url: url)
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func deleteAllData() {
        Haptics.impact(.medium)
        do {
            try deleteAll(PrayerLog.self)
            try deleteAll(Reflection.self)
            try deleteAll(DayRecord.self)
            try deleteAll(PauseInterval.self)
            try deleteAll(TravelInterval.self)
            try deleteAll(PeriodSummary.self)
            try deleteAll(QadaEntry.self)
            try deleteAll(QadaLedger.self)
            try deleteAll(UserSettings.self)
            _ = try UserSettings.fetchOrCreate(in: modelContext)
            Haptics.notification(.success)
        } catch {
            exportError = error.localizedDescription
        }
    }

    private func deleteAll<T: PersistentModel>(_ type: T.Type) throws {
        let records = try modelContext.fetch(FetchDescriptor<T>())
        for record in records {
            modelContext.delete(record)
        }
    }

    private static func exportFilenameDate() -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        return formatter.string(from: .now)
    }
}

private enum SettingsRoute: Hashable {
    case calculationMethod
    case madhab
    case highLatitudeRule
    case adhanSound
    case jamPolicy
    case theme
    case rawatibCounts
    case duhaWindow
    case adhkarWindows

    #if DEBUG
    init?(debugName: String) {
        switch debugName {
        case "calculationMethod": self = .calculationMethod
        case "madhab": self = .madhab
        case "highLatitudeRule": self = .highLatitudeRule
        case "adhanSound": self = .adhanSound
        case "jamPolicy": self = .jamPolicy
        case "theme": self = .theme
        case "rawatibCounts": self = .rawatibCounts
        case "duhaWindow": self = .duhaWindow
        case "adhkarWindows": self = .adhkarWindows
        default: return nil
        }
    }
    #endif
}

// MARK: - Sections
// Haptics audit: navigation rows use `.light`; destructive confirmations,
// sheet-like exports, and pause/travel mode commits use `.medium` plus
// success/warning notifications. Routine SwiftUI `Toggle` controls do not
// add extra custom haptics beyond the locked map, to avoid noisy settings
// scrubbing when users flip several switches in sequence.

private struct LocationSection: View {
    let settings: UserSettings
    let latestPlace: LocatedPlace?
    let refreshMessage: String?
    let onCityTap: () -> Void
    let onAutomaticLocationChanged: (Bool, UserSettings) -> Void
    let onRefresh: () -> Void

    var body: some View {
            SettingsSectionCard("Location") {
            #if DEBUG
            SettingsRow(
                title: currentCityTitle,
                subtitle: currentCitySubtitle,
                glyph: .location,
                action: onCityTap
            ) { EmptyView() }
            #else
            SettingsRow(
                title: currentCityTitle,
                subtitle: currentCitySubtitle,
                glyph: .location
            ) { EmptyView() }
            #endif

            SettingsRow(title: "Automatic location updates", glyph: .location) {
                Toggle("", isOn: Binding(
                    get: { settings.automaticLocationUpdatesEnabled },
                    set: { onAutomaticLocationChanged($0, settings) }
                ))
                .labelsHidden()
                .tint(IhsanPageChrome.tokens(at: NowProvider.active.now()).leafGold)
                .accessibilityLabel("Automatic location updates")
            }

            SettingsRow(
                title: "Refresh location now",
                subtitle: refreshMessage,
                glyph: .location,
                action: onRefresh
            )
        }
    }

    private var currentCityTitle: String {
        latestPlace?.cityName ?? settings.lastResolvedCityName ?? "Current Location"
    }

    private var currentCitySubtitle: String {
        latestPlace?.countryCode ?? settings.lastResolvedCountryCode ?? "City resolves after location refresh"
    }
}

private struct CalculationSection: View {
    let settings: UserSettings
    @Binding var path: [SettingsRoute]

    var body: some View {
        let description = CalculationDescription.resolve(
            method: settings.calculationMethod,
            tuning: settings.calculationTuning
        )

        SettingsSectionCard("Calculation Method") {
            SettingsRow(
                title: "Current method",
                subtitle: description.title,
                glyph: .method,
                action: {
                    Haptics.impact(.light)
                    path.append(.calculationMethod)
                }
            )
            .accessibilityValue(description.spokenTitle)

            if !settings.calculationTuning.offsets.isEmpty {
                SettingsDescriptionText(offsetSummary)
            }
        }
    }

    /// Offsets are quiet but never hidden: a person who set one months
    /// ago should be able to see it from the settings root, because a
    /// forgotten offset looks exactly like a wrong app.
    private var offsetSummary: String {
        let offsets = settings.calculationTuning.offsets
        let parts = Prayer.allCases.compactMap { prayer -> String? in
            let minutes = offsets[prayer]
            guard minutes != 0 else { return nil }
            let sign = minutes > 0 ? "+" : "−"
            return "\(prayer.displayNameEnglish) \(sign)\(abs(minutes))"
        }
        return "Manual offsets: " + parts.joined(separator: ", ") + " min."
    }
}

private struct MadhabSection: View {
    let settings: UserSettings
    @Binding var path: [SettingsRoute]

    var body: some View {
        SettingsSectionCard("Asr Method") {
            SettingsRow(
                title: "Current choice",
                subtitle: settings.madhab.settingsDisplayName,
                glyph: .asrShadow,
                action: {
                    Haptics.impact(.light)
                    path.append(.madhab)
                }
            )
        }
    }
}

private struct HighLatitudeSection: View {
    let settings: UserSettings
    @Binding var path: [SettingsRoute]

    var body: some View {
        SettingsSectionCard("High Latitude Rule") {
            SettingsRow(
                title: "Current rule",
                subtitle: settings.highLatitudeRule.settingsDisplayName,
                glyph: .highLatitude,
                action: {
                    Haptics.impact(.light)
                    path.append(.highLatitudeRule)
                }
            )

            SettingsDescriptionText("This matters for users above approximately 48 degrees latitude, where twilight can be unusually long or absent in parts of the year.")
        }
    }
}

private struct NotificationsSection: View {
    let settings: UserSettings
    @Binding var path: [SettingsRoute]
    let onToggleNotifications: (Bool, UserSettings) -> Void

    var body: some View {
        SettingsSectionCard("Notifications") {
            SettingsRow(title: "Adhan notifications", glyph: .adhan) {
                Toggle("", isOn: Binding(
                    get: { settings.notificationsEnabled },
                    set: { onToggleNotifications($0, settings) }
                ))
                .labelsHidden()
                .tint(IhsanPageChrome.tokens(at: NowProvider.active.now()).leafGold)
                .accessibilityLabel("Adhan notifications")
            }

            if settings.notificationsEnabled {
                SettingsRow(
                    title: "Adhan",
                    subtitle: soundSummary,
                    glyph: .adhan,
                    action: {
                        Haptics.impact(.light)
                        path.append(.adhanSound)
                    }
                )

                ForEach(Prayer.allCases, id: \.self) { prayer in
                    SettingsRow(title: prayer.displayNameEnglish, glyph: .adhan) {
                        Toggle("", isOn: prayerNotificationBinding(for: prayer))
                            .labelsHidden()
                            .tint(IhsanPageChrome.tokens(at: NowProvider.active.now()).leafGold)
                            .accessibilityLabel("\(prayer.displayNameEnglish) notification")
                    }
                }
            }
        }
    }

    /// "Chime" when every prayer agrees, "Mixed" when they do not — so
    /// the row never claims a single answer that isn't true.
    private var soundSummary: String {
        let sounds = Set(Prayer.allCases.map { settings.sound(for: $0) })
        guard sounds.count == 1, let only = sounds.first else { return "Mixed" }
        return only.displayName
    }

    private func prayerNotificationBinding(for prayer: Prayer) -> Binding<Bool> {
        Binding(
            get: { settings.notificationEnabled(for: prayer) },
            set: { isEnabled in
                settings.setNotificationEnabled(isEnabled, for: prayer)
                settings.modifiedAt = .now
            }
        )
    }
}

private struct PauseModeSection: View {
    let activePause: PauseInterval?
    let description: String
    let onToggle: (Bool) -> Void

    var body: some View {
        SettingsSectionCard("Pause Mode") {
            SettingsRow(
                title: "Status",
                subtitle: activePause.map { "Active since \($0.startDate.formatted(date: .abbreviated, time: .shortened))" } ?? "Inactive",
                glyph: .pause
            ) {
                Toggle("", isOn: Binding(
                    get: { activePause != nil },
                    set: onToggle
                ))
                .labelsHidden()
                .tint(IhsanPageChrome.tokens(at: NowProvider.active.now()).leafGold)
                .accessibilityLabel("Pause Mode")
            }

            if let activePause {
                SettingsRow(
                    title: "Expected end",
                    subtitle: "Nothing ends without you",
                    glyph: .calendar
                ) {
                    Toggle("", isOn: Binding(
                        get: { activePause.expectedEndDate != nil },
                        set: { hasExpectedEnd in
                            activePause.expectedEndDate = hasExpectedEnd
                                ? Calendar.current.date(byAdding: .day, value: 7, to: .now)
                                : nil
                            activePause.modifiedAt = .now
                        }
                    ))
                    .labelsHidden()
                    .tint(IhsanPageChrome.tokens(at: NowProvider.active.now()).leafGold)
                    .accessibilityLabel("Expected end date")
                }

                if let expectedEnd = activePause.expectedEndDate {
                    SettingsRow(title: "Around", glyph: .clock) {
                        DatePicker(
                            "",
                            selection: Binding(
                                get: { expectedEnd },
                                set: {
                                    activePause.expectedEndDate = $0
                                    activePause.modifiedAt = .now
                                }
                            ),
                            in: Date.now...,
                            displayedComponents: .date
                        )
                        .labelsHidden()
                        .accessibilityLabel("Expected end date picker")
                    }
                }
            }

            SettingsDescriptionText(description)
        }
    }
}

private struct TravelModeSection: View {
    let activeTravel: TravelInterval?
    let description: String
    @Binding var path: [SettingsRoute]
    let onToggle: (Bool) -> Void

    var body: some View {
        SettingsSectionCard("Travel Mode") {
            SettingsRow(
                title: "Status",
                subtitle: activeTravel.map { "Active since \($0.startDate.formatted(date: .abbreviated, time: .shortened))" } ?? "Inactive",
                glyph: .travel
            ) {
                Toggle("", isOn: Binding(
                    get: { activeTravel != nil },
                    set: onToggle
                ))
                .labelsHidden()
                .tint(IhsanPageChrome.tokens(at: NowProvider.active.now()).leafGold)
                .accessibilityLabel("Travel Mode")
            }

            if let activeTravel {
                SettingsRow(
                    title: "Jam policy",
                    subtitle: activeTravel.jamPolicy.settingsDisplayName,
                    glyph: .jam,
                    action: {
                        Haptics.impact(.light)
                        path.append(.jamPolicy)
                    }
                )

                SettingsRow(title: "Qasr enabled", glyph: .qasr) {
                    Toggle("", isOn: Binding(
                        get: { activeTravel.qasrEnabled },
                        set: {
                            activeTravel.qasrEnabled = $0
                            activeTravel.modifiedAt = .now
                        }
                    ))
                    .labelsHidden()
                    .tint(IhsanPageChrome.tokens(at: NowProvider.active.now()).leafGold)
                    .accessibilityLabel("Qasr enabled")
                }
            }

            SettingsDescriptionText(description)
        }
    }
}

private struct MakeupPrayersSection: View {
    let settings: UserSettings
    let onBeginSetup: () -> Void

    var body: some View {
        SettingsSectionCard("Makeup Prayers") {
            if settings.qadaTrackingEnabled {
                SettingsRow(
                    title: "Unlogged prayers flow here",
                    subtitle: "When a day passes without a record",
                    glyph: .makeupLedger
                ) {
                    Toggle("", isOn: Binding(
                        get: { settings.qadaMissedFlowEnabled },
                        set: {
                            settings.qadaMissedFlowEnabled = $0
                            settings.modifiedAt = .now
                        }
                    ))
                    .labelsHidden()
                    .tint(IhsanPageChrome.tokens(at: NowProvider.active.now()).leafGold)
                    .accessibilityLabel("Unlogged prayers flow into makeup count")
                }

                SettingsRow(title: "Track witr", glyph: .nightMoon) {
                    Toggle("", isOn: Binding(
                        get: { settings.qadaTracksWitr },
                        set: {
                            settings.qadaTracksWitr = $0
                            settings.modifiedAt = .now
                        }
                    ))
                    .labelsHidden()
                    .tint(IhsanPageChrome.tokens(at: NowProvider.active.now()).leafGold)
                    .accessibilityLabel("Track witr makeups")
                }

                SettingsDescriptionText("Your makeup counts live on the Path screen, at your pace.")
            } else {
                SettingsRow(
                    title: "Makeup prayers",
                    subtitle: "At your pace",
                    glyph: .makeupLedger,
                    action: onBeginSetup
                )

                SettingsDescriptionText("If you carry prayers to return to, Ihsan can hold the count with you. Nothing is shown until you choose it.")
            }
        }
    }
}

private struct SunnahSection: View {
    let settings: UserSettings
    @Binding var path: [SettingsRoute]
    /// Plain-spoken note shown when the wake will arrive as a
    /// time-sensitive notification rather than a true alarm.
    var wakeFallbackNote: String?
    var onWakeSettingsChanged: () -> Void = {}

    var body: some View {
        SettingsSectionCard("Sunnah & Night Prayer") {
            SettingsRow(title: "Sunnah & night prayer", glyph: .nightMoon) {
                Toggle("", isOn: Binding(
                    get: { settings.sunnahLayerEnabled },
                    set: { enabled in
                        settings.sunnahLayerEnabled = enabled
                        if enabled,
                           !settings.sunnahRawatibEnabled,
                           !settings.sunnahDuhaEnabled,
                           !settings.sunnahNightEnabled {
                            // First enable turns the whole layer on; each
                            // component stays individually switchable below.
                            settings.sunnahRawatibEnabled = true
                            settings.sunnahDuhaEnabled = true
                            settings.sunnahNightEnabled = true
                        }
                        settings.modifiedAt = .now
                        onWakeSettingsChanged()
                    }
                ))
                .labelsHidden()
                .tint(IhsanPageChrome.tokens(at: NowProvider.active.now()).leafGold)
                .accessibilityLabel("Sunnah and night prayer")
            }

            if settings.sunnahLayerEnabled {
                SettingsRow(title: "Rawatib", subtitle: "Around each fard", glyph: .rawatib) {
                    Toggle("", isOn: Binding(
                        get: { settings.sunnahRawatibEnabled },
                        set: {
                            settings.sunnahRawatibEnabled = $0
                            settings.modifiedAt = .now
                        }
                    ))
                    .labelsHidden()
                    .tint(IhsanPageChrome.tokens(at: NowProvider.active.now()).leafGold)
                    .accessibilityLabel("Rawatib")
                }

                if settings.sunnahRawatibEnabled {
                    SettingsRow(
                        title: "Rawatib counts",
                        subtitle: "Yours to set",
                        glyph: .counts,
                        action: {
                            Haptics.impact(.light)
                            path.append(.rawatibCounts)
                        }
                    )
                }

                SettingsRow(title: "Duha", subtitle: "The forenoon prayer", glyph: .sun) {
                    Toggle("", isOn: Binding(
                        get: { settings.sunnahDuhaEnabled },
                        set: {
                            settings.sunnahDuhaEnabled = $0
                            settings.modifiedAt = .now
                        }
                    ))
                    .labelsHidden()
                    .tint(IhsanPageChrome.tokens(at: NowProvider.active.now()).leafGold)
                    .accessibilityLabel("Duha")
                }

                if settings.sunnahDuhaEnabled {
                    SettingsRow(
                        title: "Duha window",
                        subtitle: duhaWindowSubtitle,
                        glyph: .clock,
                        action: {
                            Haptics.impact(.light)
                            path.append(.duhaWindow)
                        }
                    )
                }

                SettingsRow(title: "Night prayer", subtitle: "Qiyam and witr", glyph: .nightMoon) {
                    Toggle("", isOn: Binding(
                        get: { settings.sunnahNightEnabled },
                        set: {
                            settings.sunnahNightEnabled = $0
                            settings.modifiedAt = .now
                            onWakeSettingsChanged()
                        }
                    ))
                    .labelsHidden()
                    .tint(IhsanPageChrome.tokens(at: NowProvider.active.now()).leafGold)
                    .accessibilityLabel("Night prayer")
                }

                if settings.sunnahNightEnabled {
                    SettingsRow(title: "Gentle wake", subtitle: "For the last third", glyph: .clock) {
                        Toggle("", isOn: Binding(
                            get: { settings.nightWakeEnabled },
                            set: {
                                settings.nightWakeEnabled = $0
                                settings.modifiedAt = .now
                                onWakeSettingsChanged()
                            }
                        ))
                        .labelsHidden()
                        .tint(IhsanPageChrome.tokens(at: NowProvider.active.now()).leafGold)
                        .accessibilityLabel("Gentle wake")
                    }

                    if settings.nightWakeEnabled {
                        HStack {
                            miniCountControl(
                                label: "Wake before it begins (min)",
                                value: settings.nightWakeOffsetMinutes,
                                step: 5,
                                range: 0...60,
                                accessibilityLabel: "Minutes before the last third to wake"
                            ) {
                                settings.nightWakeOffsetMinutes = $0
                                settings.modifiedAt = .now
                                onWakeSettingsChanged()
                            }
                            Spacer()
                        }
                        .padding(.vertical, IhsanSpacing.xs)

                        SettingsDescriptionText("The last third of the night is computed from each night's own span, Maghrib to the coming Fajr — the wake follows it, softly, and never rings during a pause.")

                        if let wakeFallbackNote {
                            SettingsDescriptionText(wakeFallbackNote)
                        }
                    }
                }

                SettingsRow(title: "Ask for rak'ah counts", subtitle: "Off: one tap records", glyph: .counts) {
                    Toggle("", isOn: Binding(
                        get: { settings.sunnahRakahCountsEnabled },
                        set: {
                            settings.sunnahRakahCountsEnabled = $0
                            settings.modifiedAt = .now
                        }
                    ))
                    .labelsHidden()
                    .tint(IhsanPageChrome.tokens(at: NowProvider.active.now()).leafGold)
                    .accessibilityLabel("Ask for rak'ah counts")
                }

                SettingsDescriptionText("Recorded, never scored. Voluntary prayer keeps its own quiet ledger and counts toward nothing.")
            } else {
                SettingsDescriptionText("Rawatib, duha, and the night prayer, held as quietly as the rest. Nothing is shown until you choose it.")
            }
        }
    }

    private var duhaWindowSubtitle: String {
        "Sunrise +\(settings.duhaSunriseOffsetMinutes) min to Dhuhr −\(settings.duhaDhuhrMarginMinutes) min"
    }
}

/// The Adhkar group.
///
/// Off by default and invisible in the off state — the same discipline
/// as the sunnah layer. Nothing here mentions what is missing, and
/// nothing here schedules a notification: the windows offer, they never
/// call.
///
/// While the bundled content is unreviewed, a release build has no
/// adhkar at all and this section does not appear. A DEBUG build shows
/// it, and says DRAFT plainly.
private struct AdhkarSection: View {
    let settings: UserSettings
    @Binding var path: [SettingsRoute]

    var body: some View {
        if AdhkarAvailability.isAvailable {
            SettingsSectionCard("Adhkār") {
                SettingsRow(title: "Adhkār & duʿāʾ", glyph: .book) {
                    Toggle("", isOn: Binding(
                        get: { settings.adhkarLayerEnabled },
                        set: { enabled in
                            settings.adhkarLayerEnabled = enabled
                            if enabled,
                               !settings.adhkarMorningEnabled,
                               !settings.adhkarEveningEnabled,
                               !settings.adhkarPostPrayerEnabled,
                               !settings.adhkarSleepEnabled {
                                // First enable turns the whole layer
                                // on; each set stays switchable below.
                                settings.adhkarMorningEnabled = true
                                settings.adhkarEveningEnabled = true
                                settings.adhkarPostPrayerEnabled = true
                                settings.adhkarSleepEnabled = true
                            }
                            settings.modifiedAt = .now
                        }
                    ))
                    .labelsHidden()
                    .tint(IhsanPageChrome.tokens(at: NowProvider.active.now()).leafGold)
                    .accessibilityLabel("Adhkār and duʿāʾ")
                }

                if settings.adhkarLayerEnabled {
                    SettingsRow(title: "Morning", subtitle: "Fajr into mid-morning", glyph: .sun) {
                        toggle(
                            label: "Morning adhkār",
                            get: { settings.adhkarMorningEnabled },
                            set: { settings.adhkarMorningEnabled = $0 }
                        )
                    }

                    SettingsRow(title: "Evening", subtitle: "Maghrib into the early night", glyph: .nightMoon) {
                        toggle(
                            label: "Evening adhkār",
                            get: { settings.adhkarEveningEnabled },
                            set: { settings.adhkarEveningEnabled = $0 }
                        )
                    }

                    SettingsRow(title: "After each prayer", subtitle: "From a logged prayer", glyph: .rawatib) {
                        toggle(
                            label: "After-prayer adhkār",
                            get: { settings.adhkarPostPrayerEnabled },
                            set: { settings.adhkarPostPrayerEnabled = $0 }
                        )
                    }

                    SettingsRow(title: "Before sleep", subtitle: "After ʿIshāʾ is logged", glyph: .nightMoon) {
                        toggle(
                            label: "Before-sleep adhkār",
                            get: { settings.adhkarSleepEnabled },
                            set: { settings.adhkarSleepEnabled = $0 }
                        )
                    }

                    SettingsRow(
                        title: "Window bounds",
                        subtitle: windowSubtitle,
                        glyph: .clock,
                        action: {
                            Haptics.impact(.light)
                            path.append(.adhkarWindows)
                        }
                    )

                    SettingsRow(title: "Show transliteration", subtitle: "Romanised, beneath the Arabic", glyph: .book) {
                        toggle(
                            label: "Show transliteration",
                            get: { settings.adhkarShowsTransliteration },
                            set: { settings.adhkarShowsTransliteration = $0 }
                        )
                    }

                    SettingsDescriptionText("Each set is offered inside its own window and nowhere else. Sittings are recorded as plain facts and count toward nothing. Nothing here sends a notification.")

                    if AdhkarAvailability.isShowingDraftContent {
                        SettingsDescriptionText("DRAFT — these texts are awaiting a scholar's review and cannot ship. See ADHKAR_REVIEW.md.")
                    }
                } else {
                    SettingsDescriptionText("The day's remembrance, offered at its own times. Nothing is shown until you choose it.")
                }
            }
        }
    }

    private func toggle(
        label: String,
        get: @escaping () -> Bool,
        set: @escaping (Bool) -> Void
    ) -> some View {
        Toggle("", isOn: Binding(
            get: get,
            set: { newValue in
                set(newValue)
                settings.modifiedAt = .now
            }
        ))
        .labelsHidden()
        .tint(IhsanPageChrome.tokens(at: NowProvider.active.now()).leafGold)
        .accessibilityLabel(label)
    }

    private var windowSubtitle: String {
        "Sunrise +\(settings.adhkarMorningEndsAfterSunriseMinutes) min · Maghrib +\(settings.adhkarEveningExtendsAfterMaghribMinutes) min"
    }
}

private struct AdhkarWindowsPicker: View {
    let settings: UserSettings

    var body: some View {
        PickerScaffold(title: "Adhkār Windows") {
            SettingsSectionCard("The morning") {
                VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
                    miniCountControl(
                        label: "Ends after sunrise (min)",
                        value: settings.adhkarMorningEndsAfterSunriseMinutes,
                        step: 15,
                        range: 0...240,
                        accessibilityLabel: "Minutes after sunrise the morning window ends"
                    ) {
                        settings.adhkarMorningEndsAfterSunriseMinutes = $0
                        settings.modifiedAt = .now
                    }
                }
                .settingsControlInset()
                .padding(.vertical, IhsanSpacing.xs)

                SettingsDescriptionText("The morning begins at Fajr. Schools differ on where it ends — at sunrise for some, into mid-morning for others. It never runs past Dhuhr.")
            }

            SettingsSectionCard("The evening") {
                VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
                    miniCountControl(
                        label: "Extends past Maghrib (min)",
                        value: settings.adhkarEveningExtendsAfterMaghribMinutes,
                        step: 15,
                        range: 15...180,
                        accessibilityLabel: "Minutes after Maghrib the evening window ends"
                    ) {
                        settings.adhkarEveningExtendsAfterMaghribMinutes = $0
                        settings.modifiedAt = .now
                    }
                }
                .settingsControlInset()
                .padding(.vertical, IhsanSpacing.xs)

                SettingsDescriptionText("The evening offer begins at Maghrib so it follows the visible turn of the day. Choose how long it remains available; it never runs past ʿIshāʾ.")
            }

            SettingsSectionCard("Before sleep") {
                SettingsDescriptionText("Offered from ʿIshāʾ until the coming Fajr, once ʿIshāʾ is logged. It follows the prayer rather than the hour, so there is nothing to set.")
            }
        }
    }
}

private struct RawatibCountsPicker: View {
    let settings: UserSettings

    var body: some View {
        PickerScaffold(title: "Rawatib Counts") {
            SettingsSectionCard("Before and after each fard") {
                ForEach(Prayer.allCases, id: \.self) { prayer in
                    RawatibCountRow(prayer: prayer, settings: settings)
                }

                SettingsDescriptionText("Schools differ on rawatib counts; the ones here are a common set, and every count is yours to change.")
            }
        }
    }
}

private struct RawatibCountRow: View {
    let prayer: Prayer
    let settings: UserSettings

    var body: some View {
        let config = settings.rawatibConfig(for: prayer)
        VStack(alignment: .leading, spacing: IhsanSpacing.xs) {
            Divider()
                .overlay(IhsanPageChrome.tokens(at: NowProvider.active.now()).metal.opacity(0.18))
            Text(prayer.displayNameEnglish)
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(IhsanPageChrome.tokens(at: NowProvider.active.now()).ink)
            HStack(spacing: IhsanSpacing.lg) {
                miniCountControl(
                    label: "Before",
                    value: config.beforeCount,
                    accessibilityLabel: "Rak'ah before \(prayer.displayNameEnglish)"
                ) { newValue in
                    var updated = config
                    updated.beforeCount = newValue
                    settings.setRawatibConfig(updated)
                    settings.modifiedAt = .now
                }
                miniCountControl(
                    label: "After",
                    value: config.afterCount,
                    accessibilityLabel: "Rak'ah after \(prayer.displayNameEnglish)"
                ) { newValue in
                    var updated = config
                    updated.afterCount = newValue
                    settings.setRawatibConfig(updated)
                    settings.modifiedAt = .now
                }
                Spacer()
            }
        }
        .settingsControlInset()
        .padding(.vertical, IhsanSpacing.xs)
    }
}

private struct DuhaWindowPicker: View {
    let settings: UserSettings

    var body: some View {
        PickerScaffold(title: "Duha Window") {
            SettingsSectionCard("The forenoon window") {
                VStack(alignment: .leading, spacing: IhsanSpacing.sm) {
                    miniCountControl(
                        label: "Begins after sunrise (min)",
                        value: settings.duhaSunriseOffsetMinutes,
                        step: 5,
                        range: 5...60,
                        accessibilityLabel: "Minutes after sunrise the duha window begins"
                    ) {
                        settings.duhaSunriseOffsetMinutes = $0
                        settings.modifiedAt = .now
                    }
                    miniCountControl(
                        label: "Ends before Dhuhr (min)",
                        value: settings.duhaDhuhrMarginMinutes,
                        step: 5,
                        range: 5...60,
                        accessibilityLabel: "Minutes before Dhuhr the duha window ends"
                    ) {
                        settings.duhaDhuhrMarginMinutes = $0
                        settings.modifiedAt = .now
                    }
                }
                .settingsControlInset()
                .padding(.vertical, IhsanSpacing.xs)

                SettingsDescriptionText("Schools differ on the window's edges; both offsets are yours to set.")
            }
        }
    }
}

private extension View {
    /// The inset every direct child of a `SettingsSectionCard` owes the
    /// card. `SettingsRow` and `SettingsDescriptionText` apply it
    /// themselves; hand-built controls have to say so, or they hang off
    /// the panel's left edge and sit centred instead of aligned.
    func settingsControlInset() -> some View {
        frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, IhsanSpacing.md)
    }
}

/// A compact −/+ count control in the settings idiom: quiet label above,
/// two 28pt brass buttons around a monospaced value.
private func miniCountControl(
    label: String,
    value: Int,
    step: Int = 1,
    range: ClosedRange<Int> = 0...12,
    accessibilityLabel: String,
    /// Spoken form when the bare number would mislead — a signed
    /// offset reads as "minus three minutes", not "-3".
    valueDescription: String? = nil,
    onChange: @escaping (Int) -> Void
) -> some View {
    // A range that reaches below zero is a correction, not a count, and
    // its sign has to be visible at a glance.
    let signed = range.lowerBound < 0
    let displayed = signed && value > 0 ? "+\(value)" : (signed && value < 0 ? "−\(abs(value))" : "\(value)")

    return VStack(alignment: .leading, spacing: 4) {
        Text(label.uppercased())
            .font(IhsanFont.inscription)
            .tracking(1.2)
            .foregroundStyle(IhsanPageChrome.tokens(at: NowProvider.active.now()).inkSecondary.opacity(0.7))
        HStack(spacing: IhsanSpacing.sm) {
            Button {
                Haptics.impact(.light)
                onChange(max(range.lowerBound, value - step))
            } label: {
                StepMark(isPlus: false)
                    .stroke(
                        IhsanPageChrome.tokens(at: NowProvider.active.now()).metal,
                        style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
                    )
                    .frame(width: 10, height: 10)
                    .frame(width: 28, height: 28)
                    .background(Circle().strokeBorder(IhsanPageChrome.tokens(at: NowProvider.active.now()).metal.opacity(0.45), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)

            Text(displayed)
                .font(.system(.body, design: .monospaced).monospacedDigit())
                .foregroundStyle(IhsanPageChrome.tokens(at: NowProvider.active.now()).ink)
                .frame(minWidth: 36)
                .contentTransition(.numericText())

            Button {
                Haptics.impact(.light)
                onChange(min(range.upperBound, value + step))
            } label: {
                StepMark(isPlus: true)
                    .stroke(
                        IhsanPageChrome.tokens(at: NowProvider.active.now()).metal,
                        style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
                    )
                    .frame(width: 10, height: 10)
                    .frame(width: 28, height: 28)
                    .background(Circle().strokeBorder(IhsanPageChrome.tokens(at: NowProvider.active.now()).metal.opacity(0.45), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
        }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityValue(valueDescription ?? "\(value)")
    .accessibilityAdjustableAction { direction in
        switch direction {
        case .increment:
            onChange(min(range.upperBound, value + step))
        case .decrement:
            onChange(max(range.lowerBound, value - step))
        @unknown default:
            break
        }
    }
}

/// Voluntary fasting rhythms — gentle intentions, off by default.
/// Enabling one only lets the Today header's significant-day line
/// double as a quiet offer; nothing notifies, nothing counts.
private struct FastingSection: View {
    let settings: UserSettings

    var body: some View {
        SettingsSectionCard("Fasting") {
            SettingsRow(
                title: "Monday and Thursday",
                subtitle: "Off by default",
                glyph: .book
            ) {
                Toggle("", isOn: Binding(
                    get: { settings.fastingMonThuOfferEnabled },
                    set: {
                        settings.fastingMonThuOfferEnabled = $0
                        settings.modifiedAt = .now
                    }
                ))
                .labelsHidden()
                .tint(IhsanPageChrome.tokens(at: NowProvider.active.now()).leafGold)
                .accessibilityLabel("Monday and Thursday fasting offer")
            }

            SettingsRow(
                title: "White days (13–15)",
                subtitle: "Off by default",
                glyph: .nightMoon
            ) {
                Toggle("", isOn: Binding(
                    get: { settings.fastingWhiteDaysOfferEnabled },
                    set: {
                        settings.fastingWhiteDaysOfferEnabled = $0
                        settings.modifiedAt = .now
                    }
                ))
                .labelsHidden()
                .tint(IhsanPageChrome.tokens(at: NowProvider.active.now()).leafGold)
                .accessibilityLabel("White days fasting offer")
            }

            SettingsDescriptionText("When a rhythm is on, the day's quiet line on Today doubles as the offer — one tap records an intention. An intention that passes simply expires. Never a notification.")
        }
    }
}

private struct DisplaySection: View {
    let settings: UserSettings
    @Binding var path: [SettingsRoute]

    var body: some View {
        SettingsSectionCard("Display") {
            SettingsRow(
                title: "Theme",
                subtitle: settings.theme.settingsDisplayName,
                glyph: .nightMoon,
                action: {
                    Haptics.impact(.light)
                    path.append(.theme)
                }
            )

            hijriAdjustmentControl
                .padding(.vertical, IhsanSpacing.xs)

            SettingsDescriptionText("Moonsighting varies by community; shift the Hijri date up to two days either way.")
        }
    }

    /// The Hijri adjustment: ±2 days, signed display, published to
    /// every Hijri formatter the moment it changes.
    private var hijriAdjustmentControl: some View {
        let value = settings.hijriCalendarOffsetDays
        return VStack(alignment: .leading, spacing: 4) {
            Text("HIJRI ADJUSTMENT")
                .font(IhsanFont.inscription)
                .tracking(1.2)
                .foregroundStyle(IhsanPageChrome.tokens(at: NowProvider.active.now()).inkSecondary.opacity(0.7))
            HStack(spacing: IhsanSpacing.sm) {
                stepButton(isPlus: false) {
                    setOffset(max(HijriConverter.offsetRange.lowerBound, value - 1))
                }
                Text(value > 0 ? "+\(value)" : "\(value)")
                    .font(.system(.body, design: .monospaced).monospacedDigit())
                    .foregroundStyle(IhsanPageChrome.tokens(at: NowProvider.active.now()).ink)
                    .frame(minWidth: 34)
                    .contentTransition(.numericText())
                Text(value == 0 ? "DAYS · UMM AL-QURA" : "DAY\(abs(value) == 1 ? "" : "S")")
                    .font(IhsanFont.inscription)
                    .tracking(1.2)
                    .foregroundStyle(IhsanPageChrome.tokens(at: NowProvider.active.now()).inkSecondary.opacity(0.7))
                stepButton(isPlus: true) {
                    setOffset(min(HijriConverter.offsetRange.upperBound, value + 1))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hijri adjustment in days")
        .accessibilityValue("\(value)")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment:
                setOffset(min(HijriConverter.offsetRange.upperBound, value + 1))
            case .decrement:
                setOffset(max(HijriConverter.offsetRange.lowerBound, value - 1))
            @unknown default:
                break
            }
        }
    }

    private func setOffset(_ newValue: Int) {
        Haptics.impact(.light)
        settings.hijriCalendarOffsetDays = newValue
        settings.modifiedAt = .now
        HijriDisplay.publish(offsetDays: newValue)
    }

    private func stepButton(isPlus: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            StepMark(isPlus: isPlus)
                .stroke(
                    IhsanPageChrome.tokens(at: NowProvider.active.now()).metal,
                    style: StrokeStyle(lineWidth: 1.4, lineCap: .round)
                )
                .frame(width: 10, height: 10)
                .frame(width: 28, height: 28)
                .background(Circle().strokeBorder(IhsanPageChrome.tokens(at: NowProvider.active.now()).metal.opacity(0.45), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityHidden(true)
    }
}

private struct ReflectionSyncSection: View {
    let settings: UserSettings

    var body: some View {
        SettingsSectionCard("Reflection Sync") {
            SettingsRow(
                title: "Sync voice memos via iCloud",
                subtitle: "Off by default",
                glyph: .sync
            ) {
                Toggle("", isOn: Binding(
                    get: { settings.autoSyncAudioMemos },
                    set: {
                        settings.autoSyncAudioMemos = $0
                        settings.modifiedAt = .now
                    }
                ))
                .labelsHidden()
                .tint(IhsanPageChrome.tokens(at: NowProvider.active.now()).leafGold)
                .accessibilityLabel("Sync voice memos via iCloud")
            }

            SettingsDescriptionText("Voice recordings stay on this device by default. Enable to sync audio across your Apple devices via iCloud private database.")
        }
    }
}

/// This section is intentionally absent when Apple Intelligence is not
/// available. There is no disabled control or device-upgrade prompt.
private struct OnDeviceInsightsSection: View {
    let settings: UserSettings

    var body: some View {
        SettingsSectionCard("On-device Insights") {
            SettingsRow(
                title: "Prayer pattern insights",
                subtitle: "Weekly and monthly",
                glyph: .privacy
            ) {
                Toggle("", isOn: Binding(
                    get: { settings.aiInsightsEnabled },
                    set: {
                        settings.aiInsightsEnabled = $0
                        settings.modifiedAt = .now
                    }
                ))
                .labelsHidden()
                .tint(IhsanPageChrome.tokens(at: NowProvider.active.now()).leafGold)
                .accessibilityLabel("On-device prayer pattern insights")
            }

            SettingsDescriptionText("Apple Intelligence summarizes the numeric pattern already shown in Path. Processing stays on this device; Ihsan never sends prayer data to a server.")
        }
    }
}

private struct PrivacySection: View {
    let onExport: () -> Void
    let onDelete: () -> Void

    var body: some View {
        SettingsSectionCard("Privacy") {
            SettingsDescriptionText("Ihsan stores your prayer log on this device and syncs only across your own Apple devices via iCloud private database, end-to-end encrypted by Apple. No analytics, no third-party services, no accounts. Your location is used to calculate prayer times and is never stored — only your city name is saved for display. Voice recordings stay on this device unless you explicitly enable audio sync above.")

            SettingsRow(
                title: "Export my data",
                glyph: .share,
                action: onExport
            )
            .accessibilityHint("Creates a JSON export and opens the share sheet.")

            SettingsRow(
                title: "Delete all data",
                glyph: .remove,
                action: onDelete
            )
            .accessibilityHint("Opens a confirmation before deleting local Ihsan data.")
        }
    }
}

private struct AboutSection: View {
    let openURL: OpenURLAction

    var body: some View {
        SettingsSectionCard("About") {
            SettingsRow(
                title: "Version",
                subtitle: "\(Bundle.main.appVersion) (\(Bundle.main.buildNumber))",
                glyph: .info
            ) {
                EmptyView()
            }
            SettingsRow(title: "Photography credits", subtitle: "Sunrise and Maghrib wallpaper sources pending", glyph: .info) { EmptyView() }
            SettingsRow(title: "Audio credits", subtitle: "Adhan recording credits pending", glyph: .voiceWaves) { EmptyView() }
            SettingsRow(
                title: "Fiqh content credits",
                subtitle: "ihsan-fiqh-config public repo",
                glyph: .book,
                action: { openURL(URL(string: "https://github.com/sameerstudios/ihsan-fiqh-config")!) }
            )
            SettingsRow(title: "Made as sadaqah jariyah by Sameer Studios LLC", glyph: .heart) { EmptyView() }
            SettingsRow(
                title: "Privacy policy",
                subtitle: "Hosted policy URL pending before App Store submission",
                glyph: .privacy,
                action: { openURL(URL(string: "https://sameerstudios.github.io/ihsan/privacy")!) }
            )
        }
    }
}

// MARK: - Pickers

/// Calculation method, and everything underneath it.
///
/// Each preset carries its own angles on the row, so a person can check
/// the app against the timetable on their masjid wall instead of taking
/// an acronym on faith. Advanced replaces those angles; the moment it
/// does, the method stops calling itself by a standard name anywhere in
/// the app.
private struct CalculationMethodPicker: View {
    let settings: UserSettings

    var body: some View {
        PickerScaffold(title: "Calculation Method") {
            SettingsSectionCard("Automatic") {
                SettingsDescriptionText(autoDetectDescription)

                if let common = commonMethod {
                    SettingsRow(
                        title: "Match my region",
                        subtitle: common.shortName,
                        glyph: .location,
                        action: autoDetect
                    )
                }
            }

            SettingsSectionCard("Methods") {
                SettingsDescriptionText("Every method sets how far below the horizon the sun must be for Fajr and Isha. Those two angles are on each row.")

                ForEach(CalculationMethodChoice.selectable, id: \.self) { method in
                    MethodRow(
                        method: method,
                        isSelected: settings.calculationMethod == method
                            && !settings.calculationTuning.overridesAngles,
                        action: { select(method) }
                    )
                }
            }

            CalculationAdvancedSection(settings: settings)
            CalculationOffsetsSection(settings: settings)
        }
    }

    private var commonMethod: CalculationMethodChoice? {
        settings.lastResolvedCountryCode.map { CalculationMethodChoice.commonMethod(forCountryCode: $0) }
    }

    private var autoDetectDescription: String {
        guard let countryCode = settings.lastResolvedCountryCode,
              let method = commonMethod
        else {
            return "Refresh your location to see the method timetables use where you are."
        }
        return "Timetables in \(countryCode.uppercased()) commonly use \(method.titleWithAngles)."
    }

    private func autoDetect() {
        guard let countryCode = settings.lastResolvedCountryCode else { return }
        Haptics.impact(.light)
        select(CalculationMethodChoice.commonMethod(forCountryCode: countryCode))
    }

    /// Choosing a published method clears any custom angles — otherwise
    /// the row would show as selected while the app quietly computed
    /// something else. Manual offsets survive: they correct a local
    /// timetable, and that correction outlives the method choice.
    private func select(_ method: CalculationMethodChoice) {
        settings.calculationMethodRaw = method.rawValue
        settings.calculationTuning = settings.calculationTuning.resettingAngles()
        settings.modifiedAt = .now
    }
}

/// One method, in two lines: the name a person says and the angles
/// they can check, on the first; who publishes it, quietly, on the
/// second. The angles never shrink and never truncate — a figure that
/// cannot be read in full is worse than no figure at all.
private struct MethodRow: View {
    let method: CalculationMethodChoice
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        let tokens = IhsanPageChrome.tokens(at: NowProvider.active.now())
        let angles = method.angles

        VStack(spacing: 0) {
            Divider()
                .frame(height: 0.5)
                .overlay(tokens.panelStroke.opacity(0.55))

            Button {
                Haptics.impact(.light)
                action()
            } label: {
                // Past the large accessibility sizes the name and the
                // angles cannot share a line without one of them
                // shrinking, so they stack instead.
                let stacked = typeSize >= .accessibility2

                HStack(alignment: .firstTextBaseline, spacing: IhsanSpacing.md) {
                    VStack(alignment: .leading, spacing: 2) {
                        if stacked {
                            nameText(tokens)
                            if let angles { angleText(angles, tokens) }
                        } else {
                            HStack(alignment: .firstTextBaseline, spacing: IhsanSpacing.sm) {
                                nameText(tokens)
                                Spacer(minLength: IhsanSpacing.xs)
                                if let angles { angleText(angles, tokens) }
                            }
                        }

                        Text(method.provenance)
                            .font(.footnote)
                            .foregroundStyle(tokens.inkSecondary.opacity(0.85))
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)

                        if let caveat = method.caveat {
                            Text(caveat)
                                .font(.caption)
                                .foregroundStyle(tokens.inkSecondary.opacity(0.7))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    SettingsSelectionRing(isSelected: isSelected)
                }
                .padding(.horizontal, IhsanSpacing.md)
                .padding(.vertical, IhsanSpacing.sm + 2)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel("\(method.shortName), \(method.provenance)")
        .accessibilityValue(
            [method.angles?.spokenDescription, isSelected ? "Selected" : nil]
                .compactMap { $0 }
                .joined(separator: ". ")
        )
        .accessibilityHint(isSelected ? "" : "Double tap to select")
    }

    private func nameText(_ tokens: SkyPaletteTokens) -> some View {
        Text(method.shortName)
            .font(.system(size: 17, weight: .regular, design: .serif))
            .foregroundStyle(tokens.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Tabular, gilded, and never allowed to shrink or clip.
    private func angleText(_ angles: CalculationMethodAngles, _ tokens: SkyPaletteTokens) -> some View {
        Text(angles.inlineDescription)
            // Ink, not gold: gold on the morning parchment measures
            // 2.5:1, and these figures exist to be read against a
            // printed timetable. The tabular face already sets them
            // apart from the serif name beside them.
            .font(.system(.subheadline, design: .rounded).monospacedDigit())
            .foregroundStyle(tokens.ink)
            .fixedSize(horizontal: true, vertical: false)
            .layoutPriority(1)
    }
}

/// Custom angles. Present but not prominent: someone who needs it knows
/// what an angle is, and someone who does not should never have to
/// decide about one.
private struct CalculationAdvancedSection: View {
    let settings: UserSettings

    var body: some View {
        let tuning = settings.calculationTuning
        let base = settings.calculationMethod
        let baseAngles = base.angles

        SettingsSectionCard("Advanced") {
            SettingsDescriptionText("Set your own angles when a local timetable uses figures no listed method matches. Everything else — madhab, high-latitude rule, offsets — stays as you set it.")

            if tuning.overridesAngles {
                CustomBanner(
                    description: CalculationDescription.resolve(method: base, tuning: tuning)
                )
            }

            angleControl(
                label: "Fajr angle",
                value: tuning.fajrAngle ?? baseAngles?.fajrAngle ?? 15,
                isOverridden: tuning.fajrAngle != nil,
                accessibilityLabel: "Custom Fajr angle, degrees"
            ) { newValue in
                var updated = settings.calculationTuning
                updated.fajrAngle = newValue
                commit(updated)
            }

            HairlineDivider()

            Text("ISHA")
                .font(IhsanFont.inscription)
                .tracking(1.2)
                .foregroundStyle(IhsanPageChrome.tokens(at: NowProvider.active.now()).inkSecondary.opacity(0.7))
                .settingsControlInset()
                .padding(.top, IhsanSpacing.xs)

            IshaModeRow(
                title: "By angle",
                isSelected: isIshaAngleMode,
                action: {
                    var updated = settings.calculationTuning
                    updated.ishaRule = .angle(currentIshaAngle)
                    commit(updated)
                }
            )

            if isIshaAngleMode {
                angleControl(
                    label: "Isha angle",
                    value: currentIshaAngle,
                    isOverridden: tuning.ishaRule.storedAngle != nil,
                    accessibilityLabel: "Custom Isha angle, degrees"
                ) { newValue in
                    var updated = settings.calculationTuning
                    updated.ishaRule = .angle(newValue)
                    commit(updated)
                }
            }

            IshaModeRow(
                title: "Fixed minutes after Maghrib",
                isSelected: isIshaIntervalMode,
                action: {
                    var updated = settings.calculationTuning
                    updated.ishaRule = .intervalMinutes(currentIshaInterval)
                    commit(updated)
                }
            )

            if isIshaIntervalMode {
                miniCountControl(
                    label: "Minutes after Maghrib",
                    value: currentIshaInterval,
                    step: CalculationTuning.intervalStep,
                    range: CalculationTuning.intervalRange,
                    accessibilityLabel: "Minutes after Maghrib for Isha"
                ) { newValue in
                    var updated = settings.calculationTuning
                    updated.ishaRule = .intervalMinutes(newValue)
                    commit(updated)
                }
                .settingsControlInset()
                .padding(.vertical, IhsanSpacing.xs)
            }

            if tuning.overridesAngles {
                HairlineDivider()
                SettingsRow(
                    title: "Reset to \(base.shortName)",
                    subtitle: baseAngles.map { "Back to \($0.inlineDescription)" },
                    action: {
                        Haptics.impact(.medium)
                        commit(settings.calculationTuning.resettingAngles())
                    }
                )
            }
        }
    }

    private var isIshaAngleMode: Bool {
        settings.calculationTuning.ishaRule.storedAngle != nil
    }

    private var isIshaIntervalMode: Bool {
        settings.calculationTuning.ishaRule.storedIntervalMinutes != nil
    }

    /// What the angle control shows before anyone touches it: the value
    /// the app is computing with right now, whatever its source.
    private var currentIshaAngle: Double {
        if let custom = settings.calculationTuning.ishaRule.storedAngle { return custom }
        return settings.calculationMethod.angles?.ishaAngle ?? 15
    }

    private var currentIshaInterval: Int {
        if let custom = settings.calculationTuning.ishaRule.storedIntervalMinutes { return custom }
        return settings.calculationMethod.angles?.ishaIntervalMinutes ?? 90
    }

    private func commit(_ tuning: CalculationTuning) {
        settings.calculationTuning = tuning
        settings.modifiedAt = .now
    }

    private func angleControl(
        label: String,
        value: Double,
        isOverridden: Bool,
        accessibilityLabel: String,
        onChange: @escaping (Double) -> Void
    ) -> some View {
        let tokens = IhsanPageChrome.tokens(at: NowProvider.active.now())
        let step = CalculationTuning.angleStep
        let range = CalculationTuning.angleRange

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: IhsanSpacing.xs) {
                Text(label.uppercased())
                    .font(IhsanFont.inscription)
                    .tracking(1.2)
                    .foregroundStyle(tokens.inkSecondary.opacity(0.7))
                if isOverridden {
                    Text("SET BY YOU")
                        .font(IhsanFont.inscription)
                        .tracking(1.2)
                        .foregroundStyle(tokens.leafGold)
                }
            }

            HStack(spacing: IhsanSpacing.sm) {
                stepButton(isPlus: false) {
                    onChange(max(range.lowerBound, value - step))
                }

                // Fixed, not minimum: "15°" and "15.5°" must not shift
                // the marks either side of them as the value steps.
                Text(formatted(value))
                    .font(.system(.body, design: .monospaced).monospacedDigit())
                    .foregroundStyle(tokens.ink)
                    .frame(width: 64)
                    .contentTransition(.numericText())

                stepButton(isPlus: true) {
                    onChange(min(range.upperBound, value + step))
                }
                Spacer()
            }
        }
        .settingsControlInset()
        .padding(.vertical, IhsanSpacing.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(formatted(value))
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: onChange(min(range.upperBound, value + step))
            case .decrement: onChange(max(range.lowerBound, value - step))
            @unknown default: break
            }
        }
    }

    private func formatted(_ value: Double) -> String {
        value == value.rounded()
            ? "\(Int(value))°"
            : String(format: "%.1f°", value)
    }

    private func stepButton(isPlus: Bool, action: @escaping () -> Void) -> some View {
        let tokens = IhsanPageChrome.tokens(at: NowProvider.active.now())
        return Button {
            Haptics.impact(.light)
            action()
        } label: {
            StepMark(isPlus: isPlus)
                .stroke(tokens.metal, style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                .frame(width: 10, height: 10)
                .frame(width: 28, height: 28)
                .background(Circle().strokeBorder(tokens.metal.opacity(0.45), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityHidden(true)
    }
}

/// Says plainly that the app is no longer computing a standard method,
/// so nobody believes they are on one.
private struct CustomBanner: View {
    let description: CalculationDescription

    var body: some View {
        let tokens = IhsanPageChrome.tokens(at: NowProvider.active.now())
        VStack(alignment: .leading, spacing: 2) {
            Text(description.title)
                .font(IhsanFont.bodyEnglishBold)
                .foregroundStyle(tokens.ink)
            Text("These are your angles, not a published method's.")
                .font(.footnote)
                .foregroundStyle(tokens.inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .settingsControlInset()
        .padding(.vertical, IhsanSpacing.xs)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(description.spokenTitle)
    }
}

private struct IshaModeRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        SettingsRow(title: title, action: {
            Haptics.impact(.light)
            action()
        }) {
            SettingsSelectionRing(isSelected: isSelected)
        }
        .accessibilityHint(isSelected ? "Selected" : "Double tap to select")
    }
}

/// Whole-minute corrections, for matching a printed timetable exactly.
private struct CalculationOffsetsSection: View {
    let settings: UserSettings

    var body: some View {
        SettingsSectionCard("Manual Offsets") {
            SettingsDescriptionText("Shift any prayer by up to ten minutes to match the timetable you pray by. Offsets stay with you when you change method.")

            ForEach(Prayer.allCases, id: \.self) { prayer in
                miniCountControl(
                    label: prayer.displayNameEnglish,
                    value: settings.calculationTuning.offsets[prayer],
                    step: 1,
                    range: PrayerOffsets.allowedRange,
                    accessibilityLabel: "\(prayer.displayNameEnglish) offset in minutes",
                    valueDescription: Self.signed(settings.calculationTuning.offsets[prayer])
                ) { newValue in
                    var updated = settings.calculationTuning
                    updated.offsets[prayer] = newValue
                    settings.calculationTuning = updated
                    settings.modifiedAt = .now
                }
                .settingsControlInset()
                .padding(.vertical, IhsanSpacing.xxs)
            }

            if !settings.calculationTuning.offsets.isEmpty {
                HairlineDivider()
                SettingsRow(
                    title: "Clear all offsets",
                    action: {
                        Haptics.impact(.medium)
                        var updated = settings.calculationTuning
                        updated.offsets = .none
                        settings.calculationTuning = updated
                        settings.modifiedAt = .now
                    }
                )
            }
        }
    }

    static func signed(_ minutes: Int) -> String {
        if minutes == 0 { return "0 minutes" }
        return minutes > 0 ? "plus \(minutes) minutes" : "minus \(abs(minutes)) minutes"
    }
}

private struct MadhabPicker: View {
    let settings: UserSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PickerScaffold(title: "Asr Method") {
            SettingsSectionCard("Madhab") {
                ForEach(MadhabChoice.allCases, id: \.self) { madhab in
                    optionRow(
                        title: madhab.settingsDisplayName,
                        subtitle: madhab.settingsDescription,
                        isSelected: settings.madhab == madhab
                    ) {
                        settings.madhabRaw = madhab.rawValue
                        settings.modifiedAt = .now
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct HighLatitudeRulePicker: View {
    let settings: UserSettings
    @Environment(\.dismiss) private var dismiss

    private let rules: [HighLatitudeRule] = [.middleOfNight, .oneSeventh, .angleBased]

    var body: some View {
        PickerScaffold(title: "High Latitude Rule") {
            SettingsSectionCard("Rule") {
                SettingsDescriptionText("This matters for users above approximately 48 degrees latitude.")

                ForEach(rules, id: \.self) { rule in
                    optionRow(
                        title: rule.settingsDisplayName,
                        subtitle: rule.settingsDescription,
                        isSelected: settings.highLatitudeRule == rule
                    ) {
                        settings.highLatitudeRuleRaw = rule.rawValue
                        settings.modifiedAt = .now
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Set → Adhan.
///
/// Each prayer chooses its own sound, because the prayer that has to
/// wake someone is not the prayer that arrives mid-afternoon. Below the
/// prayers: the full recording, which only the app can play, and the
/// two decisions that belong to the room rather than to a prayer —
/// whether the adhan may sound on silent, and whether it may break
/// through Focus.
private struct AdhanSoundPicker: View {
    let settings: UserSettings

    @State private var expandedPrayer: Prayer?
    @State private var player = AdhanPlayer.shared

    private let resolver = AdhanSoundFileResolver.mainBundle

    var body: some View {
        PickerScaffold(title: "Adhan") {
            SettingsSectionCard("Each prayer") {
                SettingsDescriptionText("Choose what each prayer sounds like. Silent still shows the notification — it just doesn't make a sound.")

                ForEach(Prayer.allCases, id: \.self) { prayer in
                    prayerRow(prayer)

                    if expandedPrayer == prayer {
                        ForEach(AdhanSoundCatalog.options(for: prayer), id: \.self) { option in
                            optionRow(
                                title: option.displayName,
                                subtitle: subtitle(for: option),
                                isSelected: settings.sound(for: prayer) == option
                            ) {
                                settings.setSound(option, for: prayer)
                                settings.modifiedAt = .now
                                rebuildSchedule()
                            }
                        }
                    }
                }
            }

            SettingsSectionCard("The full call") {
                SettingsDescriptionText(fullAdhanDescription)

                SettingsRow(
                    title: player.isPlaying ? "Stop" : "Play",
                    glyph: .adhan,
                    action: {
                        Haptics.impact(.light)
                        if player.isPlaying {
                            player.stop()
                        } else {
                            player.play(overridesSilentSwitch: settings.adhanPlaysInSilentMode)
                        }
                    }
                )

                if let failure = player.lastFailure {
                    SettingsDescriptionText(failure)
                }

                SettingsRow(title: "Play adhan even in silent mode", glyph: .adhan) {
                    Toggle("", isOn: Binding(
                        get: { settings.adhanPlaysInSilentMode },
                        set: {
                            settings.adhanPlaysInSilentMode = $0
                            settings.modifiedAt = .now
                        }
                    ))
                    .labelsHidden()
                    .tint(IhsanPageChrome.tokens(at: NowProvider.active.now()).leafGold)
                    .accessibilityLabel("Play adhan even in silent mode")
                }

                SettingsDescriptionText("Off by default. When the ringer switch is off, the adhan stays quiet like everything else.")
            }

            SettingsSectionCard("Focus") {
                SettingsDescriptionText("A time-sensitive notification arrives even while Focus is on. Off unless you ask for it, one prayer at a time.")

                ForEach(Prayer.allCases, id: \.self) { prayer in
                    SettingsRow(title: prayer.displayNameEnglish) {
                        Toggle("", isOn: Binding(
                            get: { settings.isTimeSensitive(prayer) },
                            set: {
                                settings.setTimeSensitive($0, for: prayer)
                                settings.modifiedAt = .now
                                rebuildSchedule()
                            }
                        ))
                        .labelsHidden()
                        .tint(IhsanPageChrome.tokens(at: NowProvider.active.now()).leafGold)
                        .accessibilityLabel("\(prayer.displayNameEnglish) breaks through Focus")
                    }
                }
            }
        }
        .onDisappear { player.stop() }
    }

    private func prayerRow(_ prayer: Prayer) -> some View {
        SettingsRow(
            title: prayer.displayNameEnglish,
            subtitle: settings.sound(for: prayer).displayName,
            glyph: .adhan,
            action: {
                Haptics.impact(.light)
                withAnimation(.snappy(duration: 0.22)) {
                    expandedPrayer = expandedPrayer == prayer ? nil : prayer
                }
            }
        )
        .accessibilityHint(expandedPrayer == prayer ? "Collapses the choices" : "Shows the choices")
    }

    /// Says plainly when an option is standing in for a recording that
    /// has not landed, rather than letting two rows sound identical
    /// with no explanation.
    private func subtitle(for option: AdhanSoundCatalog) -> String {
        if option.awaitsRecording(using: resolver) {
            return "Recording not in this build yet — plays the chime"
        }
        return option.settingsDescription
    }

    private var fullAdhanDescription: String {
        let base = "A notification tone can only be thirty seconds long, so the whole adhan plays here in the app — and from the notification, if you tap Play the adhan."
        guard AdhanPlayer.isAvailable else {
            return base + " The recording is not in this build yet."
        }
        return base
    }

    private func rebuildSchedule() {
        Task { try? await NotificationScheduler.shared.rebuildSchedule() }
    }
}

private extension AdhanSoundCatalog {
    var displayName: String {
        switch self {
        case .silent: "Silent"
        case .chime: "Chime"
        case .chimeDawn: "Chime, rising"
        case .takbirat: "Takbīrāt"
        }
    }

    var settingsDescription: String {
        switch self {
        case .silent: "The notification arrives without a sound."
        case .chime: "One soft struck bowl, warm and low."
        case .chimeDawn: "The same bowl, struck four times, growing. For waking."
        case .takbirat: "The muezzin's opening lines."
        }
    }
}

private struct JamPolicyPicker: View {
    let travel: TravelInterval
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PickerScaffold(title: "Jam Policy") {
            SettingsSectionCard("Travel") {
                ForEach(JamPolicy.allCases, id: \.self) { policy in
                    optionRow(
                        title: policy.settingsDisplayName,
                        subtitle: policy.settingsDescription,
                        isSelected: travel.jamPolicy == policy
                    ) {
                        travel.jamPolicyRaw = policy.rawValue
                        travel.modifiedAt = .now
                        dismiss()
                    }
                }
            }
        }
    }
}

private struct ThemePicker: View {
    let settings: UserSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PickerScaffold(title: "Theme") {
            SettingsSectionCard("Display") {
                optionRow(
                    title: "Always Dark",
                    subtitle: "Default for v1",
                    isSelected: settings.theme == .dark
                ) {
                    settings.themeRaw = ThemePreference.dark.rawValue
                    settings.modifiedAt = .now
                    dismiss()
                }

                optionRow(
                    title: "System",
                    subtitle: "Light mode experimentation is planned for v1.1",
                    isSelected: settings.theme == .auto
                ) {
                    // v1 intentionally renders dark even when System is selected;
                    // light mode support is a v1.1 rendering project.
                    settings.themeRaw = ThemePreference.auto.rawValue
                    settings.modifiedAt = .now
                    dismiss()
                }
            }
        }
    }
}

private struct PickerScaffold<Content: View>: View {
    /// The floating tab bar's height plus the home indicator, with
    /// room to breathe. A subscreen inside a tab has to clear it
    /// itself: the bar floats over the scroll view rather than
    /// insetting it.
    static var tabBarClearance: CGFloat { 96 }

    let title: String
    let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ZStack {
            Color.clear.ihsanManuscriptPage()

            ScrollView {
                VStack(alignment: .leading, spacing: IhsanSpacing.lg) {
                    content
                    // Clearance for the floating tab bar. Without it a
                    // method row sits half-behind the bar at the foot
                    // of the list, which reads as a rendering fault
                    // rather than as a list continuing. The soft edge
                    // effect handles the top.
                    Color.clear.frame(height: Self.tabBarClearance)
                }
                .padding(.horizontal, IhsanSpacing.md)
                .padding(.top, IhsanSpacing.md)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }
}

private func optionRow(
    title: String,
    subtitle: String,
    isSelected: Bool,
    action: @escaping () -> Void
) -> some View {
    SettingsRow(title: title, subtitle: subtitle, action: {
        Haptics.impact(.light)
        action()
    }) {
        SettingsSelectionRing(isSelected: isSelected)
    }
    .accessibilityHint(isSelected ? "Selected" : "Double tap to select")
}

#if DEBUG
private struct CoordinatesDebugSheet: View {
    let place: LocatedPlace?

    var body: some View {
        ZStack {
            Color.clear.ihsanManuscriptPage()
            VStack(alignment: .leading, spacing: IhsanSpacing.md) {
                SectionHeader("Coordinates")
                    .padding(.horizontal, IhsanSpacing.md)
                    .padding(.top, IhsanSpacing.sm)
                SettingsDescriptionText(coordinatesText)
                SettingsDescriptionText("Coordinates are shown for debugging only and are not stored.")
                    .padding(.bottom, IhsanSpacing.sm)
            }
            .ihsanIlluminatedPanel(intensity: .regular)
            .padding(IhsanSpacing.md)
        }
    }

    private var coordinatesText: String {
        guard let place else {
            return "No resolved location is cached yet."
        }
        return "Latitude \(place.coordinates.latitude), longitude \(place.coordinates.longitude). Resolved at \(place.timestamp.formatted(date: .abbreviated, time: .standard))."
    }
}
#endif

private struct ActivityView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct ExportItem: Identifiable {
    let id = UUID()
    let url: URL
}

// MARK: - Export payload

private struct SettingsExportPayload: Codable {
    let exportedAt: Date
    let prayerLogs: [ExportPrayerLog]
    let reflections: [ExportReflection]
}

private struct ExportPrayerLog: Codable {
    let id: UUID
    let prayer: String
    let prayerDate: Date
    let loggedTimeZoneIdentifier: String
    let scheduledTime: Date
    let prayedAt: Date?
    let loggedAt: Date
    let status: String
    let lateBySeconds: Int?
    let withJamaah: Bool
    let jamaahLocation: String?
    let prayerVariant: String
    let combinedWithPrayerLogID: UUID?
    let combinationKind: String?
    let qadaForPrayerLogID: UUID?
    let sourceSurface: String
    let note: String?
    let createdAt: Date
    let modifiedAt: Date

    init(_ log: PrayerLog) {
        id = log.id
        prayer = log.prayerRaw
        prayerDate = log.prayerDate
        loggedTimeZoneIdentifier = log.loggedTimeZoneIdentifier
        scheduledTime = log.scheduledTime
        prayedAt = log.prayedAt
        loggedAt = log.loggedAt
        status = log.statusRaw
        lateBySeconds = log.lateBySeconds
        withJamaah = log.withJamaah
        jamaahLocation = log.jamaahLocationRaw
        prayerVariant = log.prayerVariantRaw
        combinedWithPrayerLogID = log.combinedWithPrayerLogID
        combinationKind = log.combinationKindRaw
        qadaForPrayerLogID = log.qadaForPrayerLogID
        sourceSurface = log.sourceSurface
        note = log.note
        createdAt = log.createdAt
        modifiedAt = log.modifiedAt
    }
}

private struct ExportReflection: Codable {
    let id: UUID
    let kind: String
    let forDate: Date
    let loggedTimeZoneIdentifier: String
    let promptText: String?
    let promptCitation: String?
    let typedText: String?
    let transcript: String?
    let voiceMemoID: UUID?
    let aiSummaryTitle: String?
    let aiTagsJSON: String?
    let aiGeneratedAt: Date?
    let aiModelVersion: String?
    let linkedPrayerLogID: UUID?
    let wordCount: Int?
    let createdAt: Date
    let modifiedAt: Date

    init(_ reflection: Reflection) {
        id = reflection.id
        kind = reflection.kindRaw
        forDate = reflection.forDate
        loggedTimeZoneIdentifier = reflection.loggedTimeZoneIdentifier
        promptText = reflection.promptText
        promptCitation = reflection.promptCitation
        typedText = reflection.typedText
        transcript = reflection.transcript
        voiceMemoID = reflection.voiceMemoID
        aiSummaryTitle = reflection.aiSummaryTitle
        aiTagsJSON = reflection.aiTagsJSON
        aiGeneratedAt = reflection.aiGeneratedAt
        aiModelVersion = reflection.aiModelVersion
        linkedPrayerLogID = reflection.linkedPrayerLogID
        wordCount = reflection.wordCount
        createdAt = reflection.createdAt
        modifiedAt = reflection.modifiedAt
    }
}

// MARK: - Display helpers

private extension MadhabChoice {
    var settingsDisplayName: String {
        switch self {
        case .standard: "Standard"
        case .hanafi: "Hanafi"
        }
    }

    var settingsDescription: String {
        switch self {
        case .standard: "Asr begins when an object's shadow equals its length. Used by Shafi'i, Maliki, Hanbali."
        case .hanafi: "Asr begins when shadow equals twice the object's length."
        }
    }
}

private extension HighLatitudeRule {
    var settingsDisplayName: String {
        switch self {
        case .middleOfNight: "Middle of Night"
        case .oneSeventh: "One Seventh"
        case .angleBased: "Angle Based"
        case .twilightAngle: "Twilight Angle"
        }
    }

    var settingsDescription: String {
        switch self {
        case .middleOfNight: "Splits the night in half for affected prayers."
        case .oneSeventh: "Uses one seventh of the night."
        case .angleBased: "Uses the prayer angle as a proportion of the night."
        case .twilightAngle: "Legacy twilight-angle handling."
        }
    }
}

private extension JamPolicy {
    var settingsDisplayName: String {
        switch self {
        case .none: "None"
        case .taqdim: "Taqdim"
        case .takhir: "Takhir"
        }
    }

    var settingsDescription: String {
        switch self {
        case .none: "Do not combine prayers automatically."
        case .taqdim: "Combine into the earlier prayer window."
        case .takhir: "Combine into the later prayer window."
        }
    }
}

private extension ThemePreference {
    var settingsDisplayName: String {
        switch self {
        case .auto: "System"
        case .dark: "Always Dark"
        case .light: "System"
        }
    }
}

private extension Bundle {
    var appVersion: String {
        object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
    }

    var buildNumber: String {
        object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
    }
}


/// The stepper's engraved marks: a drawn line and cross, never a
/// symbol.
private struct StepMark: Shape {
    let isPlus: Bool
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        if isPlus {
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        }
        return p
    }
}
