import Foundation

enum LisaMascotMood: String, CaseIterable, Identifiable {
    var id: String { rawValue }
    case idle, happy, thinking, encouraging, sleepy, celebrating, pirouette, wobble, peek, jelly, swim, bow, curious, giggle, rocket, chase, moonwalk, juggle, cloudHide, sneeze, tumble, balance, dizzy, superhero
    case surprised, nervous, confused, loved, proud

    var isAcrobatic: Bool {
        switch self {
        case .pirouette, .wobble, .jelly, .swim, .bow, .rocket, .chase, .moonwalk,
             .juggle, .cloudHide, .sneeze, .tumble, .balance, .dizzy, .superhero: true
        default: false
        }
    }

    /// Shared by facial articulation, body gestures and the preview sequencer.
    var reactionDuration: Double {
        switch self {
        case .chase, .moonwalk, .juggle, .cloudHide, .sneeze, .tumble, .balance, .dizzy, .superhero: 4.4
        case .curious, .giggle, .peek, .surprised, .nervous, .confused, .loved, .proud: 1.8
        case .sleepy: 3.2
        case .idle: 4
        default: 2.2
        }
    }

    // sin² produces two bounces per cycle: three readable giggles, not six
    // compressed into 1.8 seconds. Face, mantle and arms share this beat.
    var laughCycles: Float { self == .giggle ? 1.5 : 2 }
}

enum LisaMascotExpressionScheduler {
    private static let idleExpressions: [LisaMascotMood] = [.curious, .giggle, .peek, .surprised, .nervous, .confused, .loved, .proud]
    private static let thinkingExpressions: [LisaMascotMood] = [.curious, .confused, .peek]
    private static let happyExpressions: [LisaMascotMood] = [.giggle, .loved, .proud]
    private static let encouragingExpressions: [LisaMascotMood] = [.happy, .proud, .loved]

    static func nextMood(baseMood: LisaMascotMood, previousMood: LisaMascotMood?, sequence: Int) -> LisaMascotMood? {
        let expressions: [LisaMascotMood]
        switch baseMood {
        case .idle: expressions = idleExpressions
        case .thinking: expressions = thinkingExpressions
        case .happy: expressions = happyExpressions
        case .encouraging: expressions = encouragingExpressions
        default: return nil
        }
        let start = ((sequence % expressions.count) + expressions.count) % expressions.count
        for offset in expressions.indices {
            let candidate = expressions[(start + offset) % expressions.count]
            if candidate != baseMood && candidate != previousMood { return candidate }
        }
        return nil
    }
}
