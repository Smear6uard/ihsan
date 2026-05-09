import SwiftUI
import IhsanDesignSystem
import IhsanIntents

struct EveningReflectionEntry: View {
    var body: some View {
        ReflectionPromptCard(
            prompt: "Looking back at your day — what helped you turn toward Allah, and what pulled you away?",
            citation: "— al-Ghazālī, Iḥyāʾ ʿUlūm al-Dīn, Book 38",
            onBegin: {
                Task {
                    let intent = OpenReflectionIntent()
                    _ = try? await intent.perform()
                }
            }
        )
    }
}
