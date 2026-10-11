import SceneKit
import UIKit
import SudokuCore

/// A welded sculpt with 24 arm joints. Skin and cups share the same GPU skinning.
final class PoulpiRig: @unchecked Sendable {
    let node = SCNNode()
    // SceneKit action callbacks and SwiftUI updates can arrive on different
    // threads. One recursive lock serializes pose state and node writes.
    private let lock = NSRecursiveLock()
    private var mood: LisaMascotMood = .idle
    private var swimming: CompanionFlight.SwimPose?
    private var swimWeight: Float = 0
    private var bends = Array(repeating: Float(0), count: 24)
    private var twists = Array(repeating: Float(0), count: 24)
    private static let armAngles = (0..<8).map { Float($0) * .pi / 4 + .pi / 8 }
    private static let armSines = armAngles.map { sin($0) }
    private static let curlAxes = armAngles.map { SIMD3<Float>(cos($0), 0, -sin($0)) }

    func setSwimming(_ pose: CompanionFlight.SwimPose?) {
        lock.lock(); swimming = pose; lock.unlock()
    }
    private var animationClock = PoulpiAnimationClock()
    private var bones: [SCNNode] = []
    private var pupils: [SCNNode] = []
    private var brows: [SCNNode] = []
    private var eyelids: [SCNMorpher] = []
    private var lidMaterials: [SCNMaterial] = []
    private var eyelidClosure = [Float]([-1, -1])
    private var eyelidWeights = [PoulpiEyelidWeights(), PoulpiEyelidWeights()]
    private var lastBodyScale: SIMD3<Float>?
    private var lastFace: FacePose?
    // Expression transitions must never retain a transient automatic blink.
    private var lastExpressionFace: FacePose?
    private var transitionFace: FacePose?
    private var reactionElapsed: Float = 0
    private var lastJointOrientations = Array<simd_quatf?>(repeating: nil, count: 24)
    private let mouth = SCNNode()
    private let mouthCavity = SCNNode()
    private var mouthMaterial: SCNMaterial?
    private let cupsNode = SCNNode()
    private var skinMaterial: SCNMaterial?
    private var coloredFaceMaterials: [SCNMaterial] = []
    private let accessoryNode: SCNNode = { let node = SCNNode(); node.name = "poulpi-accessory"; return node }()
    private var appearance = PoulpiAppearance()

    private struct FacePose: Equatable {
        var lids: SIMD2<Float> = .zero
        var gaze: SIMD2<Float> = .zero
        var brows: SIMD2<Float> = .zero
        var smile: Float = 0
        var opening: Float = 0
        var roundness: Float = 0
        var pupilScale: Float = 1
        var headTilt: Float = 0
        var armEnergy: Float = 0.06
    }

    // Values describe a held expression. The common reaction envelope below
    // adds anticipation, an accent and a short settle without allocating actions.
    private static func expression(for mood: LisaMascotMood) -> FacePose {
        switch mood {
        case .idle: FacePose(gaze: SIMD2(0, -0.01), smile: 0.12, armEnergy: 0.04)
        case .happy: FacePose(lids: SIMD2(0.12, 0.12), gaze: SIMD2(0, 0.01), brows: SIMD2(0.02, 0.02), smile: 0.8, opening: 0.32, armEnergy: 0.16)
        case .thinking: FacePose(lids: SIMD2(0.12, 0), gaze: SIMD2(-0.025, 0.015), brows: SIMD2(0.045, -0.005), smile: -0.15, headTilt: -0.045, armEnergy: 0.07)
        case .encouraging: FacePose(lids: SIMD2(0.18, 0), gaze: SIMD2(0.016, 0.005), brows: SIMD2(0.02, 0.045), smile: 0.65, opening: 0.22, headTilt: 0.045, armEnergy: 0.15)
        case .sleepy: FacePose(lids: SIMD2(0.95, 0.92), gaze: SIMD2(0, -0.015), brows: SIMD2(-0.025, -0.025), opening: 0.10, roundness: 0.6, headTilt: -0.06, armEnergy: 0.02)
        case .celebrating: FacePose(lids: SIMD2(0.2, 0.18), gaze: SIMD2(0, 0.02), brows: SIMD2(0.07, 0.07), smile: 1, opening: 0.70, armEnergy: 0.28)
        case .pirouette: FacePose(lids: SIMD2(0.1, 0.28), gaze: SIMD2(0.025, 0.005), brows: SIMD2(0.02, 0.05), smile: 0.66, opening: 0.27, headTilt: 0.12, armEnergy: 0.24)
        case .wobble: FacePose(lids: SIMD2(0.3, 0.08), gaze: SIMD2(0.024, -0.015), brows: SIMD2(-0.02, 0.045), smile: -0.25, opening: 0.25, roundness: 0.35, headTilt: -0.09, armEnergy: 0.20)
        case .peek: FacePose(lids: SIMD2(0.78, 0.12), gaze: SIMD2(-0.025, 0.012), brows: SIMD2(-0.03, 0.04), smile: 0.35, headTilt: -0.07, armEnergy: 0.13)
        case .jelly: FacePose(lids: SIMD2(0.22, 0.26), gaze: SIMD2(0.015, -0.012), brows: SIMD2(0.02, 0.015), smile: 0.42, opening: 0.30, armEnergy: 0.30)
        case .swim: FacePose(lids: SIMD2(0.10, 0.10), gaze: SIMD2(0, 0.017), brows: SIMD2(0.01, 0.01), smile: 0.35, opening: 0.13, armEnergy: 0.19)
        case .bow: FacePose(lids: SIMD2(0.42, 0.42), gaze: SIMD2(0, -0.021), brows: SIMD2(-0.01, -0.01), smile: 0.45, headTilt: -0.15, armEnergy: 0.10)
        case .curious: FacePose(lids: SIMD2(0, 0.18), gaze: SIMD2(0.025, 0.020), brows: SIMD2(0.065, -0.015), smile: 0.20, opening: 0.15, roundness: 0.55, headTilt: 0.075, armEnergy: 0.11)
        case .giggle: FacePose(lids: SIMD2(0.48, 0.35), gaze: SIMD2(-0.012, 0), brows: SIMD2(0.03, 0.035), smile: 1, opening: 0.48, headTilt: -0.04, armEnergy: 0.22)
        case .rocket: FacePose(lids: SIMD2(0.18, 0.18), gaze: SIMD2(0, 0.025), brows: SIMD2(-0.012, -0.012), smile: 0.55, opening: 0.36, armEnergy: 0.28)
        case .chase: FacePose(lids: SIMD2(0.12, 0.28), gaze: SIMD2(0.028, 0.005), brows: SIMD2(-0.005, 0.012), smile: 0.48, opening: 0.27, headTilt: 0.05, armEnergy: 0.25)
        case .moonwalk: FacePose(lids: SIMD2(0.10, 0.52), gaze: SIMD2(-0.020, 0.008), brows: SIMD2(0.035, 0.005), smile: 0.70, headTilt: -0.09, armEnergy: 0.21)
        case .juggle: FacePose(lids: SIMD2(0.05, 0.05), gaze: SIMD2(0, 0.025), brows: SIMD2(0.05, 0.05), smile: 0.60, opening: 0.24, roundness: 0.18, armEnergy: 0.26)
        case .cloudHide: FacePose(lids: SIMD2(0.68, 0.70), gaze: SIMD2(-0.015, -0.018), brows: SIMD2(-0.035, -0.025), smile: -0.18, headTilt: -0.10, armEnergy: 0.11)
        case .sneeze: FacePose(lids: SIMD2(0.83, 0.80), gaze: SIMD2(0, -0.018), brows: SIMD2(-0.045, -0.045), opening: 0.74, roundness: 0.76, headTilt: -0.12, armEnergy: 0.30)
        case .tumble: FacePose(lids: SIMD2(0.28, 0.05), gaze: SIMD2(0.025, -0.015), brows: SIMD2(0.005, 0.055), smile: 0.42, opening: 0.36, roundness: 0.25, headTilt: 0.12, armEnergy: 0.28)
        case .balance: FacePose(lids: SIMD2(0.08, 0.26), gaze: SIMD2(-0.020, -0.005), brows: SIMD2(0.04, -0.015), smile: -0.05, opening: 0.12, headTilt: -0.085, armEnergy: 0.16)
        case .dizzy: FacePose(lids: SIMD2(0.42, 0.15), gaze: SIMD2(0.025, 0.020), brows: SIMD2(0.045, -0.025), opening: 0.45, roundness: 0.55, headTilt: 0.13, armEnergy: 0.24)
        case .superhero: FacePose(lids: SIMD2(0.12, 0.12), gaze: SIMD2(0, 0.018), brows: SIMD2(-0.015, -0.015), smile: 0.60, opening: 0.18, headTilt: 0.045, armEnergy: 0.25)
        case .surprised: FacePose(gaze: SIMD2(0, 0.024), brows: SIMD2(0.075, 0.075), opening: 0.72, roundness: 1, pupilScale: 1.28, armEnergy: 0.22)
        case .nervous: FacePose(lids: SIMD2(0.30, 0.16), gaze: SIMD2(0.026, -0.012), brows: SIMD2(-0.025, 0.035), smile: -0.42, opening: 0.16, pupilScale: 0.88, headTilt: 0.045, armEnergy: 0.20)
        case .confused: FacePose(lids: SIMD2(0.18, 0.35), gaze: SIMD2(-0.025, 0), brows: SIMD2(0.075, -0.025), smile: -0.28, opening: 0.20, roundness: 0.35, pupilScale: 1.08, headTilt: -0.07, armEnergy: 0.13)
        case .loved: FacePose(lids: SIMD2(0.34, 0.34), gaze: SIMD2(0, -0.006), brows: SIMD2(0.04, 0.04), smile: 0.85, opening: 0.30, pupilScale: 1.18, headTilt: 0.055, armEnergy: 0.13)
        case .proud: FacePose(lids: SIMD2(0.22, 0.20), gaze: SIMD2(0.010, 0.010), brows: SIMD2(0.055, 0.055), smile: 0.65, opening: 0.12, pupilScale: 1.08, headTilt: 0.045, armEnergy: 0.18)
        }
    }


    private static let inspectionBlink: Float? = {
        #if DEBUG
        let args=ProcessInfo.processInfo.arguments
        if args.contains("--octopus-preview") {
            if args.contains("--octopus-eyelids-closed") { return 1 }
            if args.contains("--octopus-eyelids-intermediate") { return 0.625 }
            if args.contains("--octopus-eyelids-half") { return 0.5 }
        }
        #endif
        return nil
    }()

    private struct Mesh: Decodable {
        let positions: [Float], normals: [Float], weights: [Float], occlusion: [Float]
        let indices: [UInt32], bones: [UInt16]
        let textureCoordinates: [Float]?
    }
    private struct Surface: Decodable { let positions: [Float], normals: [Float], textureCoordinates: [Float]; let indices: [UInt32] }
    private struct Joint: Decodable { let parent: Int; let position: [Float] }
    private struct Asset: Decodable { let version: Int; let joints: [Joint]; let skin: Mesh; let cups: Mesh; let mouth: Surface }
    /// Shared immutable buffers. The decoded JSON arrays are released after
    /// conversion; every instance owns only its bones and mutable materials.
    private struct SkinnedMesh {
        let geometry: SCNGeometry
        let weights: SCNGeometrySource
        let boneIndices: SCNGeometrySource
        init(_ mesh: Mesh, tint: Bool) {
            geometry = PoulpiRig.geometry(mesh, tint: tint)
            weights = PoulpiRig.source(mesh.weights, semantic: .boneWeights, count: mesh.weights.count / 4, components: 4, floating: true)
            boneIndices = PoulpiRig.source(mesh.bones, semantic: .boneIndices, count: mesh.bones.count / 4, components: 4, floating: false)
        }
    }
    private struct Resources {
        let joints: [Joint]
        let inverseBindTransforms: [NSValue]
        let skin: SkinnedMesh
        let cups: SkinnedMesh
        let mouth: SCNGeometry
    }
    nonisolated(unsafe) private static let resources: Resources = autoreleasepool {
        guard let url = Bundle.main.url(forResource: "poulpi-rig", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let asset = try? JSONDecoder().decode(Asset.self, from: data), asset.version == 1 else {
            preconditionFailure("Missing validated Poulpi sculpt")
        }
        return Resources(joints: asset.joints,
                         inverseBindTransforms: asset.joints.map { joint in
                             NSValue(scnMatrix4: SCNMatrix4MakeTranslation(-joint.position[0], -joint.position[1], -joint.position[2]))
                         },
                         skin: SkinnedMesh(asset.skin, tint: true), cups: SkinnedMesh(asset.cups, tint: false),
                         mouth: mouthGeometry(asset.mouth))
    }
    // The reference supplies the iris and lip pigment on curved 3D geometry.
    private static let referenceTexture: UIImage = {
        guard let url=Bundle.main.url(forResource:"poulpi-eye-reference",withExtension:"png"),
              let image=UIImage(contentsOfFile:url.path) else {
            preconditionFailure("Missing Poulpi iris reference")
        }
        return image
    }()
    private static func source<T>(_ values: [T], semantic: SCNGeometrySource.Semantic, count: Int, components: Int, floating: Bool) -> SCNGeometrySource {
        let data = values.withUnsafeBytes { Data($0) }
        return SCNGeometrySource(data: data, semantic: semantic, vectorCount: count, usesFloatComponents: floating,
                                 componentsPerVector: components, bytesPerComponent: MemoryLayout<T>.size,
                                 dataOffset: 0, dataStride: MemoryLayout<T>.size * components)
    }
    private static func geometry(_ mesh: Mesh, tint: Bool = true) -> SCNGeometry {
        var colors: [Float] = [], uv: [Float] = []
        colors.reserveCapacity(mesh.positions.count / 3 * 4)
        for i in stride(from: 0, to: mesh.positions.count, by: 3) {
            let x = mesh.positions[i], y = mesh.positions[i+1], z = mesh.positions[i+2]
            let ao = 0.45 + mesh.occlusion[i/3] * 0.55
            // Pigment transitions and blush belong to the skin, not floating discs.
            colors += tint ? [ao,ao,ao,1] : [1,1,1,1]
            if mesh.textureCoordinates == nil { uv += [atan2(x,z)/(2 * .pi)+0.5, y*0.5+0.5] }
        }
        if let coordinates=mesh.textureCoordinates {
            precondition(coordinates.count==mesh.positions.count/3*2,"Invalid mesh UV count")
            uv=coordinates
        }
        return SCNGeometry(sources: [source(uv, semantic: .texcoord, count: uv.count/2, components: 2, floating: true), source(colors, semantic: .color, count: colors.count/4, components: 4, floating: true), source(mesh.positions, semantic: .vertex, count: mesh.positions.count / 3, components: 3, floating: true),
                              source(mesh.normals, semantic: .normal, count: mesh.normals.count / 3, components: 3, floating: true)],
                    elements: [triangleElement(mesh.indices)])
    }
    /// Lossless index compaction: every vertex and triangle stays identical.
    /// The fallback also supports future sculpts larger than 65,536 vertices.
    private static func triangleElement(_ indices: [UInt32]) -> SCNGeometryElement {
        if (indices.max() ?? 0) <= UInt32(UInt16.max) {
            return SCNGeometryElement(indices: indices.map { UInt16($0) }, primitiveType: .triangles)
        }
        return SCNGeometryElement(indices: indices, primitiveType: .triangles)
    }
    private static func material(_ color: UIColor, roughness: CGFloat = 0.48) -> SCNMaterial {
        let m = SCNMaterial(); m.lightingModel = .physicallyBased
        m.diffuse.contents = color; m.roughness.contents = roughness; m.metalness.contents = 0
        return m
    }
    // Shared filtered pores keep the small facial volumes consistent with skin.
    private static let grainGeometryModifier = """
        #pragma varyings
        float3 sculptPosition;
        #pragma body
        out.sculptPosition = _geometry.position.xyz;
        """
    private static func grainSurfaceModifier(strength: String = "1.0") -> String { """
        float poreHash(float3 p) {
            p=fract(p*0.1031);
            p+=dot(p,p.yzx+33.33);
            return fract((p.x+p.y)*p.z);
        }
        float poreNoise(float3 p) {
            float3 i=floor(p),f=fract(p);f=f*f*(3.0-2.0*f);
            float a=mix(poreHash(i),poreHash(i+float3(1,0,0)),f.x);
            float b=mix(poreHash(i+float3(0,1,0)),poreHash(i+float3(1,1,0)),f.x);
            float c=mix(poreHash(i+float3(0,0,1)),poreHash(i+float3(1,0,1)),f.x);
            float d=mix(poreHash(i+float3(0,1,1)),poreHash(i+float3(1,1,1)),f.x);
            return mix(mix(a,b,f.y),mix(c,d,f.y),f.z);
        }
        #pragma body
        float grainStrength=\(strength);
        float3 grainPoint=in.sculptPosition*180.0;
        float footprint=max(length(dfdx(grainPoint)),length(dfdy(grainPoint)));
        float grainVisibility=1.0-smoothstep(0.55,1.4,footprint);
        float grain=poreNoise(grainPoint);
        float3 mottlePoint=in.sculptPosition*72.0;
        float mottleVisibility=1.0-smoothstep(0.55,1.4,max(length(dfdx(mottlePoint)),length(dfdy(mottlePoint))));
        float mottle=poreNoise(mottlePoint+float3(13.7,5.1,9.3));
        _surface.diffuse.rgb *= 1.0+(mottle-0.5)*0.08*mottleVisibility*grainStrength;
        _surface.diffuse.rgb *= 1.0+(grain-0.5)*0.10*grainVisibility*grainStrength;
        float3 dpdx=dfdx(_surface.position),dpdy=dfdy(_surface.position);
        float3 r1=cross(dpdy,_surface.normal),r2=cross(_surface.normal,dpdx);
        float determinant=dot(dpdx,r1);
        float3 gradient=sign(determinant)*(dfdx(grain)*r1+dfdy(grain)*r2);
        _surface.normal=normalize(abs(determinant)*_surface.normal-0.0006*grainVisibility*grainStrength*gradient);
        """ }
    private let purple = material(UIColor(red: 0.16, green: 0.10, blue: 0.38, alpha: 1), roughness: 0.90)
    /// SceneKit's Metal deformers prepare source objects lazily. Keep their mutable
    /// preparation state local to each scene; immutable Data buffers remain shared.
    private static func independentSource(_ source: SCNGeometrySource) -> SCNGeometrySource {
        SCNGeometrySource(data: source.data, semantic: source.semantic, vectorCount: source.vectorCount,
                          usesFloatComponents: source.usesFloatComponents,
                          componentsPerVector: source.componentsPerVector, bytesPerComponent: source.bytesPerComponent,
                          dataOffset: source.dataOffset, dataStride: source.dataStride)
    }
    private static func independentGeometry(_ geometry: SCNGeometry) -> SCNGeometry {
        let elements = geometry.elements.map {
            SCNGeometryElement(data: $0.data, primitiveType: $0.primitiveType,
                               primitiveCount: $0.primitiveCount, bytesPerIndex: $0.bytesPerIndex)
        }
        return SCNGeometry(sources: geometry.sources.map(independentSource), elements: elements)
    }

    private func attach(_ mesh: SkinnedMesh, material: SCNMaterial, to target: SCNNode) {
        let g = Self.independentGeometry(mesh.geometry)
        g.firstMaterial = material
        let skinner = SCNSkinner(baseGeometry: g, bones: bones,
                                boneInverseBindTransforms: Self.resources.inverseBindTransforms,
                                boneWeights: Self.independentSource(mesh.weights), boneIndices: Self.independentSource(mesh.boneIndices))
        skinner.skeleton = bones[0]
        target.geometry = g; target.skinner = skinner; node.addChildNode(target)
    }
    init() {
        for (index, joint) in Self.resources.joints.enumerated() {
            let b = SCNNode()
            b.name = index == 0 ? "poulpi-head" : "poulpi-arm-\((index - 1) / 3)-joint-\((index - 1) % 3)"
            let p = joint.parent >= 0 ? Self.resources.joints[joint.parent].position : [0,0,0]
            b.position = SCNVector3(joint.position[0]-p[0], joint.position[1]-p[1], joint.position[2]-p[2])
            if joint.parent >= 0 { bones[joint.parent].addChildNode(b) } else { node.addChildNode(b) }
            bones.append(b)
        }
        let skin = Self.material(UIColor(red:0.37,green:0.32,blue:0.76,alpha:1), roughness: 0.70)
        // Rest-space grain follows the articulated skin without stretched UVs.
        // Derivative filtering removes subpixel pores in distant passes.
        skin.shaderModifiers = [.geometry: Self.grainGeometryModifier,
                                .surface: Self.grainSurfaceModifier(strength: "mix(0.70,2.10,smoothstep(0.40,0.80,in.sculptPosition.y))")
                                    .replacingOccurrences(of: "#pragma body", with: "#pragma arguments\nfloat3 poulpiPigment;\n#pragma body") + """
        float3 p=in.sculptPosition;
        float crown=smoothstep(0.25,0.80,p.y);
        _surface.diffuse.rgb *= mix(float3(0.50,1.0,1.0),float3(0.98,0.76,1.0),crown);
        float front=smoothstep(0.20,0.48,p.z);
        // Keep the middle of the face cobalt while the crown stays lavender.
        float faceTone=exp(-pow((p.y-0.43)/0.35,4.0))*front;
        _surface.diffuse.g *= 1.0-0.14*faceTone;
        // Soft blue bounce on the low curls, without brightening the ivory cups.
        float curlBounce=exp(-pow((p.y+0.72)/0.20,4.0))*front;
        _surface.emission.rgb += float3(0.0,0.028,0.16)*curlBounce;
        float mantleBounce=exp(-pow(p.y/0.22,2.0))*front;
        _surface.emission.rgb += _surface.diffuse.rgb * (0.08*mantleBounce);
        _surface.emission.rgb += float3(0.0,0.004,0.10)*mantleBounce*exp(-pow(p.x/0.45,4.0));
        // Lavender pigment follows the sculpted upper orbital cushion.
        float orbit=length(float2((abs(p.x)-0.380)/0.265,(p.y-0.44)/0.24));
        float orbitalPigment=exp(-pow((orbit-1.08)/0.12,2.0))*smoothstep(0.40,0.58,p.y)*front;
        _surface.diffuse.rgb=mix(_surface.diffuse.rgb,float3(0.25,0.15,0.65),orbitalPigment*0.70);
        float socket=length(float2((abs(p.x)-0.38)/0.265,(p.y-0.44)/0.25));
        float contact=exp(-pow((socket-1.02)/0.12,2.0))*0.12*front;
        float lipContact=exp(-pow(p.x/0.19,2.0)-pow((p.y-0.17)/0.10,2.0))*0.08*front;
        float lipUnderShadow=exp(-pow(p.x/0.16,4.0)-pow((p.y-0.035)/0.025,2.0))*0.18*front;
        _surface.diffuse.rgb *= 1.0-contact-lipContact-lipUnderShadow;
        // A broad, soft contact shadow anchors the lower lip to the mantle.
        float mouthShade=exp(-pow(p.x/0.22,4.0)-pow((p.y-0.035)/0.11,2.0))*0.24*front;
        _surface.diffuse.rgb *= 1.0-mouthShade;
        _surface.emission.rgb *= 1.0-mouthShade;
        float blush=exp(-pow((abs(p.x)-0.47)/0.105,2.0)-pow((p.y-0.155)/0.070,2.0))*front;
        _surface.diffuse.rgb=mix(_surface.diffuse.rgb,float3(0.45,0.045,0.46),blush*0.40);
        """]
        skin.shaderModifiers?[.surface]?.append("\n_surface.diffuse.rgb *= poulpiPigment;\n_surface.emission.rgb *= poulpiPigment;\n")
        skin.setValue(NSValue(scnVector3: SCNVector3(1, 1, 1)), forKey: "poulpiPigment")
        skinMaterial = skin
        attach(Self.resources.skin, material: skin, to: SCNNode())
        let cups = Self.material(UIColor(red:0.78,green:0.73,blue:0.62,alpha:1),roughness:0.52)
        cups.emission.contents = UIColor(red:0.35,green:0.30,blue:0.22,alpha:1)
        cups.shaderModifiers = [.surface: """
        #pragma body
        // Per-cup coordinates follow the skinned surface, including oval cups.
        float cupRadius=length(_surface.diffuseTexcoord*2.0-1.0);
        float recess=exp(-pow(cupRadius/0.36,2.0));
        float innerRim=exp(-pow((cupRadius-0.46)/0.10,2.0));
        float cupShade=1.0-0.04*recess-0.04*innerRim;
        _surface.diffuse.rgb *= cupShade;
        _surface.emission.rgb *= cupShade;
        _surface.emission.rgb += float3(0.035,0.017,0.0)*recess;
        _surface.roughness += 0.08*recess;
        """]
        attach(Self.resources.cups, material:cups, to:cupsNode)
        buildFace()
        bones[0].addChildNode(accessoryNode)
        node.scale = SCNVector3(0.90,1,1)
    }
    /// Palette changes touch only pigment; geometry, AO, pores, cups and the
    /// supplied iris image remain exactly the validated sculpt.
    func setAppearance(_ value: PoulpiAppearance) {
        lock.lock(); defer { lock.unlock() }
        guard value != appearance else { return }
        let previousAccessory = appearance.accessory
        appearance = value
        let rgb = value.color.pigment
        // UIColor pigment is specified in sRGB, while a physically based
        // SceneKit surface modifier receives linear light. Divide linearized
        // colors so a warm gold does not retain the original blue energy.
        let target = Self.linearPigment(rgb)
        let original = Self.linearPigment(SIMD3(0.37, 0.32, 0.76))
        let multiplier = SCNVector3(Float(target.x / original.x), Float(target.y / original.y), Float(target.z / original.z))
        skinMaterial?.setValue(NSValue(scnVector3: multiplier), forKey: "poulpiPigment")
        for (index, material) in coloredFaceMaterials.enumerated() {
            let base: SIMD3<Double> = index == 0 ? SIMD3(0.29, 0.24, 0.69) : SIMD3(0.30, 0.23, 0.70)
            material.diffuse.contents = UIColor(red: min(1, base.x * rgb.x / 0.37),
                                                green: min(1, base.y * rgb.y / 0.32),
                                                blue: min(1, base.z * rgb.z / 0.76), alpha: 1)
        }
        purple.diffuse.contents = value.color == .pink
            ? UIColor(red: 0.16, green: 0.10, blue: 0.38, alpha: 1)
            : UIColor(red: rgb.x * 0.43, green: rgb.y * 0.31, blue: rgb.z * 0.5, alpha: 1)
        if previousAccessory != value.accessory { rebuildAccessory(value.accessory) }
    }

    private static func linearPigment(_ srgb: SIMD3<Double>) -> SIMD3<Double> {
        func linear(_ channel: Double) -> Double {
            channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
        }
        return SIMD3(linear(srgb.x), linear(srgb.y), linear(srgb.z))
    }

    private func rebuildAccessory(_ accessory: PoulpiAccessory) {
        accessoryNode.childNodes.forEach { $0.removeFromParentNode() }
        let gold = Self.material(UIColor(red: 1, green: 0.72, blue: 0.16, alpha: 1), roughness: 0.30)
        gold.metalness.contents = 0.35
        let ribbon = Self.material(UIColor(red: 0.96, green: 0.31, blue: 0.39, alpha: 1), roughness: 0.65)
        switch accessory {
        case .none: break
        case .star:
            let path = UIBezierPath()
            for index in 0..<10 {
                let angle = CGFloat(index) * .pi / 5 - .pi / 2
                let radius: CGFloat = index.isMultiple(of: 2) ? 0.16 : 0.075
                let point = CGPoint(x: cos(angle) * radius, y: sin(angle) * radius)
                if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
            }
            path.close()
            let shape = SCNShape(path: path, extrusionDepth: 0.045)
            shape.chamferRadius = 0.009
            shape.firstMaterial = gold
            let star = SCNNode(geometry: shape)
            star.position = SCNVector3(0.49, 0.88, 0.46)
            star.eulerAngles = SCNVector3(0, 0.36, -0.18)
            accessoryNode.addChildNode(star)
        case .headband:
            let band = SCNTorus(ringRadius: 0.69, pipeRadius: 0.055)
            band.ringSegmentCount = 40; band.pipeSegmentCount = 8; band.firstMaterial = ribbon
            let ring = SCNNode(geometry: band)
            ring.position = SCNVector3(0, 0.84, -0.03); ring.scale = SCNVector3(1.05, 1, 0.76)
            accessoryNode.addChildNode(ring)
            let knot = SCNSphere(radius: 0.085); knot.segmentCount = 12; knot.firstMaterial = ribbon
            let knotNode = SCNNode(geometry: knot)
            knotNode.position = SCNVector3(-0.66, 0.84, 0.25)
            accessoryNode.addChildNode(knotNode)
            for side: Float in [-1, 1] {
                let tail = SCNCapsule(capRadius: 0.028, height: 0.28)
                tail.radialSegmentCount = 8; tail.firstMaterial = ribbon
                let tailNode = SCNNode(geometry: tail)
                tailNode.position = SCNVector3(-0.68 + side * 0.055, 0.73, 0.30)
                tailNode.eulerAngles.z = side * 0.35 - 0.2
                accessoryNode.addChildNode(tailNode)
            }
        case .crown:
            let band = SCNTorus(ringRadius: 0.40, pipeRadius: 0.042)
            band.ringSegmentCount = 32; band.pipeSegmentCount = 8; band.firstMaterial = gold
            let ring = SCNNode(geometry: band); ring.position = SCNVector3(0, 1.08, -0.035); ring.scale.z = 0.77
            accessoryNode.addChildNode(ring)
            for index in 0..<5 {
                let angle = Float(index) * .pi * 2 / 5
                let spike = SCNCone(topRadius: 0.016, bottomRadius: 0.10, height: 0.25)
                spike.radialSegmentCount = 4; spike.firstMaterial = gold
                let spikeNode = SCNNode(geometry: spike)
                spikeNode.position = SCNVector3(sin(angle) * 0.34, 1.18, cos(angle) * 0.27 - 0.035)
                accessoryNode.addChildNode(spikeNode)
                let gem = SCNSphere(radius: 0.037); gem.segmentCount = 8; gem.firstMaterial = gold
                let gemNode = SCNNode(geometry: gem)
                gemNode.position = SCNVector3(sin(angle) * 0.34, 1.31, cos(angle) * 0.27 - 0.035)
                accessoryNode.addChildNode(gemNode)
            }
        }
    }

    private func eyeShell(_ radius: CGFloat, _ scale: SCNVector3, _ position: SCNVector3, _ material: SCNMaterial, parent: SCNNode) -> SCNNode {
        let g = Self.eyeShellGeometry.copy() as! SCNGeometry
        g.firstMaterial = material
        let n = SCNNode(geometry: g), r = Float(radius)
        n.scale = SCNVector3(scale.x*r, scale.y*r, scale.z*r)
        n.position = position
        parent.addChildNode(n)
        return n
    }
    nonisolated(unsafe) private static let eyeShellGeometry: SCNGeometry = {
        let rows=40,columns=64
        var vertices:[SCNVector3]=[],normals:[SCNVector3]=[],indices:[UInt32]=[]
        for row in 0...rows {
            let phi=Float(row)/Float(rows) * .pi,y=cos(phi),taper=1-0.15*y
            for col in 0...columns {
                let theta=Float(col)/Float(columns)*2 * .pi
                let x=sin(phi)*cos(theta)*taper,z=sin(phi)*sin(theta)
                vertices.append(SCNVector3(x,y,z))
                let n=simd_normalize(SIMD3<Float>(x/(taper*taper),y+0.15*x*x/(taper*taper*taper),z))
                normals.append(SCNVector3(n.x,n.y,n.z))
                if row<rows && col<columns {
                    let a=UInt32(row*(columns+1)+col),b=a+1,c=a+UInt32(columns+1),d=c+1
                    indices += [a,b,c,b,d,c]
                }
            }
        }
        let g=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:normals)],elements:[PoulpiRig.triangleElement(indices)])
        return g
    }()
    /// Coordinates shared by the immutable iris mesh and its GPU deformation.
    /// Rotate on a sphere before mapping onto the tapered eye: translating a
    /// pre-curved cap would bury one edge and lift the opposite edge off the eye.
    enum EyeSurface {
        static let radius = SIMD3<Float>(0.226, 0.25764, 0.07458)
        static let relief: Float = 0.002

        static func angularScale(for pupilScale: Float) -> Float {
            // The source contains the entire iris and its catchlights, so an
            // expression may only enlarge this artwork subtly as a whole.
            max(0.97, min(1.05, 1 + (pupilScale - 1) * 0.2))
        }

        static func rotation(for gaze: SIMD2<Float>, eyeOrientation: simd_quatf) -> simd_quatf {
            let horizontal = simd_quatf(angle: gaze.x / radius.x, axis: SIMD3(0, 1, 0))
            let vertical = simd_quatf(angle: -gaze.y / radius.y, axis: SIMD3(1, 0, 0))
            // Both eyes follow the same head-space direction despite their
            // opposite mounting yaw and roll.
            return eyeOrientation.inverse * horizontal * vertical * eyeOrientation
        }

        static func direction(_ point: SIMD2<Float>, side: Float) -> SIMD3<Float> {
            let y = (point.y - 0.004) / radius.y
            let x = (point.x - side * 0.096) / (radius.x * (1 - 0.15 * y))
            return SIMD3(x, y, sqrt(max(0, 1 - x * x - y * y)))
        }

        static func projectedPoint(_ point: SIMD2<Float>, side: Float,
                                   rotation: simd_quatf, angularScale: Float) -> SIMD3<Float> {
            let center = direction(.zero, side: side)
            let source = direction(point, side: side)
            let cosine = max(-1, min(1, simd_dot(center, source)))
            let tangent = source - center * cosine
            let sine = simd_length(tangent)
            let angle = atan2(sine, cosine) * angularScale
            let expanded = simd_normalize(center * cos(angle) + tangent / max(sine, 0.000001) * sin(angle))
            let d = rotation.act(expanded)
            let taper = 1 - 0.15 * d.y
            let position = SIMD3(radius.x * d.x * taper, radius.y * d.y - 0.006, 0.012 + radius.z * d.z)
            let normal = simd_normalize(SIMD3(d.x / (radius.x * taper),
                                              (d.y + 0.15 * d.x * d.x / taper) / radius.y,
                                              d.z / radius.z))
            return position + normal * relief
        }

        static let geometryModifier = """
        #pragma arguments
        float irisSide;
        float4 irisRotation;
        float irisAngularScale;
        #pragma varyings
        float irisRadius;
        #pragma body
        float2 point = _geometry.position.xy;
        out.irisRadius = length(point / float2(0.125, 0.1625));
        float3 radii = float3(0.226, 0.25764, 0.07458);
        float cy = -0.004 / radii.y;
        float cx = -irisSide * 0.096 / (radii.x * (1.0 - 0.15 * cy));
        float3 center = float3(cx, cy, sqrt(max(0.0, 1.0 - cx*cx - cy*cy)));
        float sy = (point.y - 0.004) / radii.y;
        float sx = (point.x - irisSide * 0.096) / (radii.x * (1.0 - 0.15 * sy));
        float3 source = float3(sx, sy, sqrt(max(0.0, 1.0 - sx*sx - sy*sy)));
        float cosine = clamp(dot(center, source), -1.0, 1.0);
        float3 tangent = source - center * cosine;
        float sine = length(tangent);
        float angle = atan2(sine, cosine) * irisAngularScale;
        float3 d = normalize(center * cos(angle) + tangent / max(sine, 0.000001) * sin(angle));
        d += 2.0 * cross(irisRotation.xyz, cross(irisRotation.xyz, d) + irisRotation.w * d);
        float taper = 1.0 - 0.15 * d.y;
        float3 normal = normalize(float3(d.x / (radii.x * taper),
                                       (d.y + 0.15*d.x*d.x/taper) / radii.y,
                                       d.z / radii.z));
        _geometry.position.xyz = float3(radii.x*d.x*taper, radii.y*d.y - 0.006,
                                       0.012 + radii.z*d.z) + normal * 0.002;
        _geometry.normal = normal;
        """
    }

    private func eyeDisc(radius: Float, side: Float, material: SCNMaterial, parent: SCNNode) {
        let rings=18,columns=64
        var vertices:[SCNVector3]=[],normals:[SCNVector3]=[],indices:[UInt32]=[]
        var uv:[CGPoint]=[]
        for ring in 0...rings {
            let r=radius*max(0.00001,Float(ring)/Float(rings))
            for col in 0...columns {
                let angle=Float(col)/Float(columns)*2 * .pi
                let x=r*cos(angle),y=r*sin(angle)*1.30
                // Source coordinates remain immutable for the original UV crop.
                // The geometry modifier maps them onto the eye every frame.
                vertices.append(SCNVector3(x,y,0));normals.append(SCNVector3(0,0,1))
                let centerX:Float=side < 0 ? 491 : 759
                let centerY:Float=side < 0 ? 471 : 472
                let radiusY:Float=side < 0 ? 71 : 70
                uv.append(CGPoint(x:CGFloat((centerX+x/radius*64)/1254),
                                  y:CGFloat((centerY-y/(radius*1.30)*radiusY)/1254)))
                if ring<rings && col<columns {
                    let a=UInt32(ring*(columns+1)+col),b=a+1,c=a+UInt32(columns+1),d=c+1
                    indices += [a,c,b,b,c,d]
                }
            }
        }
        let g=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:normals),SCNGeometrySource(textureCoordinates:uv)],elements:[PoulpiRig.triangleElement(indices)])
        // SceneKit cannot infer bounds from the shader's spherical deformation.
        g.boundingBox = (SCNVector3(-0.27,-0.27,-0.08), SCNVector3(0.27,0.26,0.10))
        let eyeMaterial = material.copy() as! SCNMaterial
        eyeMaterial.setValue(NSNumber(value: side), forKey: "irisSide")
        eyeMaterial.setValue(NSValue(scnVector4: SCNVector4(0,0,0,1)), forKey: "irisRotation")
        eyeMaterial.setValue(NSNumber(value: Float(1)), forKey: "irisAngularScale")
        g.firstMaterial=eyeMaterial;parent.addChildNode(SCNNode(geometry:g))
    }
    private func buildFace() {
        let ivory = Self.material(UIColor(red: 0.685, green: 0.68, blue: 0.64, alpha: 1), roughness: 0.80)
        ivory.emission.contents = UIColor(red:0.10,green:0.09,blue:0.075,alpha:1)
        ivory.shaderModifiers = [.geometry: """
        #pragma varyings
        float eyeHeight;
        float eyeDepth;
        #pragma body
        out.eyeHeight=_geometry.position.y;
        out.eyeDepth=_geometry.position.z;
        """, .surface: """
        #pragma arguments
        float ivoryBlueFill;
        #pragma body
        float bounce=1.0-smoothstep(-0.85,0.40,in.eyeHeight);
        _surface.emission.rgb += float3(0.135,0.10,0.075)*bounce;
        _surface.emission.rgb += float3(0.09,0.04,0.08)*pow(bounce,4.0);
        // Soft ivory fill on the dome; preserve the darker contact at its edge.
        float ivoryLift=pow(max(0.0,in.eyeDepth),4.0)*bounce;
        _surface.emission.rgb += float3(0.0,0.08,ivoryBlueFill)*ivoryLift;
        float rim=(1.0-smoothstep(0.10,0.55,in.eyeDepth))*smoothstep(-0.85,-0.20,in.eyeHeight);
        float contact=1.0-0.35*rim;
        _surface.diffuse.rgb *= contact;
        _surface.emission.rgb *= contact;
        """]
        // Keep the source's indigo fibres, pupil depth and catchlights on a
        // single curved cap. Filtering remains stable during distant flights.
        let iris=SCNMaterial();iris.lightingModel = .constant
        iris.diffuse.contents=Self.referenceTexture
        // The supplied PNG has partial alpha even inside dark pupils. Iris
        // pigment is opaque; do not blend the ivory underneath into that colour.
        iris.shaderModifiers = [.geometry: EyeSurface.geometryModifier, .surface: """
        #pragma transparent
        #pragma body
        // Filter only the geometric rim; dark pigment stays fully opaque inside.
        float edgeWidth=max(0.008,fwidth(in.irisRadius));
        _surface.diffuse.a=1.0-smoothstep(1.0-edgeWidth,1.0,in.irisRadius);
        """]
        iris.diffuse.minificationFilter = .linear
        iris.diffuse.magnificationFilter = .linear
        iris.diffuse.mipFilter = .linear
        iris.diffuse.maxAnisotropy=8
        let browMaterial=Self.material(UIColor(red:0.29,green:0.24,blue:0.69,alpha:1),roughness:0.62)
        browMaterial.shaderModifiers=[.geometry:Self.grainGeometryModifier,.surface:Self.grainSurfaceModifier(strength:"0.35")]
        let lidMaterial=Self.material(UIColor(red:0.30,green:0.23,blue:0.70,alpha:1),roughness:0.70)
        lidMaterial.shaderModifiers = [.geometry: Self.lidGeometryModifier,
                                       .surface: Self.grainSurfaceModifier(strength: "0.65") + Self.lidEdgeSurfaceModifier]
        coloredFaceMaterials = [browMaterial]
        for side: Float in [-1,1] {
            let eyeRoot = SCNNode(); eyeRoot.position = SCNVector3(side * 0.380, 0.434, 0.555); bones[0].addChildNode(eyeRoot)
            eyeRoot.eulerAngles.y = side * 0.20
            eyeRoot.eulerAngles.z = -side * 0.10
            eyeRoot.scale = SCNVector3(1.12,0.88,1)
            _ = eyeShell(0.231, SCNVector3(1,1.14,0.23), SCNVector3(0,-0.006,0), purple, parent: eyeRoot)
            let eyeIvory = ivory.copy() as! SCNMaterial
            eyeIvory.setValue(NSNumber(value:side < 0 ? 0.08 : -0.08),forKey:"ivoryBlueFill")
            if side > 0 { eyeIvory.diffuse.contents = UIColor(red:0.71,green:0.66,blue:0.57,alpha:1) }
            _ = eyeShell(0.226, SCNVector3(1,1.14,0.33), SCNVector3(0,-0.006,0.012), eyeIvory, parent: eyeRoot)
            let gaze = SCNNode(); gaze.name = side < 0 ? "poulpi-pupil-left" : "poulpi-pupil-right"
            eyeRoot.addChildNode(gaze); pupils.append(gaze)
            eyeDisc(radius:0.125,side:side,material:iris,parent:gaze)
            let lid = SCNNode(geometry: Self.independentGeometry(Self.openLid))
            lid.name = side < 0 ? "poulpi-lids-left" : "poulpi-lids-right"
            let eyeLidMaterial = lidMaterial.copy() as! SCNMaterial
            eyeLidMaterial.setValue(NSNumber(value: Float(0)), forKey: "lidClosure")
            lid.geometry?.firstMaterial = eyeLidMaterial
            lidMaterials.append(eyeLidMaterial)
            coloredFaceMaterials.append(eyeLidMaterial)
            let morph = SCNMorpher()
            morph.targets = Self.lidTargets.map(Self.independentGeometry)
            morph.calculationMode = .normalized
            lid.morpher = morph
            eyeRoot.addChildNode(lid)
            eyelids.append(morph)
            let brow = tube(points: (0...48).map { step in
                let t=Float(step)/48
                return SCNVector3(-0.138+t*0.276, 0.014*sin(t * .pi), 0)
            }, radius: 0.046, material: browMaterial, radiusScale: { t in
                let inward = side < 0 ? t : 1-t
                let blend = inward*inward*(3-2*inward)
                return 0.92+0.23*blend
            })
            brow.name = side < 0 ? "poulpi-brow-left" : "poulpi-brow-right"
            brow.position = SCNVector3(side*0.375,0.77,0.435); brow.eulerAngles.z = -side*0.34; brow.eulerAngles.y = side*0.35
            bones[0].addChildNode(brow); brows.append(brow)
        }
        // A rounded, heart-shaped lip volume; the smile crease sits inside it.
        let orange=SCNMaterial();orange.lightingModel = .constant
        orange.diffuse.contents=Self.referenceTexture
        orange.diffuse.minificationFilter = .linear
        orange.diffuse.magnificationFilter = .linear
        orange.diffuse.mipFilter = .linear
        orange.diffuse.maxAnisotropy=8
        orange.shaderModifiers=[.geometry: """
        #pragma varyings
        float2 mouthPoint;
        #pragma body
        out.mouthPoint = _geometry.position.xy;
        """, .surface: """
        #pragma arguments
        float mouthOpen;
        float mouthRound;
        float mouthSmile;
        #pragma transparent
        #pragma body
        float width = mix(0.105, 0.065, mouthRound);
        float height = 0.065 * mouthOpen;
        float smileCurve = mouthSmile * 0.022 * pow(in.mouthPoint.x / 0.17, 2.0);
        float2 p = float2(in.mouthPoint.x / width, (in.mouthPoint.y + 0.010 - smileCurve) / max(height, 0.001));
        float edge = length(p);
        float softness = max(0.025, fwidth(edge) * 1.5);
        float aperture = smoothstep(0.015, 0.08, mouthOpen);
        _surface.diffuse.a = 1.0 - aperture * (1.0 - smoothstep(1.0-softness, 1.0+softness, edge));
        """]
        orange.setValue(NSNumber(value: Float(0)), forKey: "mouthOpen")
        orange.setValue(NSNumber(value: Float(0)), forKey: "mouthRound")
        orange.setValue(NSNumber(value: Float(0)), forKey: "mouthSmile")
        mouthMaterial = orange
        let cavityMaterial = Self.material(UIColor(red: 0.14, green: 0.055, blue: 0.18, alpha: 1), roughness: 0.9)
        cavityMaterial.lightingModel = .constant
        let cavity = SCNSphere(radius: 1)
        cavity.segmentCount = 32
        cavity.firstMaterial = cavityMaterial
        mouthCavity.name = "poulpi-mouth-cavity"
        mouthCavity.geometry = cavity
        mouthCavity.position = SCNVector3(0, -0.010, 0.022)
        mouthCavity.scale = SCNVector3(0.10, 0.001, 0.012)
        mouthCavity.isHidden = true
        mouth.addChildNode(mouthCavity)
        let lips=SCNNode(geometry:Self.resources.mouth)
        lips.geometry = lips.geometry?.copy() as? SCNGeometry
        lips.geometry?.firstMaterial=orange; lips.scale=SCNVector3(1.05,1.158,1); mouth.addChildNode(lips)
        mouth.name = "poulpi-mouth"
        mouth.position = SCNVector3(-0.0033,0.179,0.601); bones[0].addChildNode(mouth)
    }
    // The two membranes share fixed corners and converge on the same curved
    // edge. A closed eye therefore has one real seam, not a painted line above
    // a second, still-open boundary. Both membranes follow the ivory surface.
    nonisolated(unsafe) private static let openLid = lidGeometry(closure: 0)
    nonisolated(unsafe) private static let lidTargets = (1...PoulpiEyelidWeights.targetCount).map {
        lidGeometry(closure: Float($0) / Float(PoulpiEyelidWeights.targetCount))
    }
    private static let lidGeometryModifier = """
        #pragma arguments
        float lidClosure;
        #pragma varyings
        float3 sculptPosition;
        float lidEdgeDistance;
        #pragma body
        out.sculptPosition = _geometry.position.xyz;
        float u = _geometry.texcoords[0].x;
        float span = max(0.001, acos(clamp(1.0 - lidClosure, 0.0, 1.0)));
        out.lidEdgeDistance = _geometry.texcoords[0].y * span * 0.16 * sqrt(max(0.0, 1.0-u*u));
        """
    private static let lidEdgeSurfaceModifier = """

        // Pigment follows the actual free edge of each membrane. At complete
        // closure both edges coincide, so no independent floating crease exists.
        float edgeWidth = max(0.0022, fwidth(in.lidEdgeDistance));
        float edgePigment = 1.0 - smoothstep(0.0, edgeWidth, in.lidEdgeDistance);
        _surface.diffuse.rgb *= 1.0 - 0.24 * edgePigment;
        """

    private static func lidGeometry(closure: Float) -> SCNGeometry {
        let rows = 24, columns = 64
        let radius = EyeSurface.radius
        var vertices: [SCNVector3] = [], normals: [SCNVector3] = []
        var uv: [CGPoint] = [], indices: [UInt32] = []
        for lower in [false, true] {
            let offset = UInt32(vertices.count)
            for row in 0...rows {
                let progress = Float(row) / Float(rows)
                for col in 0...columns {
                    // Cosine spacing gives smooth corners without narrow slivers
                    // from a uniformly spaced horizontal grid.
                    let u = -cos(Float(col) / Float(columns) * .pi)
                    let span = sqrt(max(0, 1 - u * u))
                    let meetingHeight = -0.019 / radius.y * span
                    let openHeight: Float = lower ? -0.99998 : 0.99998
                    let edgeHeight = openHeight + (meetingHeight - openHeight) * closure
                    let edgeAngle = acos(max(-1, min(1, edgeHeight)))
                    let theta = lower ? edgeAngle + (.pi - edgeAngle) * progress : edgeAngle * progress
                    let direction = SIMD3<Float>(u, span * cos(theta), span * sin(theta))
                    let taper = 1 - 0.15 * direction.y
                    let normal = simd_normalize(SIMD3<Float>(
                        direction.x / (radius.x * taper),
                        (direction.y + 0.15 * direction.x * direction.x / taper) / radius.y,
                        direction.z / radius.z
                    ))
                    let surface = SIMD3<Float>(radius.x * direction.x * taper,
                                               radius.y * direction.y - 0.006,
                                               0.012 + radius.z * direction.z)
                    // Thin skin follows the eye; it does not inflate into a
                    // larger enclosing globe as the old upper-only cap did.
                    let point = surface + normal * 0.0045
                    vertices.append(SCNVector3(point.x, point.y, point.z))
                    normals.append(SCNVector3(normal.x, normal.y, normal.z))
                    uv.append(CGPoint(x: CGFloat(u), y: CGFloat(lower ? progress : 1 - progress)))
                    if row < rows && col < columns {
                        let a = offset + UInt32(row * (columns + 1) + col)
                        let b = a + 1, c = a + UInt32(columns + 1), d = c + 1
                        indices += [a, c, b, b, c, d]
                    }
                }
            }
        }
        return SCNGeometry(sources: [SCNGeometrySource(vertices: vertices),
                                    SCNGeometrySource(normals: normals),
                                    SCNGeometrySource(textureCoordinates: uv)],
                           elements: [triangleElement(indices)])
    }

    // A single closed lip cushion, with the smile pressed into the surface.
    // Immutable geometry is cached; expression scaling still costs one transform.
    private static func mouthGeometry(_ mesh: Surface) -> SCNGeometry {
        return SCNGeometry(sources:[
            source(mesh.positions,semantic:.vertex,count:mesh.positions.count/3,components:3,floating:true),
            source(mesh.normals,semantic:.normal,count:mesh.normals.count/3,components:3,floating:true),
            source(mesh.textureCoordinates,semantic:.texcoord,count:mesh.textureCoordinates.count/2,components:2,floating:true)
        ],elements:[triangleElement(mesh.indices)])
    }

    /// Smooth variable-radius tubes for eyebrow ridges.
    private func tube(points: [SCNVector3], radius: Float, material: SCNMaterial, radiusScale: ((Float) -> Float)? = nil) -> SCNNode {
        let sides=24
        var vertices:[SCNVector3]=[], normals:[SCNVector3]=[], indices:[UInt32]=[]
        var arc=[Float](repeating:0,count:points.count)
        for i in 1..<points.count {
            let a=points[i-1],b=points[i]
            arc[i]=arc[i-1]+simd_length(SIMD3<Float>(b.x-a.x,b.y-a.y,b.z-a.z))
        }
        for i in points.indices {
            let p=SIMD3<Float>(points[i].x,points[i].y,points[i].z)
            let a=points[max(0,i-1)], b=points[min(points.count-1,i+1)]
            let tangent=simd_normalize(SIMD3<Float>(b.x-a.x,b.y-a.y,b.z-a.z))
            let across=simd_normalize(simd_cross(tangent,SIMD3<Float>(0,0,1)))
            let depth=simd_cross(tangent,across)
            let localRadius=radius*(radiusScale?(arc[i]/max(arc[points.count-1],0.00001)) ?? 1)
            let endDistance=min(arc[i],arc[points.count-1]-arc[i])
            let taper=max(0.001,sqrt(max(0,1-pow(1-min(1,endDistance/localRadius),2))))
            for j in 0..<sides {
                let angle=Float(j)/Float(sides)*2 * Float.pi
                let n=across*cos(angle)+depth*sin(angle), v=p+n*localRadius*taper
                vertices.append(SCNVector3(v.x,v.y,v.z));normals.append(SCNVector3(n.x,n.y,n.z))
                if i<points.count-1 {
                    let a=UInt32(i*sides+j), b=UInt32(i*sides+(j+1)%sides), c=a+UInt32(sides), d=b+UInt32(sides)
                    indices += [a,b,c,b,d,c]
                }
            }
        }
        for end in [0,points.count-1] {
            let center=UInt32(vertices.count)
            vertices.append(points[end]); normals.append(SCNVector3(0,0,end==0 ? -1:1))
            for j in 0..<sides {
                let a=UInt32(end*sides+j), b=UInt32(end*sides+(j+1)%sides)
                indices += end==0 ? [center,b,a] : [center,a,b]
            }
        }
        // Area-weighted surface normals follow the rounded end caps too.
        var accumulated=Array(repeating:SIMD3<Float>.zero,count:vertices.count)
        func vector(_ index:Int) -> SIMD3<Float> {
            let v=vertices[index]; return SIMD3<Float>(v.x,v.y,v.z)
        }
        for triangle in stride(from:0,to:indices.count,by:3) {
            let a=Int(indices[triangle]),b=Int(indices[triangle+1]),c=Int(indices[triangle+2])
            let normal=simd_cross(vector(b)-vector(a),vector(c)-vector(a))
            accumulated[a] += normal; accumulated[b] += normal; accumulated[c] += normal
        }
        for i in normals.indices where simd_length_squared(accumulated[i])>1e-24 {
            let n=simd_normalize(accumulated[i]);normals[i]=SCNVector3(n.x,n.y,n.z)
        }
        let g=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:normals)],elements:[PoulpiRig.triangleElement(indices)])
        g.firstMaterial=material
        return SCNNode(geometry:g)
    }

    #if DEBUG
    /// Drives the real closure path for deterministic front/profile rendering checks.
    func setInspectionEyelids(_ closure: Float) {
        lock.lock(); defer { lock.unlock() }
        for index in 0..<2 { closeEyelid(closure, index: index) }
    }
    #endif

    private func closeEyelid(_ amount: Float, index: Int) {
        let closure=max(0,min(1,amount))
        guard abs(closure-eyelidClosure[index])>0.0001 else { return }
        eyelidClosure[index]=closure
        lidMaterials[index].setValue(NSNumber(value: closure), forKey: "lidClosure")
        let morpher = eyelids[index]
        eyelidWeights[index].update(closure: closure) { target, weight in
            morpher.setWeight(CGFloat(weight), forTargetAt: target)
        }
    }

    private func applyFace(_ face: FacePose) {
        let old = lastFace
        for index in 0..<2 where old?.lids[index] != face.lids[index] {
            closeEyelid(face.lids[index], index: index)
        }
        if old?.gaze != face.gaze || old?.pupilScale != face.pupilScale {
            for pupil in pupils {
                guard let eye = pupil.parent, let material = pupil.childNodes.first?.geometry?.firstMaterial else { continue }
                let rotation = EyeSurface.rotation(for: face.gaze, eyeOrientation: eye.simdOrientation).vector
                material.setValue(NSValue(scnVector4: SCNVector4(rotation.x, rotation.y, rotation.z, rotation.w)), forKey: "irisRotation")
                material.setValue(NSNumber(value: EyeSurface.angularScale(for: face.pupilScale)), forKey: "irisAngularScale")
            }
        }
        if old?.brows != face.brows {
            for (index, brow) in brows.enumerated() {
                let side: Float = index == 0 ? -1 : 1
                let lift = face.brows[index]
                brow.position = SCNVector3(side * 0.375, 0.77 + lift, 0.435 - max(0, lift) * 0.18)
                brow.eulerAngles.z = -side * (0.34 + lift * 1.6)
            }
        }
        if old?.opening != face.opening || old?.roundness != face.roundness || old?.smile != face.smile {
            mouthMaterial?.setValue(NSNumber(value: face.opening), forKey: "mouthOpen")
            mouthMaterial?.setValue(NSNumber(value: face.roundness), forKey: "mouthRound")
            mouthMaterial?.setValue(NSNumber(value: face.smile), forKey: "mouthSmile")
            mouthCavity.isHidden = face.opening < 0.015
            mouthCavity.scale = SCNVector3(0.106 - face.roundness * 0.038,
                                           max(0.001, face.opening * 0.063), 0.012)
            mouth.scale = SCNVector3(1 + face.smile * 0.09 - face.roundness * 0.08,
                                     1 + face.opening * 0.07, 1)
        }
        if old?.headTilt != face.headTilt {
            bones[0].simdOrientation = simd_quatf(angle: face.headTilt, axis: SIMD3(0, 0, 1))
        }
        lastFace = face
    }

    func play(_ mood: LisaMascotMood, animated: Bool) {
        #if DEBUG
        let animated = animated && !(ProcessInfo.processInfo.arguments.contains("--octopus-preview") && ProcessInfo.processInfo.arguments.contains("--octopus-still"))
        #endif
        lock.lock(); defer { lock.unlock() }
        transitionFace = animated ? lastExpressionFace : nil
        self.mood = mood; reactionElapsed = 0
        if !animated {
            // Static poses write these nodes directly; the next animated frame
            // must restore every channel, even when its cached value matches.
            lastBodyScale = nil; lastFace = nil
            node.removeAction(forKey:"rig")
            swimWeight = 0
            animationClock = PoulpiAnimationClock()
            bends = Array(repeating: 0, count: 24)
            twists = Array(repeating: 0, count: 24)
            for b in bones { b.eulerAngles = SCNVector3Zero }
            lastJointOrientations = Array(repeating: nil, count: 24)
            bones[0].scale=SCNVector3(1,1,1)
            let expression = Self.expression(for: mood)
            lastExpressionFace = expression
            applyFace(expression)
            return
        }
        guard node.action(forKey:"rig") == nil else { return }
        node.runAction(.repeatForever(.customAction(duration:24) { [weak self] _,time in self?.animate(time) }),forKey:"rig")
    }

    private struct ReactionEnvelope {
        let anticipation: Float
        let accent: Float
        let settle: Float
    }

    private static func envelope(elapsed: Float, duration: Float) -> ReactionEnvelope {
        let phase = max(0, min(1, elapsed / max(duration, 0.1)))
        let anticipation = phase < 0.18 ? sin(phase / 0.18 * .pi) : 0
        let accentPhase = max(0, min(1, (phase - 0.14) / 0.66))
        let accent = sin(accentPhase * .pi)
        let settle = phase > 0.58 ? sin((phase - 0.58) * 12) * exp(-(phase - 0.58) * 8) : 0
        return ReactionEnvelope(anticipation: anticipation, accent: accent, settle: settle)
    }

    private static func animatedFace(_ mood: LisaMascotMood, time: Float, reactionPhase: Float, envelope: ReactionEnvelope) -> FacePose {
        var face = expression(for: mood)
        let strength = 0.65 + envelope.accent * 0.45 - envelope.anticipation * 0.12 + envelope.settle * 0.06
        face.lids *= strength
        if mood == .sleepy { face.lids = simd_max(face.lids, SIMD2(repeating: 0.84)) }
        face.brows *= strength
        face.smile *= strength
        face.opening = max(0, min(1, face.opening * strength))
        face.headTilt = face.headTilt * strength + sin(time * 2.2) * face.armEnergy * 0.07
        face.gaze += SIMD2(sin(time * 0.9) * 0.008, cos(time * 1.3) * 0.006)
        switch mood {
        case .giggle, .celebrating:
            let laugh = sin(reactionPhase * 2 * .pi * mood.laughCycles)
            face.opening *= 0.67 + 0.33 * laugh * laugh
            face.brows += SIMD2(repeating: laugh * 0.008)
        case .sleepy:
            face.opening = max(face.opening, 0.48 * envelope.accent)
            face.roundness = 0.9
        case .nervous:
            let tremor = reactionPhase * 2 * .pi
            face.gaze += SIMD2(sin(tremor * 5) * 0.007, cos(tremor * 6) * 0.005)
        case .dizzy:
            let rotation = reactionPhase * 2 * .pi * 3
            face.gaze += SIMD2(cos(rotation), sin(rotation)) * 0.020
        default: break
        }
        if mood == .peek || mood == .encouraging || mood == .moonwalk {
            face.lids.x = max(face.lids.x, min(1, envelope.accent * 1.08))
        }
        if mood == .sneeze {
            let impulse = PoulpiAnimationTiming.sneezeImpulse(phase: reactionPhase)
            let closing = max(impulse, PoulpiAnimationTiming.sneezeImpulse(phase: reactionPhase + 0.04))
            face.lids = simd_max(face.lids, SIMD2(repeating: closing))
            face.opening = max(face.opening, impulse * 0.7)
        }
        return face
    }

    private static func blend(_ source: FacePose, _ target: FacePose, progress: Float) -> FacePose {
        let t = max(0, min(1, progress))
        let eased = t * t * (3 - 2 * t)
        func mix(_ a: Float, _ b: Float) -> Float { a + (b - a) * eased }
        return FacePose(
            lids: source.lids + (target.lids - source.lids) * eased,
            gaze: source.gaze + (target.gaze - source.gaze) * eased,
            brows: source.brows + (target.brows - source.brows) * eased,
            smile: mix(source.smile, target.smile),
            opening: mix(source.opening, target.opening),
            roundness: mix(source.roundness, target.roundness),
            pupilScale: mix(source.pupilScale, target.pupilScale),
            headTilt: mix(source.headTilt, target.headTilt),
            armEnergy: mix(source.armEnergy, target.armEnergy)
        )
    }

    /// Distinct, bounded poses blend into the swim instead of replacing it.
    private func armGesture(_ mood: LisaMascotMood, arm: Int, joint: Int, time: Float, reactionPhase: Float) -> (bend: Float, twist: Float) {
        let tip = Float(joint) / 2
        let side: Float = arm < 4 ? 1 : -1
        let front = arm == 0 || arm == 7
        let wave = sin(time * 5 - Float(joint) * 0.6 + Float(arm) * 0.8)
        switch mood {
        case .idle, .sleepy: return (0, 0)
        case .surprised:
            return (-0.30 - tip * 0.12 + wave * 0.06, side * 0.12)
        case .nervous:
            let tremor = sin(time * 17 + Float(arm) * 1.7 + Float(joint))
            return (tremor * 0.12, tremor * side * 0.10)
        case .confused:
            return arm == 1 ? (-0.32 - tip * 0.10, side * 0.10) : (-0.03, 0)
        case .loved:
            return front ? (-0.24 - tip * 0.08 + wave * 0.05, side * 0.08) : (-0.02, 0)
        case .proud:
            return (arm == 1 ? -0.32 : 0.20 + tip * 0.08, arm == 1 ? -0.18 : 0)
        case .happy, .encouraging:
            return arm == 1 ? (-0.20 - tip * 0.16 + wave * 0.12, sin(time * 6) * 0.18 * (1-tip)) : (0, 0)
        case .thinking, .curious:
            return front ? (-0.18 - tip * 0.14, side * 0.10) : (-0.04, 0)
        case .celebrating, .giggle:
            let laughPhase = reactionPhase * 2 * .pi * mood.laughCycles
            return (0.18 + sin(laughPhase - Float(joint) * 0.6) * (0.20 + tip * 0.10), side * sin(laughPhase) * 0.12)
        case .peek, .cloudHide:
            return (front ? -0.32 - tip * 0.18 : 0.18, front ? side * 0.12 : 0)
        case .swim, .chase, .rocket:
            return (sin(time * .pi - Float(joint) * 0.5) * 0.18, 0)
        case .moonwalk:
            return (sin(time * 5 + Float(arm) * .pi / 2 - Float(joint)) * 0.25, side * wave * 0.08)
        case .juggle:
            return (front ? -0.18 + sin(time * 5 + side * .pi / 2) * 0.22 : -0.08, front ? side * 0.12 : 0)
        case .sneeze:
            return (PoulpiAnimationTiming.sneezeImpulse(phase: reactionPhase) * 0.40, 0)
        case .tumble, .pirouette:
            return (0.30 + tip * 0.12, side * 0.10)
        case .balance, .dizzy, .wobble:
            return (side * sin(time * 4) * (0.16 + tip * 0.10), side * 0.12)
        case .superhero:
            return (arm == 0 ? -0.32 : 0.24 + tip * 0.1, arm == 0 ? -0.20 : 0)
        case .jelly:
            return (wave * (0.16 + tip * 0.12), wave * 0.10)
        case .bow:
            return (-0.18 - tip * 0.10, side * 0.08)
        }
    }
    func animate(_ time: CGFloat) {
        lock.lock(); defer { lock.unlock() }
        let mood = self.mood, swimming = self.swimming
        let elapsed = Float(animationClock.advance(actionTime: Double(time)))
        reactionElapsed += elapsed
        let reactionElapsed = self.reactionElapsed
        // Only radian oscillators share 20π. Blink and stroke use their own
        // periods from the continuous clock, including across action restarts.
        let t = Float(animationClock.totalTime.truncatingRemainder(dividingBy: 20 * .pi))
        let cycle = Float(time) * .pi/12
        let reactionPhase = PoulpiAnimationTiming.reactionPhase(elapsed: Double(reactionElapsed), duration: mood.reactionDuration)
        let envelope = Self.envelope(elapsed: reactionElapsed, duration: Float(mood.reactionDuration))
        let targetFace = Self.animatedFace(mood, time: t, reactionPhase: reactionPhase, envelope: envelope)
        var face = transitionFace.map { Self.blend($0, targetFace, progress: reactionElapsed / 0.22) } ?? targetFace
        lastExpressionFace = face
        // The current blink wins over expression interpolation so the actual
        // lids reach full closure, then reopen without a captured blink tail.
        face.lids = simd_max(face.lids, SIMD2(repeating: PoulpiAnimationTiming.blink(at: animationClock.totalTime)))
        if let forced = Self.inspectionBlink { face.lids = SIMD2(repeating: forced) }
        if reactionElapsed >= 0.22 { transitionFace = nil }
        let blend = PoulpiAnimationTiming.smoothing(elapsed: Double(elapsed))
        swimWeight += ((swimming == nil ? 0 : 1) - swimWeight) * blend
        let stroke = Float(swimming?.phase ?? animationClock.totalTime.truncatingRemainder(dividingBy: 2) * .pi)
        let effort = Float(swimming?.effort ?? 0)
        let braking = Float(swimming?.braking ?? 0)
        let turn = Float(swimming?.turn ?? 0)
        let localReactionTime = min(reactionElapsed, Float(mood.reactionDuration))
        let gestureTime = swimming != nil && (mood == .swim || mood == .chase || mood == .rocket)
            ? stroke / .pi : localReactionTime
        for i in 0..<8 {
            let angle = Self.armAngles[i]
            let steering = turn * Self.armSines[i]
            let baseTwist = sin(cycle * 6 + angle) * 0.035 + swimWeight * turn * 0.10
            for j in 0..<3 {
                let joint = Float(j)
                let idle = sin(cycle * Float(mood == .sleepy ? 3 : 6+i%3) + angle - joint * 0.55) * (0.07 + joint * 0.045) * (mood == .sleepy ? 0.45 : 1)
                // A wave travels from the base to each tip, with a slight arm lag.
                // Recovery opens the arms; the power stroke curls them together.
                let lag = joint * 0.48 + Float(i % 2) * 0.16
                let power = sin(stroke - lag)
                let paddle = (0.08 + power * (0.22 + joint * 0.085)) * (0.45 + effort * 0.55)
                let fan = -braking * (0.14 + joint * 0.04)
                let jointSteering = steering * (0.15 + joint * 0.04)
                let gesture = mood == .idle || mood == .sleepy
                    ? (bend: Float(0), twist: Float(0))
                    : armGesture(mood, arm: i, joint: j, time: gestureTime, reactionPhase: reactionPhase)
                let sharedGesture = sin(localReactionTime * 4.4 - Float(i) * 0.45 - joint * 0.5)
                    * face.armEnergy * (0.35 + joint * 0.18)
                let anticipation = -envelope.anticipation * face.armEnergy * (0.34 + joint * 0.12)
                let accent = envelope.accent * sharedGesture
                let gestureWeight: Float = mood.isAcrobatic ? max(0, envelope.accent) : 1
                let target = idle * (1 - swimWeight * 0.7) + swimWeight * (paddle + fan + jointSteering)
                    + gesture.bend * gestureWeight + sharedGesture * 0.35 + anticipation + accent
                let index = i * 3 + j
                bends[index] += (target - bends[index]) * blend
                let twist = (j == 0 ? baseTwist : 0) + gesture.twist * gestureWeight
                twists[index] += (twist - twists[index]) * blend
                // Compose rotations once: do not mix Euler writes with axis-angle.
                let curl = simd_quatf(angle: bends[index], axis: Self.curlAxes[i])
                let sweep = simd_quatf(angle: twists[index], axis: SIMD3(0, 1, 0))
                let orientation = sweep * curl
                if lastJointOrientations[index]?.vector != orientation.vector {
                    bones[1+index].simdOrientation = orientation
                    lastJointOrientations[index] = orientation
                }
            }
        }
        let breath = (mood == .sleepy ? Float(0.025) : 0.012) * sin(cycle * (mood == .sleepy ? 3 : 6))
        let contraction = swimWeight * Float(swimming?.propulsion ?? 0) * 0.045
        let recoil = (envelope.accent - envelope.anticipation * 0.7 + envelope.settle * 0.2) * face.armEnergy * 0.08
        let bodyScale = SIMD3<Float>(1 + breath - contraction + recoil,
                                     1 + (mood == .sleepy ? breath * 1.2 : 0.015 * sin(cycle * 6)) + contraction * 0.7 - recoil * 0.7,
                                     1 + breath - contraction + recoil)
        if lastBodyScale != bodyScale {
            bones[0].scale = SCNVector3(bodyScale.x, bodyScale.y, bodyScale.z)
            lastBodyScale = bodyScale
        }
        applyFace(face)
    }
}
