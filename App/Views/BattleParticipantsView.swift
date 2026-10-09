import SwiftUI
import SudokuCore

/// A stable, compact view of the race. Positions do not change when progress changes.
struct BattleParticipantsView: View {
    let participants: [BattleParticipant]
    let localPlayerID: String
    var isLobby = false

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var selectedParticipantID: String?

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
                        BattleParticipantBadge(participant: participant, isLocal: participant.id == localPlayerID, isLobby: isLobby, compact: true,
                            showsStats: selectedParticipantID == participant.id) {
                                toggleStats(for: participant.id)
                            }
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
                    BattleParticipantBadge(participant: participant, isLocal: participant.id == localPlayerID, isLobby: isLobby, compact: false,
                        showsStats: selectedParticipantID == participant.id) {
                            toggleStats(for: participant.id)
                        }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func toggleStats(for participantID: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedParticipantID = selectedParticipantID == participantID ? nil : participantID
        }
    }
}

private struct BattleParticipantBadge: View {
    let participant: BattleParticipant
    let isLocal: Bool
    let isLobby: Bool
    let compact: Bool
    let showsStats: Bool
    let onSelect: () -> Void

    @Environment(\.lisaMotionAllowed) private var motionAllowed
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var reaction: BattleParticipantReaction = .none
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
        Button(action: onSelect) {
            Group {
                if compact {
                    VStack(spacing: 3) {
                        BattleParticipantAvatar(appearance: participant.appearance, fraction: fraction,
                            isLocal: isLocal, reaction: reaction, progressGain: progressGain, canAnimate: canAnimate,
                            compact: compact, participantID: participant.id)
                        BattleParticipantDetails(participant: participant, status: status,
                            percent: percent, isLocal: isLocal, isLobby: isLobby, compact: true,
                            showsStats: showsStats)
                    }
                    .frame(maxWidth: .infinity)
                } else {
                    HStack(alignment: .center, spacing: 9) {
                        BattleParticipantAvatar(appearance: participant.appearance, fraction: fraction,
                            isLocal: isLocal, reaction: reaction, progressGain: progressGain, canAnimate: canAnimate,
                            compact: compact, participantID: participant.id)
                        BattleParticipantDetails(participant: participant, status: status,
                            percent: percent, isLocal: isLocal, isLobby: isLobby, compact: false,
                            showsStats: showsStats)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("battleParticipant-\(participant.id)")
        .accessibilityHint(L10n.text("Touchez un joueur pour afficher ou masquer sa progression et ses erreurs."))
        .onChange(of: participant.progress) { oldValue, newValue in
            guard !isLobby, !isLocal, canAnimate, participant.status == .connected || participant.status == .finished,
                  oldValue.isFinite, newValue.isFinite, newValue > oldValue else { return }
            let gain = Int((newValue * 100).rounded()) - Int((oldValue * 100).rounded())
            guard gain > 0 else { return }
            resetTask?.cancel()
            animate(.progress, gain: gain, duration: 650)
        }
        .onChange(of: participant.mistakes) { oldValue, newValue in
            guard !isLobby, canAnimate, newValue > oldValue,
                  participant.status == .connected else { return }
            animate(.mistake, duration: 700)
        }
        .onChange(of: participant.status) { oldValue, newValue in
            guard canAnimate, oldValue != .finished, newValue == .finished else { return }
            animate(.celebration, duration: 900)
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
        reaction = .none
    }

    private func animate(_ newReaction: BattleParticipantReaction, gain: Int? = nil, duration: Int) {
        resetTask?.cancel()
        withAnimation(.spring(response: 0.28, dampingFraction: 0.55)) {
            reaction = newReaction
            progressGain = gain
        }
        resetTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(duration))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.22)) {
                reaction = .none
                progressGain = nil
            }
        }
    }
}

private enum BattleParticipantReaction: Equatable {
    case none, progress, mistake, celebration
}

private struct BattleParticipantAvatar: View {
    let appearance: PoulpiAppearance
    let fraction: Double
    let isLocal: Bool
    let reaction: BattleParticipantReaction
    let progressGain: Int?
    let canAnimate: Bool
    let compact: Bool
    let participantID: String

    private var pulse: Bool { reaction != .none }

    private var progressColor: Color {
        if fraction >= 1 { LisaTheme.yellow }
        else if fraction >= 0.68 { LisaTheme.coral }
        else if fraction >= 0.30 { LisaTheme.actionInk }
        else { LisaTheme.mint }
    }

    private var avatarScale: CGFloat {
        switch reaction {
        case .none: 1
        case .progress: 1.10
        case .mistake: 0.91
        case .celebration: 1.14
        }
    }

    var body: some View {
        ZStack {
            Circle().stroke(isLocal ? LisaTheme.actionInk.opacity(0.65) : LisaTheme.line.opacity(0.55), lineWidth: 4)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(progressColor, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(canAnimate ? .easeOut(duration: 0.35) : nil, value: fraction)
                .animation(canAnimate ? .easeInOut(duration: 0.3) : nil, value: progressColor)
            if pulse {
                Circle()
                    .stroke(reaction == .mistake ? LisaTheme.coral.opacity(0.72) : progressColor.opacity(0.62), lineWidth: 3)
                    .scaleEffect(reaction == .celebration ? 1.28 : 1.18)
                    .transition(.opacity.combined(with: .scale(scale: 0.75)))
            }
            if reaction == .celebration {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(LisaTheme.yellow)
                    .offset(x: compact ? 16 : 19, y: compact ? -15 : -18)
                    .transition(.scale.combined(with: .opacity))
            }
            PoulpiAvatar(appearance: appearance, size: compact ? 38 : 43)
                .scaleEffect(avatarScale)
                .rotationEffect(.degrees(reaction == .mistake ? -7 : reaction == .progress ? 4 : reaction == .celebration ? -5 : 0))
                .offset(y: reaction == .progress || reaction == .celebration ? -3 : 0)
                .animation(canAnimate ? .spring(response: 0.26, dampingFraction: 0.48) : nil, value: reaction)
                .accessibilityHidden(true)
        }
        .frame(width: compact ? 46 : 54, height: compact ? 46 : 54)
        .overlay(alignment: .topTrailing) {
            if let progressGain {
                Text("+\(progressGain)%")
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .fixedSize()
                .foregroundStyle(LisaTheme.actionInk)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(LisaTheme.paper, in: Capsule())
                .offset(x: 4, y: -18)
                .transition(.opacity.combined(with: .scale(scale: 0.8)))
                .accessibilityIdentifier("battleGain-\(participantID)")
            }
        }
    }
}

private struct BattleParticipantDetails: View {
    let participant: BattleParticipant
    let status: String
    let percent: Int
    let isLocal: Bool
    let isLobby: Bool
    let compact: Bool
    let showsStats: Bool

    var body: some View {
        VStack(alignment: compact ? .center : .leading, spacing: 2) {
            Text(isLocal ? L10n.text("%@ · vous", participant.name) : participant.name)
                .font((compact ? Font.caption : Font.subheadline).weight(.semibold))
                .foregroundStyle(LisaTheme.ink)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(compact ? .center : .leading)
                .fixedSize(horizontal: false, vertical: true)
            if showsStats && !isLobby {
                HStack(spacing: 6) {
                    Text("\(percent)%")
                        .monospacedDigit()
                        .accessibilityIdentifier("battleProgress-\(participant.id)")
                    Text("·").accessibilityHidden(true)
                    Label {
                        Text("\(participant.mistakes)").monospacedDigit()
                    } icon: {
                        Image(systemName: "xmark").font(.system(size: 7, weight: .bold))
                    }
                    .accessibilityLabel(L10n.text("Erreurs : %@", String(participant.mistakes)))
                    .accessibilityIdentifier("battleMistakes-\(participant.id)")
                }
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundStyle(LisaTheme.actionInk)
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(LisaTheme.paper, in: Capsule())
                .overlay(Capsule().stroke(LisaTheme.line, lineWidth: 1))
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .accessibilityElement(children: .contain)
                .accessibilityIdentifier("battleStats-\(participant.id)")
            }
            if isLobby || (!compact && status != L10n.text("En course")) {
                Text(status)
            }
        }
        .font(.caption2)
        .foregroundStyle(LisaTheme.muted)
        .multilineTextAlignment(compact ? .center : .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

}
