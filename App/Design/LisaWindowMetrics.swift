import SwiftUI

private struct LisaVisibleBoundsKey: EnvironmentKey {
    static let defaultValue: CGRect? = nil
}

extension EnvironmentValues {
    var lisaVisibleBounds: CGRect? {
        get { self[LisaVisibleBoundsKey.self] }
        set { self[LisaVisibleBoundsKey.self] = newValue }
    }
}

/// Follow the screen hosting our single game window, including display changes.
/// Do not infer either display's capabilities from UIScreen.main on a foldable.
struct LisaDisplayObserver: UIViewRepresentable {
    func makeUIView(context: Context) -> DisplayView { DisplayView() }
    func updateUIView(_ view: DisplayView, context: Context) { view.refreshDisplay() }

    final class DisplayView: UIView {
        private var maximumFrames = 0

        override func didMoveToWindow() {
            super.didMoveToWindow()
            refreshDisplay()
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            refreshDisplay()
        }

        func refreshDisplay() {
            guard let screen = window?.windowScene?.screen,
                  maximumFrames != screen.maximumFramesPerSecond else { return }
            maximumFrames = screen.maximumFramesPerSecond
            // UIKit can measure during a SwiftUI update. Publish on the next turn.
            Task { @MainActor [weak self] in
                guard let screen = self?.window?.windowScene?.screen else { return }
                LisaRenderBudget.shared.setDisplayMaximumFrameRate(screen.maximumFramesPerSecond)
            }
        }
    }
}
