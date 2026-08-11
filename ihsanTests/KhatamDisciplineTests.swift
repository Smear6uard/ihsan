import Foundation
import IhsanDesignSystem
import Testing
@testable import ihsan

@Suite("Khatam dignity and data discipline")
struct KhatamDisciplineTests {
    private var repoRoot: URL {
        URL(fileURLWithPath: #filePath)
            .resolvingSymlinksInPath()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private var surfaceFiles: [String] {
        [
            "ihsan/Khatam/Components/KhatamLogSheet.swift",
            "ihsan/Khatam/Components/KhatamPathCards.swift",
            "ihsan/Khatam/Components/KhatamThreadView.swift",
            "ihsan/Khatam/Helpers/KhatamSurfaceModel.swift",
            "ihsan/Khatam/KhatamDetailScreen.swift",
            "ihsan/Khatam/KhatamSetupFlow.swift",
            "Packages/IhsanCore/Sources/IhsanCore/Khatam/KhatamPacing.swift",
            "Packages/IhsanCore/Sources/IhsanCore/Khatam/KhatamPlanWriter.swift",
            "Packages/IhsanCore/Sources/IhsanCore/Models/KhatamPlan.swift",
            "Packages/IhsanCore/Sources/IhsanCore/Models/KhatamEntry.swift",
            "Packages/IhsanCore/Sources/IhsanCore/Enums/KhatamUnit.swift",
        ]
    }

    private func source(_ path: String) throws -> String {
        try String(contentsOf: repoRoot.appending(path: path), encoding: .utf8)
    }

    private func stringLiterals(in source: String) -> String {
        var literals: [String] = []
        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.hasPrefix("//") else { continue }
            var inLiteral = false
            var current = ""
            var previous: Character?
            for character in line {
                if character == "\"", previous != "\\" {
                    if inLiteral { literals.append(current); current = "" }
                    inLiteral.toggle()
                } else if inLiteral {
                    current.append(character)
                }
                previous = character
            }
        }
        return literals.joined(separator: "\n")
    }

    @Test("Khatam copy contains no shame or scoring language")
    func copyIsMerciful() throws {
        let banned = [
            "behind", "missed pages", "catch up", "deficit", "failed",
            "failure", "streak", "percent complete", "percentage complete",
            "% complete",
        ]
        for path in surfaceFiles {
            let literals = stringLiterals(in: try source(path)).lowercased()
            for fragment in banned {
                #expect(!literals.contains(fragment), "\(path) contains '\(fragment)'")
            }
        }
    }

    @Test("Khatam surfaces contain no red treatment")
    func noRedTreatment() throws {
        for path in surfaceFiles {
            let text = try source(path)
            #expect(!text.contains("Color.red"), "\(path) uses Color.red")
            #expect(!text.contains(".foregroundStyle(.red"), "\(path) uses red foreground")
            #expect(!text.contains(".tint(.red"), "\(path) uses red tint")
        }
    }

    @Test("Khatam stores numeric ledger fields and no reading content")
    func modelsAreNumericLedgers() throws {
        let plan = try source("Packages/IhsanCore/Sources/IhsanCore/Models/KhatamPlan.swift")
        let entry = try source("Packages/IhsanCore/Sources/IhsanCore/Models/KhatamEntry.swift")
        let declared = Set(
            (plan + "\n" + entry)
                .split(separator: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { $0.hasPrefix("public var ") }
                .compactMap { line -> String? in
                    line.dropFirst("public var ".count)
                        .prefix { $0.isLetter || $0.isNumber || $0 == "_" }
                        .description
                }
        )
        #expect(declared == [
            "id", "planID", "startDate", "endDate", "unitRaw",
            "mushafPageTotal", "targetCount", "isRamadan", "completedAt",
            "retiredAt", "completionMomentShownAt", "entryDate", "unitsRead",
            "afterPrayerRaw", "createdAt", "modifiedAt",
        ])

        for path in surfaceFiles {
            let scalars = try source(path).unicodeScalars
            let hasArabicScript = scalars.contains { scalar in
                (0x0600...0x06FF).contains(Int(scalar.value))
                    || (0x0750...0x077F).contains(Int(scalar.value))
                    || (0x08A0...0x08FF).contains(Int(scalar.value))
            }
            #expect(!hasArabicScript, "\(path) contains Arabic-script content")
        }
    }
}

@Suite("Khatam surface contrast")
struct KhatamContrastTests {
    @Test("Text and terminal controls hold AA in every SkyPhase")
    func allPhases() {
        for state in PaletteState.allCases {
            let tokens = state.tokens
            for surface in [tokens.panelFillValue, tokens.pageGroundFlatValue] {
                #expect(tokens.inkValue.contrastRatio(against: surface) >= 7.0)
                #expect(tokens.inkSecondaryValue.contrastRatio(against: surface) >= 4.5)
            }
            #expect(tokens.keylineValue.contrastRatio(against: tokens.leafGoldValue) >= 4.5)
            let terminal = max(
                tokens.inkSecondaryValue.contrastRatio(against: tokens.panelFillValue),
                tokens.keylineValue.contrastRatio(against: tokens.panelFillValue)
            )
            #expect(terminal >= 3.0)
        }
    }
}
