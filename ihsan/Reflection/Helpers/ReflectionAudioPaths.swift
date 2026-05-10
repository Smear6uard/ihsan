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
}
