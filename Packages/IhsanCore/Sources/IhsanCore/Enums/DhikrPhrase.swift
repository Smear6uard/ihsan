import Foundation

/// The tasbīḥ instrument's curated label set, plus a custom slot.
/// String-backed so sessions store a stable key; the custom phrase's
/// own text lives on the session row (encrypted), never here.
public enum DhikrPhrase: String, Codable, CaseIterable, Sendable {
    case subhanallah
    case alhamdulillah
    case allahuAkbar
    case astaghfirullah
    case custom

    public var displayTransliteration: String {
        switch self {
        case .subhanallah: return "Subḥānallāh"
        case .alhamdulillah: return "Alḥamdulillāh"
        case .allahuAkbar: return "Allāhu Akbar"
        case .astaghfirullah: return "Astaghfirullāh"
        case .custom: return "Custom"
        }
    }

    public var displayArabic: String? {
        switch self {
        case .subhanallah: return "سبحان الله"
        case .alhamdulillah: return "الحمد لله"
        case .allahuAkbar: return "الله أكبر"
        case .astaghfirullah: return "أستغفر الله"
        case .custom: return nil
        }
    }
}
