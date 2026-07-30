import SwiftUI
import SwiftData
import UIKit
import UserNotifications
import IhsanCore
import IhsanDesignSystem
import IhsanFiqhConfig
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
                        DisplaySection(settings: settings, path: $path)
                        ReflectionSyncSection(settings: settings)
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
                            .tint(IhsanColor.brass)
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
                .foregroundStyle(IhsanPageChrome.tokens(at: .now).ink)
                .accessibilityAddTraits(.isHeader)
            Text("SETTINGS")
                .font(IhsanFont.inscription)
                .tracking(2.0)
                .foregroundStyle(IhsanColor.brass)
            OrnamentalDivider()
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
            AdhanSoundPicker()
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
                icon: "location.fill",
                action: onCityTap
            ) { EmptyView() }
            #else
            SettingsRow(
                title: currentCityTitle,
                subtitle: currentCitySubtitle,
                icon: "location.fill"
            ) { EmptyView() }
            #endif

            SettingsRow(title: "Automatic location updates", icon: "location.circle") {
                Toggle("", isOn: Binding(
                    get: { settings.automaticLocationUpdatesEnabled },
                    set: { onAutomaticLocationChanged($0, settings) }
                ))
                .labelsHidden()
                .tint(IhsanColor.brass)
                .accessibilityLabel("Automatic location updates")
            }

            SettingsRow(
                title: "Refresh location now",
                subtitle: refreshMessage,
                icon: "location.magnifyingglass",
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
        SettingsSectionCard("Calculation Method") {
            SettingsRow(
                title: "Current method",
                subtitle: settings.calculationMethod.settingsDisplayName,
                icon: "function",
                action: {
                    Haptics.impact(.light)
                    path.append(.calculationMethod)
                }
            )
        }
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
                icon: "book.closed.fill",
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
                icon: "sun.horizon",
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
            SettingsRow(title: "Adhan notifications", icon: "bell.fill") {
                Toggle("", isOn: Binding(
                    get: { settings.notificationsEnabled },
                    set: { onToggleNotifications($0, settings) }
                ))
                .labelsHidden()
                .tint(IhsanColor.brass)
                .accessibilityLabel("Adhan notifications")
            }

            if settings.notificationsEnabled {
                SettingsRow(
                    title: "Sound",
                    subtitle: "Default",
                    icon: "speaker.wave.2.fill",
                    action: {
                        Haptics.impact(.light)
                        path.append(.adhanSound)
                    }
                )

                ForEach(Prayer.allCases, id: \.self) { prayer in
                    SettingsRow(title: prayer.displayNameEnglish, icon: "clock.badge.checkmark") {
                        Toggle("", isOn: prayerNotificationBinding(for: prayer))
                            .labelsHidden()
                            .tint(IhsanColor.brass)
                            .accessibilityLabel("\(prayer.displayNameEnglish) notification")
                    }
                }
            }
        }
    }

    private func prayerNotificationBinding(for prayer: Prayer) -> Binding<Bool> {
        Binding(
            get: {
                settings.prayerNotificationConfigs.first(where: { $0.prayer == prayer })?.isEnabled ?? true
            },
            set: { isEnabled in
                var configs = settings.prayerNotificationConfigs
                if let index = configs.firstIndex(where: { $0.prayer == prayer }) {
                    configs[index].isEnabled = isEnabled
                } else {
                    configs.append(PrayerNotificationConfig(prayer: prayer, isEnabled: isEnabled))
                }
                settings.prayerNotificationConfigs = configs
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
                icon: "pause.circle.fill"
            ) {
                Toggle("", isOn: Binding(
                    get: { activePause != nil },
                    set: onToggle
                ))
                .labelsHidden()
                .tint(IhsanColor.brass)
                .accessibilityLabel("Pause Mode")
            }

            if let activePause {
                SettingsRow(
                    title: "Expected end",
                    subtitle: "Nothing ends without you",
                    icon: "calendar"
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
                    .tint(IhsanColor.brass)
                    .accessibilityLabel("Expected end date")
                }

                if let expectedEnd = activePause.expectedEndDate {
                    SettingsRow(title: "Around", icon: "clock") {
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
                icon: "airplane"
            ) {
                Toggle("", isOn: Binding(
                    get: { activeTravel != nil },
                    set: onToggle
                ))
                .labelsHidden()
                .tint(IhsanColor.brass)
                .accessibilityLabel("Travel Mode")
            }

            if let activeTravel {
                SettingsRow(
                    title: "Jam policy",
                    subtitle: activeTravel.jamPolicy.settingsDisplayName,
                    icon: "arrow.triangle.merge",
                    action: {
                        Haptics.impact(.light)
                        path.append(.jamPolicy)
                    }
                )

                SettingsRow(title: "Qasr enabled", icon: "arrow.down.forward.and.arrow.up.backward") {
                    Toggle("", isOn: Binding(
                        get: { activeTravel.qasrEnabled },
                        set: {
                            activeTravel.qasrEnabled = $0
                            activeTravel.modifiedAt = .now
                        }
                    ))
                    .labelsHidden()
                    .tint(IhsanColor.brass)
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
                    icon: "arrow.uturn.backward"
                ) {
                    Toggle("", isOn: Binding(
                        get: { settings.qadaMissedFlowEnabled },
                        set: {
                            settings.qadaMissedFlowEnabled = $0
                            settings.modifiedAt = .now
                        }
                    ))
                    .labelsHidden()
                    .tint(IhsanColor.brass)
                    .accessibilityLabel("Unlogged prayers flow into makeup count")
                }

                SettingsRow(title: "Track witr", icon: "moon.haze.fill") {
                    Toggle("", isOn: Binding(
                        get: { settings.qadaTracksWitr },
                        set: {
                            settings.qadaTracksWitr = $0
                            settings.modifiedAt = .now
                        }
                    ))
                    .labelsHidden()
                    .tint(IhsanColor.brass)
                    .accessibilityLabel("Track witr makeups")
                }

                SettingsDescriptionText("Your makeup counts live on the Path screen, at your pace.")
            } else {
                SettingsRow(
                    title: "Makeup prayers",
                    subtitle: "At your pace",
                    icon: "arrow.uturn.backward",
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
            SettingsRow(title: "Sunnah & night prayer", icon: "moon.stars") {
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
                .tint(IhsanColor.brass)
                .accessibilityLabel("Sunnah and night prayer")
            }

            if settings.sunnahLayerEnabled {
                SettingsRow(title: "Rawatib", subtitle: "Around each fard", icon: "circle.grid.cross") {
                    Toggle("", isOn: Binding(
                        get: { settings.sunnahRawatibEnabled },
                        set: {
                            settings.sunnahRawatibEnabled = $0
                            settings.modifiedAt = .now
                        }
                    ))
                    .labelsHidden()
                    .tint(IhsanColor.brass)
                    .accessibilityLabel("Rawatib")
                }

                if settings.sunnahRawatibEnabled {
                    SettingsRow(
                        title: "Rawatib counts",
                        subtitle: "Yours to set",
                        icon: "plusminus",
                        action: {
                            Haptics.impact(.light)
                            path.append(.rawatibCounts)
                        }
                    )
                }

                SettingsRow(title: "Duha", subtitle: "The forenoon prayer", icon: "sun.min") {
                    Toggle("", isOn: Binding(
                        get: { settings.sunnahDuhaEnabled },
                        set: {
                            settings.sunnahDuhaEnabled = $0
                            settings.modifiedAt = .now
                        }
                    ))
                    .labelsHidden()
                    .tint(IhsanColor.brass)
                    .accessibilityLabel("Duha")
                }

                if settings.sunnahDuhaEnabled {
                    SettingsRow(
                        title: "Duha window",
                        subtitle: duhaWindowSubtitle,
                        icon: "clock",
                        action: {
                            Haptics.impact(.light)
                            path.append(.duhaWindow)
                        }
                    )
                }

                SettingsRow(title: "Night prayer", subtitle: "Qiyam and witr", icon: "moon.zzz") {
                    Toggle("", isOn: Binding(
                        get: { settings.sunnahNightEnabled },
                        set: {
                            settings.sunnahNightEnabled = $0
                            settings.modifiedAt = .now
                            onWakeSettingsChanged()
                        }
                    ))
                    .labelsHidden()
                    .tint(IhsanColor.brass)
                    .accessibilityLabel("Night prayer")
                }

                if settings.sunnahNightEnabled {
                    SettingsRow(title: "Gentle wake", subtitle: "For the last third", icon: "alarm") {
                        Toggle("", isOn: Binding(
                            get: { settings.nightWakeEnabled },
                            set: {
                                settings.nightWakeEnabled = $0
                                settings.modifiedAt = .now
                                onWakeSettingsChanged()
                            }
                        ))
                        .labelsHidden()
                        .tint(IhsanColor.brass)
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

                SettingsRow(title: "Ask for rak'ah counts", subtitle: "Off: one tap records", icon: "number") {
                    Toggle("", isOn: Binding(
                        get: { settings.sunnahRakahCountsEnabled },
                        set: {
                            settings.sunnahRakahCountsEnabled = $0
                            settings.modifiedAt = .now
                        }
                    ))
                    .labelsHidden()
                    .tint(IhsanColor.brass)
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
                .overlay(IhsanColor.brass.opacity(0.18))
            Text(prayer.displayNameEnglish)
                .font(IhsanFont.bodyEnglish)
                .foregroundStyle(IhsanPageChrome.tokens(at: .now).ink)
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
                .padding(.vertical, IhsanSpacing.xs)

                SettingsDescriptionText("Schools differ on the window's edges; both offsets are yours to set.")
            }
        }
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
    onChange: @escaping (Int) -> Void
) -> some View {
    VStack(alignment: .leading, spacing: 4) {
        Text(label.uppercased())
            .font(IhsanFont.inscription)
            .tracking(1.2)
            .foregroundStyle(IhsanPageChrome.tokens(at: .now).inkSecondary.opacity(0.7))
        HStack(spacing: IhsanSpacing.sm) {
            Button {
                Haptics.impact(.light)
                onChange(max(range.lowerBound, value - step))
            } label: {
                Image(systemName: "minus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(IhsanColor.brass)
                    .frame(width: 28, height: 28)
                    .background(Circle().strokeBorder(IhsanColor.brass.opacity(0.45), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)

            Text("\(value)")
                .font(.system(.body, design: .monospaced).monospacedDigit())
                .foregroundStyle(IhsanPageChrome.tokens(at: .now).ink)
                .frame(minWidth: 28)
                .contentTransition(.numericText())

            Button {
                Haptics.impact(.light)
                onChange(min(range.upperBound, value + step))
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(IhsanColor.brass)
                    .frame(width: 28, height: 28)
                    .background(Circle().strokeBorder(IhsanColor.brass.opacity(0.45), lineWidth: 1))
            }
            .buttonStyle(.plain)
            .accessibilityHidden(true)
        }
    }
    .accessibilityElement(children: .ignore)
    .accessibilityLabel(accessibilityLabel)
    .accessibilityValue("\(value)")
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

private struct DisplaySection: View {
    let settings: UserSettings
    @Binding var path: [SettingsRoute]

    var body: some View {
        SettingsSectionCard("Display") {
            SettingsRow(
                title: "Theme",
                subtitle: settings.theme.settingsDisplayName,
                icon: "moon.stars.fill",
                action: {
                    Haptics.impact(.light)
                    path.append(.theme)
                }
            )
        }
    }
}

private struct ReflectionSyncSection: View {
    let settings: UserSettings

    var body: some View {
        SettingsSectionCard("Reflection Sync") {
            SettingsRow(
                title: "Sync voice memos via iCloud",
                subtitle: "Off by default",
                icon: "icloud.fill"
            ) {
                Toggle("", isOn: Binding(
                    get: { settings.autoSyncAudioMemos },
                    set: {
                        settings.autoSyncAudioMemos = $0
                        settings.modifiedAt = .now
                    }
                ))
                .labelsHidden()
                .tint(IhsanColor.brass)
                .accessibilityLabel("Sync voice memos via iCloud")
            }

            SettingsDescriptionText("Voice recordings stay on this device by default. Enable to sync audio across your Apple devices via iCloud private database.")
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
                icon: "square.and.arrow.up",
                action: onExport
            )
            .accessibilityHint("Creates a JSON export and opens the share sheet.")

            SettingsRow(
                title: "Delete all data",
                icon: "trash",
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
                icon: "info.circle.fill"
            ) {
                EmptyView()
            }
            SettingsRow(title: "Photography credits", subtitle: "Sunrise and Maghrib wallpaper sources pending", icon: "camera.fill") { EmptyView() }
            SettingsRow(title: "Audio credits", subtitle: "Adhan recording credits pending", icon: "waveform") { EmptyView() }
            SettingsRow(
                title: "Fiqh content credits",
                subtitle: "ihsan-fiqh-config public repo",
                icon: "book.pages.fill",
                action: { openURL(URL(string: "https://github.com/sameerstudios/ihsan-fiqh-config")!) }
            )
            SettingsRow(title: "Made as sadaqah jariyah by Sameer Studios LLC", icon: "heart.fill") { EmptyView() }
            SettingsRow(
                title: "Privacy policy",
                subtitle: "Hosted policy URL pending before App Store submission",
                icon: "lock.shield.fill",
                action: { openURL(URL(string: "https://sameerstudios.github.io/ihsan/privacy")!) }
            )
        }
    }
}

// MARK: - Pickers

private struct CalculationMethodPicker: View {
    let settings: UserSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        PickerScaffold(title: "Calculation Method") {
            SettingsSectionCard("Automatic") {
                SettingsRow(
                    title: "Auto-detect from location",
                    subtitle: autoDetectSubtitle,
                    icon: "location.viewfinder",
                    action: autoDetect
                )
            }

            SettingsSectionCard("Methods") {
                ForEach(CalculationMethodChoice.allCases, id: \.self) { method in
                    optionRow(
                        title: method.settingsDisplayName,
                        subtitle: method.settingsDescription,
                        isSelected: settings.calculationMethod == method
                    ) {
                        settings.calculationMethodRaw = method.rawValue
                        settings.modifiedAt = .now
                        dismiss()
                    }
                }
            }
        }
    }

    private var recommendedMethod: CalculationMethodChoice? {
        settings.lastResolvedCountryCode.map(CalculationMethodChoice.recommendedMethod)
    }

    private var autoDetectSubtitle: String {
        guard let countryCode = settings.lastResolvedCountryCode else {
            return "Refresh location first"
        }
        return "\(countryCode.uppercased()) recommends \((recommendedMethod ?? .muslimWorldLeague).settingsDisplayName)"
    }

    private func autoDetect() {
        guard let countryCode = settings.lastResolvedCountryCode else { return }
        Haptics.impact(.light)
        settings.calculationMethodRaw = CalculationMethodChoice.recommendedMethod(for: countryCode).rawValue
        settings.modifiedAt = .now
        dismiss()
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

private struct AdhanSoundPicker: View {
    private let options = [
        "Default",
        "Adhan Standard",
        "Adhan Fajr-aware",
        "Tone Only"
    ]

    var body: some View {
        PickerScaffold(title: "Adhan Sound") {
            SettingsSectionCard("Sound") {
                ForEach(options, id: \.self) { option in
                    SettingsRow(title: option, subtitle: "Sound switching lands with notification scheduling", icon: "speaker.wave.2.fill") {
                        EmptyView()
                    }
                    .accessibilityHint("This option is visible but not active yet.")
                }
            }
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
                    Color.clear.frame(height: IhsanSpacing.xl)
                }
                .padding(.horizontal, IhsanSpacing.md)
                .padding(.top, IhsanSpacing.md)
            }
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
    SettingsRow(title: title, subtitle: subtitle, icon: isSelected ? "checkmark.circle.fill" : "circle", action: {
        Haptics.impact(.light)
        action()
    }) {
        EmptyView()
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

private extension UserSettings {
    var prayerNotificationConfigs: [PrayerNotificationConfig] {
        get {
            guard let data = prayerNotificationsConfigJSON.data(using: .utf8),
                  let configs = try? JSONDecoder().decode([PrayerNotificationConfig].self, from: data)
            else {
                return Prayer.allCases.map { PrayerNotificationConfig(prayer: $0) }
            }
            return configs
        }
        set {
            guard let data = try? JSONEncoder().encode(newValue),
                  let json = String(data: data, encoding: .utf8)
            else { return }
            prayerNotificationsConfigJSON = json
        }
    }
}

private extension CalculationMethodChoice {
    var settingsDisplayName: String {
        switch self {
        case .muslimWorldLeague: "MWL"
        case .isna: "ISNA"
        case .egyptian: "Egyptian"
        case .ummAlQura: "Umm al-Qura"
        case .karachi: "Karachi"
        case .dubai: "Dubai"
        case .qatar: "Qatar"
        case .kuwait: "Kuwait"
        case .singapore: "Singapore"
        case .tehran: "Tehran"
        case .jafari: "Jafari"
        case .moonsightingCommittee: "Moonsighting Committee"
        case .northAmerica: "North America"
        case .turkey: "Turkey"
        case .other: "Other"
        }
    }

    var settingsDescription: String {
        switch self {
        case .muslimWorldLeague: "Worldwide default"
        case .isna: "North America"
        case .egyptian: "Egypt and parts of Africa"
        case .ummAlQura: "Saudi Arabia and Gulf"
        case .karachi: "South Asia"
        case .dubai: "United Arab Emirates"
        case .qatar: "Qatar"
        case .kuwait: "Kuwait"
        case .singapore: "Singapore and nearby regions"
        case .tehran: "Iran"
        case .jafari: "Shia Ithna Ashari communities"
        case .moonsightingCommittee: "Moonsighting Committee settings"
        case .northAmerica: "North America calculation profile"
        case .turkey: "Turkey"
        case .other: "Custom or unsupported method"
        }
    }

    nonisolated static func recommendedMethod(for countryCode: String) -> CalculationMethodChoice {
        switch countryCode.uppercased() {
        case "US", "CA":
            return .isna
        case "SA", "AE", "QA", "KW", "BH", "OM":
            return .ummAlQura
        case "GB", "IE":
            return .muslimWorldLeague
        case "PK", "IN", "BD", "LK":
            return .karachi
        case "EG":
            return .egyptian
        case "SG", "MY", "ID", "BN":
            return .singapore
        case "TR":
            return .turkey
        case "IR":
            return .tehran
        default:
            return .muslimWorldLeague
        }
    }
}

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
