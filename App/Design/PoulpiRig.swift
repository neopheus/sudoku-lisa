import SceneKit
import UIKit
import SudokuCore

/// A welded sculpt with 24 arm joints. Skin and cups share the same GPU skinning.
final class PoulpiRig: @unchecked Sendable {
    let node = SCNNode()
    private let lock = NSLock()
    private var mood: LisaMascotMood = .idle
    private var activity: Float = 0
    private var swimming: CompanionFlight.SwimPose?
    private var swimWeight: Float = 0
    private var bends = Array(repeating: Float(0), count: 24)
    private var twists = Array(repeating: Float(0), count: 24)

    func setSwimming(_ pose: CompanionFlight.SwimPose?) {
        lock.lock(); swimming = pose; lock.unlock()
    }
    private var previousTime: CGFloat = 0
    private var bones: [SCNNode] = []
    private var pupils: [SCNNode] = []
    private var brows: [SCNNode] = []
    private var eyelids: [SCNMorpher] = []
    private var lidCreases: [SCNNode] = []
    private var eyelidClosure: Float = -1
    private let mouth = SCNNode()
    private let cupsNode = SCNNode()

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
    }
    private struct Surface: Decodable { let positions: [Float], normals: [Float], textureCoordinates: [Float]; let indices: [UInt32] }
    private struct Joint: Decodable { let parent: Int; let position: [Float] }
    private struct Asset: Decodable { let version: Int; let joints: [Joint]; let skin: Mesh; let cups: Mesh; let mouth: Surface }
    private static let asset: Asset = {
        guard let url = Bundle.main.url(forResource: "poulpi-rig", withExtension: "json"),
              let data = try? Data(contentsOf: url), let result = try? JSONDecoder().decode(Asset.self, from: data), result.version == 1 else {
            preconditionFailure("Missing validated Poulpi sculpt")
        }
        return result
    }()
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
            uv += [atan2(x,z)/(2 * .pi)+0.5, y*0.5+0.5]
        }
        return SCNGeometry(sources: [source(uv, semantic: .texcoord, count: uv.count/2, components: 2, floating: true), source(colors, semantic: .color, count: colors.count/4, components: 4, floating: true), source(mesh.positions, semantic: .vertex, count: mesh.positions.count / 3, components: 3, floating: true),
                              source(mesh.normals, semantic: .normal, count: mesh.normals.count / 3, components: 3, floating: true)],
                    elements: [SCNGeometryElement(indices: mesh.indices, primitiveType: .triangles)])
    }
    // Immutable prototypes: each instance copies them before assigning materials.
    nonisolated(unsafe) private static let skinGeometry = geometry(asset.skin)
    nonisolated(unsafe) private static let cupGeometry = geometry(asset.cups, tint: false)
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
    private func attach(_ mesh: Mesh, geometry: SCNGeometry, material: SCNMaterial, to target: SCNNode) {
        let g = geometry.copy() as! SCNGeometry; g.firstMaterial = material
        let inverse = Self.asset.joints.map { joint -> NSValue in
            NSValue(scnMatrix4: SCNMatrix4MakeTranslation(-joint.position[0], -joint.position[1], -joint.position[2]))
        }
        let skinner = SCNSkinner(baseGeometry: g, bones: bones, boneInverseBindTransforms: inverse,
                                boneWeights: Self.source(mesh.weights, semantic: .boneWeights, count: mesh.weights.count/4, components: 4, floating: true),
                                boneIndices: Self.source(mesh.bones, semantic: .boneIndices, count: mesh.bones.count/4, components: 4, floating: false))
        skinner.skeleton = bones[0]
        target.geometry = g; target.skinner = skinner; node.addChildNode(target)
    }
    init() {
        for joint in Self.asset.joints {
            let b = SCNNode()
            let p = joint.parent >= 0 ? Self.asset.joints[joint.parent].position : [0,0,0]
            b.position = SCNVector3(joint.position[0]-p[0], joint.position[1]-p[1], joint.position[2]-p[2])
            if joint.parent >= 0 { bones[joint.parent].addChildNode(b) } else { node.addChildNode(b) }
            bones.append(b)
        }
        let skin = Self.material(UIColor(red:0.37,green:0.32,blue:0.76,alpha:1), roughness: 0.70)
        // Rest-space grain follows the articulated skin without stretched UVs.
        // Derivative filtering removes subpixel pores in distant passes.
        skin.shaderModifiers = [.geometry: Self.grainGeometryModifier,
                                .surface: Self.grainSurfaceModifier(strength: "mix(0.70,2.10,smoothstep(0.40,0.80,in.sculptPosition.y))") + """
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
        _surface.emission.rgb += _surface.diffuse.rgb * (0.16*mantleBounce);
        _surface.emission.rgb += float3(0.0,0.007,0.20)*mantleBounce*exp(-pow(p.x/0.45,4.0));
        // Lavender pigment follows the sculpted upper orbital cushion.
        float orbit=length(float2((abs(p.x)-0.380)/0.265,(p.y-0.44)/0.24));
        float orbitalPigment=exp(-pow((orbit-1.08)/0.12,2.0))*smoothstep(0.40,0.58,p.y)*front;
        _surface.diffuse.rgb=mix(_surface.diffuse.rgb,float3(0.25,0.15,0.65),orbitalPigment*0.45);
        float socket=length(float2((abs(p.x)-0.38)/0.265,(p.y-0.44)/0.25));
        float contact=exp(-pow((socket-1.02)/0.12,2.0))*0.12*front;
        float lipContact=exp(-pow(p.x/0.19,2.0)-pow((p.y-0.17)/0.10,2.0))*0.08*front;
        float lipUnderShadow=exp(-pow(p.x/0.16,4.0)-pow((p.y-0.035)/0.025,2.0))*0.18*front;
        _surface.diffuse.rgb *= 1.0-contact-lipContact-lipUnderShadow;
        // A broad, soft contact shadow anchors the lower lip to the mantle.
        float mouthShade=exp(-pow(p.x/0.22,4.0)-pow((p.y-0.035)/0.11,2.0))*0.24*front;
        _surface.diffuse.rgb *= 1.0-mouthShade;
        _surface.emission.rgb *= 1.0-mouthShade;
        float blush=exp(-pow((abs(p.x)-0.47)/0.13,2.0)-pow((p.y-0.18)/0.095,2.0))*front;
        _surface.diffuse.rgb=mix(_surface.diffuse.rgb,float3(0.45,0.045,0.46),blush*0.50);
        """]
        attach(Self.asset.skin, geometry: Self.skinGeometry, material: skin, to: SCNNode())
        let cups = Self.material(UIColor(red:0.76,green:0.69,blue:0.53,alpha:1),roughness:0.76)
        cups.emission.contents = UIColor(red:0.50,green:0.40,blue:0.24,alpha:1)
        attach(Self.asset.cups, geometry:Self.cupGeometry, material:cups, to:cupsNode)
        buildFace()
        node.scale = SCNVector3(0.90,1,1)
    }
    private func eyeShell(_ radius: CGFloat, _ scale: SCNVector3, _ position: SCNVector3, _ material: SCNMaterial, parent: SCNNode) -> SCNNode {
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
        let g=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:normals)],elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)])
        g.firstMaterial=material
        let n=SCNNode(geometry:g);let r=Float(radius)
        n.scale=SCNVector3(scale.x*r,scale.y*r,scale.z*r);n.position=position;parent.addChildNode(n)
        return n
    }
    /// Iris and pupil follow the ivory shell instead of intersecting it as
    /// flattened spheres. Their small relief also fits inside the closing lid.
    private func eyeDisc(radius:Float, side:Float, lift:Float, material:SCNMaterial, parent:SCNNode) {
        let rings=18,columns=64
        var vertices:[SCNVector3]=[],normals:[SCNVector3]=[],indices:[UInt32]=[]
        var uv:[CGPoint]=[]
        for ring in 0...rings {
            let r=radius*max(0.00001,Float(ring)/Float(rings))
            for col in 0...columns {
                let angle=Float(col)/Float(columns)*2 * .pi
                let x=r*cos(angle),y=r*sin(angle)*1.30
                let sx=x-side*0.096,sy=y-0.004,ry:Float=0.25764,rx:Float=0.226
                let taper=1-0.15*sy/ry
                let q=sx*sx/(rx*rx*taper*taper)+sy*sy/(ry*ry)
                let dome=sqrt(max(0.005,1-q))
                let z=0.012+0.07458*dome+lift-0.065
                let dx = -0.07458*sx/(rx*rx*taper*taper*dome)
                let dy = -0.07458*(sy/(ry*ry)+0.15*sx*sx/(ry*rx*rx*taper*taper*taper))/dome
                let n=simd_normalize(SIMD3<Float>(-dx,-dy,1))
                vertices.append(SCNVector3(x,y,z));normals.append(SCNVector3(n.x,n.y,n.z))
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
        let g=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:normals),SCNGeometrySource(textureCoordinates:uv)],elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)])
        g.firstMaterial=material;parent.addChildNode(SCNNode(geometry:g))
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
        #pragma body
        float bounce=1.0-smoothstep(-0.85,0.40,in.eyeHeight);
        _surface.emission.rgb += float3(0.135,0.10,0.075)*bounce;
        _surface.emission.rgb += float3(0.09,0.04,0.08)*pow(bounce,4.0);
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
        iris.shaderModifiers = [.surface: """
        #pragma body
        _surface.diffuse.a=1.0;
        """]
        iris.diffuse.minificationFilter = .linear
        iris.diffuse.magnificationFilter = .linear
        iris.diffuse.mipFilter = .linear
        iris.diffuse.maxAnisotropy=8
        let browMaterial=Self.material(UIColor(red:0.24,green:0.20,blue:0.64,alpha:1),roughness:0.72)
        browMaterial.shaderModifiers=[.geometry:Self.grainGeometryModifier,.surface:Self.grainSurfaceModifier()]
        let lidMaterial=Self.material(UIColor(red:0.30,green:0.23,blue:0.70,alpha:1),roughness:0.70)
        lidMaterial.shaderModifiers=[.geometry:Self.grainGeometryModifier,
                                     .surface:Self.grainSurfaceModifier(strength:"0.65")]
        for side: Float in [-1,1] {
            let eyeRoot = SCNNode(); eyeRoot.position = SCNVector3(side * 0.380, 0.434, 0.555); bones[0].addChildNode(eyeRoot)
            eyeRoot.eulerAngles.y = side * 0.20
            eyeRoot.eulerAngles.z = -side * 0.10
            eyeRoot.scale = SCNVector3(1.12,0.88,1)
            _ = eyeShell(0.231, SCNVector3(1,1.14,0.23), SCNVector3(0,-0.006,0), purple, parent: eyeRoot)
            let eyeIvory = ivory.copy() as! SCNMaterial
            if side > 0 { eyeIvory.diffuse.contents = UIColor(red:0.71,green:0.66,blue:0.57,alpha:1) }
            _ = eyeShell(0.226, SCNVector3(1,1.14,0.33), SCNVector3(0,-0.006,0.012), eyeIvory, parent: eyeRoot)
            let gaze = SCNNode(); gaze.position = SCNVector3(-side * 0.096,-0.010,0.065); eyeRoot.addChildNode(gaze); pupils.append(gaze)
            eyeDisc(radius:0.125,side:side,lift:0.010,material:iris,parent:gaze)
            let lid=SCNNode(geometry:Self.openLid.copy() as? SCNGeometry)
            lid.geometry?.firstMaterial=lidMaterial
            let morph=SCNMorpher();morph.targets=Self.lidTargets;morph.calculationMode = .normalized
            lid.morpher=morph;eyeRoot.addChildNode(lid);eyelids.append(morph)
            let seam=tube(points:(0...24).map { step in
                let x=Float(step)/24*0.32-0.16
                let y = -0.025+0.032*pow(x/0.16,2)
                let taper = 1-0.15*y/0.268
                let z = 0.016+Self.lidDepth*sqrt(max(0,1-pow(x/(0.244*taper),2)-pow(y/0.268,2)))
                return SCNVector3(x,y,z)
            },radius:0.004,material:Self.material(UIColor(red:0.22,green:0.13,blue:0.53,alpha:1)))
            seam.opacity=0;eyeRoot.addChildNode(seam);lidCreases.append(seam)
            let brow = tube(points: (0...48).map { step in
                let t=Float(step)/48
                return SCNVector3(-0.138+t*0.276, 0.008*sin(t * .pi), 0)
            }, radius: 0.046, material: browMaterial, radiusScale: { t in
                let inward = side < 0 ? t : 1-t
                let blend = inward*inward*(3-2*inward)
                return 0.75+0.40*blend
            })
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
        orange.shaderModifiers=[.surface: """
        #pragma body
        _surface.diffuse.a=1.0;
        """]
        let lips=SCNNode(geometry:Self.smileGeometry)
        lips.geometry = lips.geometry?.copy() as? SCNGeometry
        lips.geometry?.firstMaterial=orange; lips.scale=SCNVector3(1.05,1.158,1); mouth.addChildNode(lips)
        mouth.position = SCNVector3(-0.0033,0.179,0.601); bones[0].addChildNode(mouth)
    }
    // The upper eyelid closes over the eye instead of flattening the eyeball.
    // Closely spaced poses keep interpolated chords outside the curved iris.
    // Only the two neighbouring targets are active; topology stays shared.
    private static let lidDepth: Float = 0.112
    nonisolated(unsafe) private static let openLid = lidGeometry(angle:0.057)
    nonisolated(unsafe) private static let lidTargets = (1...16).map { lidGeometry(angle:Float($0) * .pi/16) }
    private static func lidGeometry(angle:Float) -> SCNGeometry {
        let rows=18, columns=24
        var vertices:[SCNVector3]=[], normals:[SCNVector3]=[], indices:[UInt32]=[]
        for row in 0...rows {
            let theta=(0.001+Float(row)/Float(rows)*(angle-0.002))
            for col in 0...columns {
                let phi=Float(col)/Float(columns) * Float.pi
                let y=0.268*cos(theta)
                let x=0.244*sin(theta)*cos(phi)*(1-0.15*y/0.268),z=0.012+lidDepth*sin(theta)*sin(phi)
                vertices.append(SCNVector3(x,y,z))
                let n=simd_normalize(SIMD3<Float>(x/(0.244*0.244),y/(0.268*0.268),(z-0.012)/(lidDepth*lidDepth)))
                normals.append(SCNVector3(n.x,n.y,n.z))
                if row<rows && col<columns {
                    let a=UInt32(row*(columns+1)+col),b=a+1,c=a+UInt32(columns+1),d=c+1
                    indices += [a,b,c,b,d,c]
                }
            }
        }
        return SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:normals)],elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)])
    }

    // A single closed lip cushion, with the smile pressed into the surface.
    // Immutable geometry is cached; expression scaling still costs one transform.
    nonisolated(unsafe) private static let smileGeometry: SCNGeometry = {
        let mesh=asset.mouth
        return SCNGeometry(sources:[
            source(mesh.positions,semantic:.vertex,count:mesh.positions.count/3,components:3,floating:true),
            source(mesh.normals,semantic:.normal,count:mesh.normals.count/3,components:3,floating:true),
            source(mesh.textureCoordinates,semantic:.texcoord,count:mesh.textureCoordinates.count/2,components:2,floating:true)
        ],elements:[SCNGeometryElement(indices:mesh.indices,primitiveType:.triangles)])
    }()

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
        let g=SCNGeometry(sources:[SCNGeometrySource(vertices:vertices),SCNGeometrySource(normals:normals)],elements:[SCNGeometryElement(indices:indices,primitiveType:.triangles)])
        g.firstMaterial=material
        return SCNNode(geometry:g)
    }

    private func closeEyelids(_ amount:Float) {
        lock.lock(); defer { lock.unlock() }
        let closure=max(0,min(1,amount))
        guard abs(closure-eyelidClosure)>0.0001 else { return }
        eyelidClosure=closure
        for seam in lidCreases { seam.opacity=CGFloat(pow(closure,4)) }
        let targetCount=Self.lidTargets.count
        let phase=closure*Float(targetCount)
        let segment=min(targetCount-1,Int(phase)), progress=phase-Float(segment)
        for lid in eyelids {
            for index in 0..<targetCount {
                let weight=index==segment ? progress : (index==segment-1 ? 1-progress : 0)
                lid.setWeight(CGFloat(weight),forTargetAt:index)
            }
        }
    }

    func play(_ mood: LisaMascotMood, animated: Bool) {
        #if DEBUG
        let animated = animated && !(ProcessInfo.processInfo.arguments.contains("--octopus-preview") && ProcessInfo.processInfo.arguments.contains("--octopus-still"))
        #endif
        lock.lock(); self.mood = mood; lock.unlock()
        if !animated {
            node.removeAction(forKey:"rig")
            activity = 0; swimWeight = 0; previousTime = 0
            bends = Array(repeating: 0, count: 24)
            twists = Array(repeating: 0, count: 24)
            for b in bones { b.eulerAngles = SCNVector3Zero }; bones[0].scale=SCNVector3(1,1,1)
            closeEyelids(mood == .sleepy ? 1 : 0)
            for (i,pupil) in pupils.enumerated() { pupil.position.x = i==0 ? 0.096 : -0.096; pupil.position.y = -0.010 }
            for (i,brow) in brows.enumerated() { brow.position.y=0.77;brow.position.z=0.435;brow.eulerAngles.z = i==0 ? 0.34 : -0.34 }
            mouth.scale=SCNVector3(1,1,1)
            return
        }
        guard node.action(forKey:"rig") == nil else { return }
        node.runAction(.repeatForever(.customAction(duration:24) { [weak self] _,time in self?.animate(time) }),forKey:"rig")
    }
    /// Distinct, bounded poses blend into the swim instead of replacing it.
    private func armGesture(_ mood: LisaMascotMood, arm: Int, joint: Int, time: Float) -> (bend: Float, twist: Float) {
        let tip = Float(joint) / 2
        let side: Float = arm < 4 ? 1 : -1
        let front = arm == 0 || arm == 7
        let wave = sin(time * 5 - Float(joint) * 0.6 + Float(arm) * 0.8)
        switch mood {
        case .idle, .sleepy: return (0, 0)
        case .happy, .encouraging:
            return arm == 1 ? (-0.20 - tip * 0.16 + wave * 0.12, sin(time * 6) * 0.18 * (1-tip)) : (0, 0)
        case .thinking, .curious:
            return front ? (-0.18 - tip * 0.14, side * 0.10) : (-0.04, 0)
        case .celebrating, .giggle:
            return (0.18 + wave * (0.20 + tip * 0.10), side * sin(time * 4) * 0.12)
        case .peek, .cloudHide:
            return (front ? -0.32 - tip * 0.18 : 0.18, front ? side * 0.12 : 0)
        case .swim, .chase, .rocket:
            return (sin(time * .pi - Float(joint) * 0.5) * 0.18, 0)
        case .moonwalk:
            return (sin(time * 5 + Float(arm) * .pi / 2 - Float(joint)) * 0.25, side * wave * 0.08)
        case .juggle:
            return (front ? -0.18 + sin(time * 5 + side * .pi / 2) * 0.22 : -0.08, front ? side * 0.12 : 0)
        case .sneeze:
            return ((pow(max(0, sin(time * 4)), 4) - 0.3) * 0.40, 0)
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
    private func animate(_ time: CGFloat) {
        lock.lock(); let mood = self.mood; let swimming = self.swimming; lock.unlock()
        let dt = Float(time >= previousTime ? min(0.05,time-previousTime) : 1/60); previousTime=time
        let target: Float = mood == .idle || mood == .thinking || mood == .sleepy ? 0 : 1
        activity += (target-activity)*(1-exp(-dt/0.28))
        let t=Float(time), cycle=t * .pi/12
        let blend = 1 - exp(-dt / 0.13)
        swimWeight += ((swimming == nil ? 0 : 1) - swimWeight) * blend
        let stroke = Float(swimming?.phase ?? Double(t * .pi))
        let effort = Float(swimming?.effort ?? 0)
        let braking = Float(swimming?.braking ?? 0)
        let turn = Float(swimming?.turn ?? 0)
        for i in 0..<8 {
            let angle=Float(i) * .pi/4 + .pi/8
            for j in 0..<3 {
                let joint = Float(j)
                let idle = sin(cycle * Float(mood == .sleepy ? 3 : 6+i%3) + angle - joint * 0.55) * (0.07 + joint * 0.045) * (mood == .sleepy ? 0.45 : 1)
                // A wave travels from the base to each tip, with a slight arm lag.
                // Recovery opens the arms; the power stroke curls them together.
                let lag = joint * 0.48 + Float(i % 2) * 0.16
                let power = sin(stroke - lag)
                let paddle = (0.08 + power * (0.22 + joint * 0.085)) * (0.45 + effort * 0.55)
                let fan = -braking * (0.14 + joint * 0.04)
                let steering = turn * sin(angle) * (0.15 + joint * 0.04)
                let gestureTime = swimming != nil && [.swim, .chase, .rocket].contains(mood) ? stroke / .pi : t
                let gesture = armGesture(mood, arm: i, joint: j, time: gestureTime)
                let target = idle * (1 - swimWeight * 0.7) + swimWeight * (paddle + fan + steering) + gesture.bend
                let index = i * 3 + j
                bends[index] += (target - bends[index]) * blend
                let twist = (j == 0 ? sin(cycle * 6 + angle) * 0.035 + swimWeight * turn * 0.10 : 0) + gesture.twist
                twists[index] += (twist - twists[index]) * blend
                // Compose rotations once: do not mix Euler writes with axis-angle.
                let curl = simd_quatf(angle: bends[index], axis: SIMD3(cos(angle), 0, -sin(angle)))
                let sweep = simd_quatf(angle: twists[index], axis: SIMD3(0, 1, 0))
                bones[1+index].simdOrientation = sweep * curl
            }
        }
        let breath = (mood == .sleepy ? Float(0.025) : 0.012) * sin(cycle * (mood == .sleepy ? 3 : 6))
        let contraction = swimWeight * Float(swimming?.propulsion ?? 0) * 0.045
        bones[0].scale = SCNVector3(1 + breath - contraction,
                                    1 + (mood == .sleepy ? breath * 1.2 : 0.015 * sin(cycle * 6)) + contraction * 0.7,
                                    1 + breath - contraction)
        // Smooth blink every four seconds, with no sprite substitutions.
        let local=t.truncatingRemainder(dividingBy:4)
        let blink=local>3.65 ? pow(sin((local-3.65)/0.35 * .pi),2) : 0
        let closure=Self.inspectionBlink ?? (mood == .sleepy ? 1 : blink)
        closeEyelids(closure)
        for (i,brow) in brows.enumerated() {
            let side:Float=i==0 ? -1:1
            let curious:Float=mood == .thinking && i==0 ? 0.022 : 0
            brow.position.y=0.77+activity*0.012+curious
            brow.position.z=0.435-activity*0.008-curious*0.7
            brow.eulerAngles.z = -side*(0.34+activity*0.10)+curious*3
        }
        for (i,pupil) in pupils.enumerated() { let side:Float=i==0 ? -1:1;pupil.position.x = -side*0.096+sin(cycle*2)*0.014;pupil.position.y = -0.010+cos(cycle*3)*0.009 }
        mouth.scale=SCNVector3(1+activity*0.08,1+activity*0.18,1)
    }
}
