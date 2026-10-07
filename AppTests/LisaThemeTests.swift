import XCTest
import SwiftUI
import UIKit
@testable import SudokuLisa

@MainActor
final class LisaThemeTests: XCTestCase {
    func testTextContrastOnCandySurfaces() {
        var minimumRatio = Double.infinity
        for style in [UIUserInterfaceStyle.light, .dark] {
            let traits = UITraitCollection(userInterfaceStyle: style)
            for surface in [LisaTheme.paper, LisaTheme.lavender, LisaTheme.mint, LisaTheme.yellow] {
                let background = components(surface, traits: traits)
                // The top of CandySurface carries its brightest white highlight.
                let highlight = style == .dark ? 0.06 : 0.20
                let highlighted = background.map { $0 + (1 - $0) * highlight }
                for foreground in [LisaTheme.ink, LisaTheme.muted, LisaTheme.actionInk] {
                    minimumRatio = min(minimumRatio, contrast(components(foreground, traits: traits), background), contrast(components(foreground, traits: traits), highlighted))
                    XCTAssertGreaterThanOrEqual(contrast(components(foreground, traits: traits), background), 4.5)
                    XCTAssertGreaterThanOrEqual(contrast(components(foreground, traits: traits), highlighted), 4.5)
                }
            }
            let coral = components(LisaTheme.coral, traits: traits).map { $0 + (1 - $0) * 0.06 }
            XCTAssertGreaterThanOrEqual(contrast([1, 1, 1], coral), 4.5)
        }
        print("ACCESSIBILITY minimum tested theme contrast: \(minimumRatio)")
    }

    func testRoundedBodyFontScalesWithViewEnvironment() {
        func height(_ size: DynamicTypeSize, font: Font) -> CGFloat {
            let host = UIHostingController(rootView:
                Text("Lisa Sudoku").font(font)
                    .fixedSize().environment(\.dynamicTypeSize, size))
            return host.sizeThatFits(in: CGSize(width: 1_000, height: 1_000)).height
        }
        for font in [LisaTheme.body(16), LisaTheme.heading(24)] {
            let standard = height(.large, font: font)
            XCTAssertGreaterThan(standard, 10)
            let enlarged = height(.accessibility5, font: font)
            print("ACCESSIBILITY font height: \(standard) -> \(enlarged), ratio \(enlarged / standard)")
            XCTAssertGreaterThanOrEqual(enlarged, standard * 2)
        }
    }

    private func components(_ color: Color, traits: UITraitCollection) -> [Double] {
        let resolved = UIColor(color).resolvedColor(with: traits)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        XCTAssertTrue(resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha))
        return [Double(red), Double(green), Double(blue)]
    }

    private func contrast(_ first: [Double], _ second: [Double]) -> Double {
        func luminance(_ rgb: [Double]) -> Double {
            zip(rgb, [0.2126, 0.7152, 0.0722]).reduce(0) { result, pair in
                let (component, weight) = pair
                return result + weight * (component <= 0.04045 ? component / 12.92 : pow((component + 0.055) / 1.055, 2.4))
            }
        }
        let firstLuminance = luminance(first), secondLuminance = luminance(second)
        return (max(firstLuminance, secondLuminance) + 0.05) / (min(firstLuminance, secondLuminance) + 0.05)
    }
}
