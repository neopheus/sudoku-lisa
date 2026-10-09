import SwiftUI
import SudokuCore

/// A stable, compact view of the race. Positions do not change when progress changes.
struct BattleParticipantsView: View {
    let participants: [BattleParticipant]
    let localPlayerID: String
    var isLobby = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    private var orderedParticipants: [BattleParticipant] {
        participants.sorted {
            if $0.id == $1.id { return false }
            if $0.id == localPlayerID { return true }
            if $1.id == localPlayerID { return false }
            return $0.id < $1.id
        }
    }

    private var canUseSingleRow: Bool {
        dynamicTypeSize <= .large && participants.count <= 4
            && participants.allSatisfy { $0.name.count <= 15 }
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            if canUseSingleRow {
                HStack(alignment: .top, spacing: 6) {
                    ForEach(orderedParticipants) { participant in
                        BattleParticipantBadge(participant: participant, isLocal: participant.id == localPlayerID, isLobby: isLobby, compact: true)
                            .frame(width: 80)
                    }
                }
                .frame(width: CGFloat(orderedParticipants.count * 80 + max(0, orderedParticipants.count - 1) * 6))
            }
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: dynamicTypeSize.isAccessibilitySize ? 1 : 2),
                spacing: 8
            ) {
                ForEach(orderedParticipants) { participant in
                    BattleParticipantBadge(participant: participant, isLocal: participant.id == localPlayerID, isLobby: isLobby, compact: false)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityIdentifier("battleParticipants")
    }
}

private struct BattleParticipantBadge: View {
    let participant: BattleParticipant
    let isLocal: Bool
    let isLobby: Bool
    let compact: Bool

    @Environment(\.lisaMotionAllowed) private var motionAllowed
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var pulse = false
    @State private var progressGain: Int?
    @State private var resetTask: Task<Void, Never>?

    private var fraction: Double {
        participant.progress.isFinite ? min(1, max(0, participant.progress)) : 0
    }

    private var percent: Int { Int((fraction * 100).rounded()) }

    private var canAnimate: Bool {
        motionAllowed && !reduceMotion && scenePhase == .active
    }

    private var status: String {
        switch participant.status {
        case .connected: isLobby ? L10n.text(participant.ready ? "Prêt" : "Se prépare") : L10n.text("En course")
        case .interrupted: L10n.text("Connexion interrompue · 30 s maximum")
        case .finished: L10n.text("Grille terminée")
        case .didNotFinish: L10n.text("Abandon")
        }
    }

    var body: some View {
        Group {
            if compact {
                VStack(spacing: 3) {
                    BattleParticipantAvatar(appearance: participant.appearance, fraction: fraction,
                        isLocal: isLocal, pulse: pulse, progressGain: progressGain, canAnimate: canAnimate, compact: compact)
                    BattleParticipantDetails(participant: participant, status: status,
                        percent: percent, isLocal: isLocal, isLobby: isLobby, compact: true)
                }
                .frame(maxWidth: .infinity)
            } else {
                HStack(alignment: .center, spacing: 9) {
                    BattleParticipantAvatar(appearance: participant.appearance, fraction: fraction,
                        isLocal: isLocal, pulse: pulse, progressGain: progressGain, canAnimate: canAnimate, compact: compact)
                    BattleParticipantDetails(participant: participant, status: status,
                        percent: percent, isLocal: isLocal, isLobby: isLobby, compact: false)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("battleParticipant-\(participant.id)")
        .onChange(of: participant.progress) { oldValue, newValue in
            guard !isLobby, !isLocal, canAnimate, participant.status == .connected || participant.status == .finished,
                  oldValue.isFinite, newValue.isFinite, newValue > oldValue else { return }
            let gain = Int((newValue * 100).rounded()) - Int((oldValue * 100).rounded())
            guard gain > 0 else { return }
            resetTask?.cancel()
            withAnimation(.easeOut(duration: 0.18)) {
                progressGain = gain
                pulse = true
            }
            resetTask = Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(650))
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.2)) {
                    progressGain = nil
                    pulse = false
                }
            }
        }
        .onChange(of: canAnimate) { _, enabled in
            if !enabled { stopAnimation() }
        }
        .onDisappear { stopAnimation() }
    }

    private func stopAnimation() {
        resetTask?.cancel()
        resetTask = nil
        progressGain = nil
        pulse = false
    }
}

private struct BattleParticipantAvatar: View {
    let appearance: PoulpiAppearance
    let fraction: Double
    let isLocal: Bool
    let pulse: Bool
    let progressGain: Int?
    let canAnimate: Bool
    let compact: Bool

    var body: some View {
        ZStack {
            Circle().stroke(isLocal ? LisaTheme.actionInk.opacity(0.65) : LisaTheme.line.opacity(0.55), lineWidth: 4)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(LisaTheme.actionInk, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(canAnimate ? .easeOut(duration: 0.35) : nil, value: fraction)
            if pulse {
                Circle()
                    .stroke(LisaTheme.actionInk.opacity(0.55), lineWidth: 3)
                    .scaleEffect(1.18)
                    .transition(.opacity.combined(with: .scale(scale: 0.75)))
            }
            PoulpiAvatar(appearance: appearance, size: compact ? 38 : 43)
                .scaleEffect(pulse ? 1.08 : 1)
        }
        .frame(width: compact ? 46 : 54, height: compact ? 46 : 54)
        .overlay(alignment: .topTrailing) {
            if let progressGain {
                Label {
                    Text(Double(progressGain) / 100, format: .percent.precision(.fractionLength(0)))
                } icon: {
                    Image(systemName: "arrow.up")
                }
                .font(.caption2.weight(.bold))
                .foregroundStyle(LisaTheme.actionInk)
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(LisaTheme.paper, in: Capsule())
                .offset(x: 8, y: -7)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
        }
        .accessibilityHidden(true)
    }
}

private struct BattleParticipantDetails: View {
    let participant: BattleParticipant
    let status: String
    let percent: Int
    let isLocal: Bool
    let isLobby: Bool
    let compact: Bool

    var body: some View {
        VStack(alignment: compact ? .center : .leading, spacing: 2) {
            Text(isLocal ? L10n.text("%@ · vous", participant.name) : participant.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(LisaTheme.ink)
                .multilineTextAlignment(compact ? .center : .leading)
                .fixedSize(horizontal: false, vertical: true)
            if !isLobby {
                if compact {
                    progress
                    mistakes
                } else {
                    HStack(spacing: 5) {
                        progress
                        Text("·").accessibilityHidden(true)
                        mistakes
                    }
                }
            }
            if status != L10n.text("En course") {
                Text(status)
            }
        }
        .font(.caption2)
        .foregroundStyle(LisaTheme.muted)
        .multilineTextAlignment(compact ? .center : .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var progress: some View {
        Text(Double(percent) / 100, format: .percent.precision(.fractionLength(0)))
            .monospacedDigit()
            .accessibilityIdentifier("battleProgress-\(participant.id)")
    }

    private var mistakes: some View {
        Text(L10n.text("Erreurs : %@", String(participant.mistakes)))
            .accessibilityIdentifier("battleMistakes-\(participant.id)")
    }
}
