import Foundation
import IhsanCore

/// Resolves on-disk locations for voice-memo audio files.
///
/// Audio stays on the device that recorded it — files live in the App Group
/// container and never sync via CloudKit. This is a deliberate privacy
/// tradeoff: the transcript syncs (the Reflection record's `transcript`
/// attribute is `.allowsCloudEncryption`), but the raw audio does not.
enum ReflectionAudioPaths {
    /// Subfolder inside the App Group container for voice-memo files.
    static let voiceMemosFolderName = "VoiceMemos"

    enum PathError: Error {
        case appGroupUnavailable
    }

    /// URL of the directory holding all voice memos. Created on first access.
    static func voiceMemosDirectory() throws -> URL {
        guard let container = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier:
                IhsanModelContainerFactory.appGroupIdentifier
        ) else {
            throw PathError.appGroupUnavailable
        }
        let directory = container.appendingPathComponent(
            voiceMemosFolderName,
            isDirectory: true
        )
        if !FileManager.default.fileExists(atPath: directory.path) {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
        }
        return directory
    }

    /// File URL for a voice memo with the given UUID.
    /// Files use `.m4a` (AAC) — small, broadly supported, gracefully streamable.
    static func fileURL(for memoID: UUID) throws -> URL {
        try voiceMemosDirectory()
            .appendingPathComponent("\(memoID.uuidString).m4a")
    }

    /// Returns the file URL only if the file actually exists on disk. Useful
    /// when rendering a feed card: a record may carry a `voiceMemoID` whose
    /// audio file was lost (uninstall/reinstall, restore from backup) and the
    /// pill should fall back to text-only rendering rather than show a
    /// broken playback control.
    static func existingFileURL(for memoID: UUID) -> URL? {
        guard let url = try? fileURL(for: memoID),
              FileManager.default.fileExists(atPath: url.path)
        else {
            return nil
        }
        return url
    }

    /// Removes audio files in the voice-memos directory that aren't
    /// referenced by any persisted Reflection. Catches orphans from
    /// force-quit during recording (the file lives, but no Reflection
    /// record was ever created for it).
    ///
    /// `minAge` is a guard against deleting files that belong to an
    /// in-flight recording started milliseconds ago — only files
    /// modified at least that long ago are considered for removal.
    /// Default 5 minutes is well above any plausible recording length
    /// AND above the time it takes to save after stopping.
    ///
    /// Returns the number of orphan files removed; the call is
    /// best-effort and does not throw on individual removal failures.
    @discardableResult
    static func cleanupOrphans(
        knownMemoIDs: Set<UUID>,
        minAge: TimeInterval = 5 * 60
    ) -> Int {
        guard let directory = try? voiceMemosDirectory() else { return 0 }
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }
        let cutoff = Date.now.addingTimeInterval(-minAge)
        var removed = 0
        for url in contents where url.pathExtension == "m4a" {
            let stem = url.deletingPathExtension().lastPathComponent
            guard let id = UUID(uuidString: stem) else { continue }
            if knownMemoIDs.contains(id) { continue }
            if let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate, modified > cutoff {
                continue
            }
            if (try? fm.removeItem(at: url)) != nil {
                removed += 1
            }
        }
        return removed
    }

    /// Removes the local voice-memo directory after the user confirms
    /// Delete All Data. Unlike orphan cleanup this is immediate: the
    /// records and their files are one user-selected deletion scope.
    static func deleteAllVoiceMemos() {
        guard let directory = try? voiceMemosDirectory() else { return }
        try? FileManager.default.removeItem(at: directory)
    }
}
