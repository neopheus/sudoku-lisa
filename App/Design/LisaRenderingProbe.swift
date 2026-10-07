#if DEBUG || LISA_PERFORMANCE_DIAGNOSTICS
import SwiftUI
import SceneKit
import Metal
import Darwin

/// Explicit diagnostic launch only. Never used by the normal application flow.
struct LisaRenderingProbeView: View {
    @State private var result = "Measuring rendering…"
    var body: some View {
        Text(result).task {
            do {
                try await LisaRenderingProbe.run()
                result = "Rendering report saved"
            } catch { result = "Rendering probe failed: \(error)" }
        }
    }
}

@MainActor
private enum LisaRenderingProbe {
    private final class WeakModel { weak var model: OctopusModel?; init(_ model: OctopusModel) { self.model = model } }
    private final class WeakNode { weak var node: SCNNode?; init(_ node: SCNNode) { self.node = node } }
    private static func memory(_ device: MTLDevice) -> [String: UInt64] {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let status = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        var result = ["metal_allocated_bytes": UInt64(device.currentAllocatedSize)]
        if status == KERN_SUCCESS {
            result["physical_footprint_bytes"] = info.phys_footprint
            result["resident_bytes"] = info.resident_size
        }
        return result
    }
    private static func geometry(_ models: [OctopusModel]) -> [String: Int] {
        var dataAddresses: Set<UInt> = []
        var geometries: Set<ObjectIdentifier> = []
        var bytes = 0, triangles = 0, draws = 0, indexBytes = 0
        func data(_ value: Data) {
            value.withUnsafeBytes { buffer in
                guard let address = buffer.baseAddress else { return }
                if dataAddresses.insert(UInt(bitPattern: address)).inserted { bytes += value.count }
            }
        }
        func geometryData(_ geometry: SCNGeometry) {
            guard geometries.insert(ObjectIdentifier(geometry)).inserted else { return }
            for source in geometry.sources { data(source.data) }
            for element in geometry.elements {
                data(element.data)
                indexBytes += element.data.count
            }
        }
        for model in models {
            model.scene.rootNode.enumerateChildNodes { node, _ in
                if let g = node.geometry {
                    draws += g.elementCount
                    triangles += g.elements.filter { $0.primitiveType == .triangles }.reduce(0) { $0 + $1.primitiveCount }
                    geometryData(g)
                }
                if let skin = node.skinner { data(skin.boneWeights.data); data(skin.boneIndices.data) }
                for target in node.morpher?.targets ?? [] { geometryData(target) }
            }
        }
        return ["unique_buffer_bytes": bytes, "geometry_index_bytes": indexBytes,
                "triangles": triangles, "geometry_elements": draws]
    }
    private static func median(_ values: [Double]) -> Double {
        let ordered = values.sorted()
        return ordered.isEmpty ? 0 : ordered[ordered.count / 2]
    }
    static func run() async throws {
        guard let device = MTLCreateSystemDefaultDevice(), let queue = device.makeCommandQueue() else {
            throw NSError(domain: "RenderingProbe", code: 1)
        }
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("RenderingProbe", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var report: [String: Any] = ["device": device.name,
            "scope": "Fixed 4x MSAA, native-sized offscreen SceneKit; simulator GPU is the host GPU, not an iPhone GPU"]
        report["initial_memory"] = memory(device)
        var models: [OctopusModel] = []
        let start = CACurrentMediaTime()
        var constructionTimes: [Double] = []
        for _ in 0..<8 {
            let modelStart = CACurrentMediaTime()
            autoreleasepool {
                let model = OctopusModel()
                model.setMotionEnabled(false)
                models.append(model)
            }
            constructionTimes.append((CACurrentMediaTime() - modelStart) * 1000)
        }
        report["eight_models_construction_ms"] = (CACurrentMediaTime() - start) * 1000
        report["individual_construction_ms"] = constructionTimes
        report["eight_models_memory"] = memory(device)
        report["eight_models_geometry"] = geometry(models)
        let weakModels = models.map { WeakModel($0) }
        let weakNodes = autoreleasepool { models.map { WeakNode($0.scene.rootNode) } }
        autoreleasepool { models.removeAll() }
        // Let SceneKit transactions and the run-loop autorelease pool drain.
        try await Task.sleep(for: .milliseconds(250))
        SCNTransaction.flush()
        report["released_models"] = weakModels.filter { $0.model == nil }.count
        report["released_scene_roots"] = weakNodes.filter { $0.node == nil }.count
        report["after_release_memory"] = memory(device)
        var cases: [[String: Any]] = []
        for spatial in [false, true] {
            let model = OctopusModel()
            let size = spatial ? CGSize(width: 1179, height: 2556) : CGSize(width: 840, height: 840)
            model.setSpatial(spatial, aspect: Float(size.width / size.height))
            model.setMotionEnabled(false)
            let renderer = SCNRenderer(device: device, options: nil)
            renderer.scene = model.scene
            renderer.pointOfView = model.scene.rootNode.childNodes.first { $0.camera != nil }
            let image = renderer.snapshot(atTime: 0, with: size, antialiasingMode: .multisampling4X)
            try image.pngData()?.write(to: directory.appendingPathComponent(spatial ? "flight.png" : "portrait.png"))
            model.setMotionEnabled(true)
            renderer.isPlaying = true
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: Int(size.width), height: Int(size.height), mipmapped: false)
            descriptor.storageMode = .private
            descriptor.usage = [.renderTarget]
            let resolved = device.makeTexture(descriptor: descriptor)!
            descriptor.textureType = .type2DMultisample
            descriptor.sampleCount = 4
            let color = device.makeTexture(descriptor: descriptor)!
            descriptor.pixelFormat = .depth32Float_stencil8
            let depth = device.makeTexture(descriptor: descriptor)!
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = color
            pass.colorAttachments[0].resolveTexture = resolved
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].storeAction = .multisampleResolve
            pass.depthAttachment.texture = depth
            pass.depthAttachment.loadAction = .clear
            pass.depthAttachment.storeAction = .dontCare
            pass.depthAttachment.clearDepth = 1
            pass.stencilAttachment.texture = depth
            pass.stencilAttachment.loadAction = .clear
            pass.stencilAttachment.storeAction = .dontCare
            var gpu: [Double] = [], encode: [Double] = []
            for frame in 0..<140 {
                let command = queue.makeCommandBuffer()!
                let began = CACurrentMediaTime()
                renderer.render(atTime: Double(frame) / 60, viewport: CGRect(origin: .zero, size: size), commandBuffer: command, passDescriptor: pass)
                let cpuWall = (CACurrentMediaTime() - began) * 1000
                let elapsed: Double? = await withCheckedContinuation { continuation in
                    command.addCompletedHandler { completed in
                        let delta = completed.gpuEndTime - completed.gpuStartTime
                        continuation.resume(returning: completed.status == .completed && completed.gpuStartTime > 0 && delta > 0 ? delta * 1000 : nil)
                    }
                    command.commit()
                }
                guard command.status == .completed else { throw command.error ?? NSError(domain: "RenderingProbe", code: 2) }
                if frame >= 20 {
                    encode.append(cpuWall)
                    if let elapsed { gpu.append(elapsed) }
                }
            }
            cases.append(["name": spatial ? "flight" : "portrait", "width": Int(size.width), "height": Int(size.height), "samples": encode.count,
                          "encode_wall_median_ms": median(encode), "gpu_timing_samples": gpu.count,
                          "gpu_median_ms": gpu.isEmpty ? NSNull() : median(gpu) as Any,
                          "memory": memory(device), "geometry": geometry([model])])
        }
        report["render_cases"] = cases
        try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            .write(to: directory.appendingPathComponent("report.json"), options: .atomic)
    }
}
#endif
