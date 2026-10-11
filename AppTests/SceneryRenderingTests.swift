import XCTest
import SwiftUI
import SudokuCore
@testable import SudokuLisa

final class SceneryRenderingTests: XCTestCase {
    @MainActor func testIllustrationsAreBundledAndEachWorldHasLivingForeground() throws {
        for stop in SceneryStop.all {
            let image = try XCTUnwrap(UIImage(named: stop.artworkName), stop.id)
            XCTAssertGreaterThanOrEqual(image.size.width * image.scale, 1024)
            func frame(_ time: Double) throws -> Data {
                let view = Canvas { context, size in
                    SceneryAtmosphere.draw(stop: stop, time: time, context: context, size: size)
                }.frame(width: 320, height: 480)
                return try XCTUnwrap(ImageRenderer(content: view).uiImage?.pngData())
            }
            XCTAssertNotEqual(try frame(1), try frame(2), "Foreground must move for \(stop.id)")
            XCTAssertEqual(try frame(0), try frame(0), "Reduced motion must have a stable frame")
        }
    }

    @MainActor func testAllStopsHaveDistinctStaticArtworkInLightAndDark() throws {
        let previousLanguage = UserDefaults.standard.string(forKey: L10n.languagePreferenceKey)
        UserDefaults.standard.set("fr", forKey: L10n.languagePreferenceKey)
        defer {
            if let previousLanguage { UserDefaults.standard.set(previousLanguage, forKey: L10n.languagePreferenceKey) }
            else { UserDefaults.standard.removeObject(forKey: L10n.languagePreferenceKey) }
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("save.json")
        let store = LisaStore(saveURL: url)
        defer { try? FileManager.default.removeItem(at: url.deletingLastPathComponent()) }
        for scheme in [ColorScheme.light, .dark] {
            var rendered: Set<Data> = []
            for stop in SceneryStop.all {
                let renderer = ImageRenderer(content: LisaScenery(stop: stop, animated: false)
                    .frame(width: 160, height: 240).environmentObject(store).environment(\.colorScheme, scheme))
                let data = try XCTUnwrap(renderer.uiImage?.pngData())
                XCTAssertTrue(rendered.insert(data).inserted, "Artwork must differ for \(stop.id)")
            }
            let gallery = VStack(spacing: 8) {
                ForEach(SceneryWorld.allCases, id: \.self) { world in
                    HStack(spacing: 8) {
                        ForEach(SceneryStop.all.filter { $0.world == world }) { stop in
                            VStack(spacing: 4) {
                                LisaScenery(stop: stop, animated: false).frame(width: 160, height: 240)
                                Text(stop.title).font(.system(size: 11)).foregroundStyle(LisaTheme.ink)
                            }
                        }
                    }
                }
            }.padding(12).background(LisaTheme.paper).environmentObject(store).environment(\.colorScheme, scheme)
            let image = try XCTUnwrap(ImageRenderer(content: gallery).uiImage)
            let attachment = XCTAttachment(image: image)
            attachment.name = "25-escales-\(scheme)"; attachment.lifetime = .keepAlways
            add(attachment)
        }
    }
}
