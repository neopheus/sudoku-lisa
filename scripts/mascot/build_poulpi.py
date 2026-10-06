"""Blender offline sculpt, smooth skin binding and compact runtime mesh export.
Run: blender -b --python-exit-code 1 --python scripts/mascot/build_poulpi.py
Coordinates intentionally use SceneKit's Y-up / +Z-front convention.
"""
import bpy, bmesh, math, json, sys
sys.dont_write_bytecode=True
sys.path.insert(0,str(__import__("pathlib").Path(__file__).resolve().parent))
from sculpt_surface import sculpt
from mouth_surface import sculpt_mouth
import numpy as np
from mathutils.bvhtree import BVHTree
from mathutils.geometry import barycentric_transform
from mathutils import Vector
from pathlib import Path
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)

def curve(i,t):
    # Deliberately posed curled arms: the raised pair frames the cheeks, while
    # the front pair rests in broad U-shaped curls as in the supplied portrait.
    a=math.pi/8+i*math.pi/4
    anchors=[(.20,-.10),(.43,-.43),(.69,-.65),(.88,-.62),(.94,-.46),(.79,-.40)]
    if i in (1,6):
        side=1 if i==1 else -1
        anchors=[Vector((side*x,y,z)) for x,y,z in [(.36,-.20,.23),(.55,-.31,.48),(.77,-.27,.65),(.90,-.10,.72),(.84,.045,.73),(.71,.005,.73)]]
    elif i in (0,7):
        side=1 if i==0 else -1
        anchors=[Vector((side*x,y,z)) for x,y,z in [(.14,-.02,.36),(.25,-.36,.43),(.30,-.72,.72),(.51,-.74,.80),(.65,-.72,.87),(.59,-.63,.94)]]
    elif i in (2,5):
        side=1 if i==2 else -1
        anchors=[Vector((side*x,y,z)) for x,y,z in [(.22,-.20,-.04),(.55,-.55,.08),(.84,-.69,.22),(1.00,-.63,.40),(1.06,-.62,.62),(.84,-.35,.30)]]
    else:
        side=1 if i==3 else -1
        # The rear pair peeks through the front web instead of spreading behind
        # the lateral arms. Keep the tips apart to avoid a second attachment.
        anchors=[Vector((side*x,y,z)) for x,y,z in [(.12,-.18,-.15),(.17,-.50,-.40),(.22,-.85,-.65),(.25,-.89,-.78),(.24,-.76,-.86),(.22,-.68,-.80)]]
    for anchor in anchors: anchor.x *= .90
    q=min(t,.999999)*5;j=int(q);u=q-j
    p0=anchors[max(0,j-1)];p1=anchors[j];p2=anchors[j+1];p3=anchors[min(5,j+2)]
    return .5*((2*p1)+(-p0+p2)*u+(2*p0-5*p1+4*p2-p3)*u*u+(-p0+3*p1-3*p2+p3)*u*u*u)

def basis(i,t):
    tangent=(curve(i,min(1,t+.001))-curve(i,max(0,t-.001))).normalized()
    a=math.pi/8+i*math.pi/4; across=Vector((math.cos(a),0,-math.sin(a)))
    across=(across-tangent*across.dot(tangent)).normalized()
    underside=-tangent.cross(across).normalized()
    # A natural axial twist turns the underside toward the viewer as each
    # curled arm lifts. Cups stay on that same continuous underside ribbon.
    twist=2.4 if i in (1,6) else .65
    underside+=Vector((0,0,twist))
    if i in (2,5):
        # The lateral curls expose their outer lower ribbon, not their crown.
        underside=Vector((1.5 if i==2 else -1.5,-.45,.3))
    underside=(underside-tangent*underside.dot(tangent)).normalized()
    across=tangent.cross(underside).normalized()
    return tangent,across,underside

def radius(t, i=None):
    if i in (0,7): return .18+.055*math.sin(math.pi*t)-.06*t
    if i in (1,6): return .105*(1-t)+.085
    if i in (2,5):
        tip=max(0,min(1,(t-.60)/.40))
        return .19*(1-t)+.100-.030*tip*tip*(3-2*tip)
    return .19*(1-t)+.100

def mesh(name,vertices,faces):
    m=bpy.data.meshes.new(name);m.from_pydata(vertices,[],faces);m.update()
    obj=bpy.data.objects.new(name,m);bpy.context.collection.objects.link(obj);return obj

# A smooth distance union creates a continuous mantle instead of overlapping
# ellipsoids with an obvious horizontal neck seam.
sculpt_vertices,sculpt_faces=sculpt(curve,radius)
skin=mesh('Poulpi continuous sculpt',sculpt_vertices.tolist(),sculpt_faces.tolist())
bpy.context.view_layer.objects.active=skin;skin.select_set(True)
# Collapse nearly coincident iso-surface vertices before simplification. This
# prevents tiny tetrahedral slivers from turning into visible pinholes.
bm=bmesh.new();bm.from_mesh(skin.data)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00008)
bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.00004)
bmesh.ops.holes_fill(bm,edges=[e for e in bm.edges if e.is_boundary],sides=0)
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
bm.to_mesh(skin.data);bm.free()
# Resolve sub-voxel saddle contacts from the implicit tessellation before LOD.
# This offline resampling keeps one closed skin without four-face edges.
r=skin.modifiers.new('Manifold resampling','REMESH');r.mode='VOXEL';r.voxel_size=.014;r.use_smooth_shade=True
bpy.ops.object.modifier_apply(modifier=r.name)
s=skin.modifiers.new('Silky surface','SMOOTH');s.factor=.65;s.iterations=4;bpy.ops.object.modifier_apply(modifier=s.name)
d=skin.modifiers.new('Mobile mesh','DECIMATE');d.ratio=.40;bpy.ops.object.modifier_apply(modifier=d.name)
bm=bmesh.new();bm.from_mesh(skin.data)
bmesh.ops.holes_fill(bm,edges=[e for e in bm.edges if e.is_boundary],sides=0)
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
assert all(e.is_manifold for e in bm.edges), 'Non-manifold skin surface'
bm.to_mesh(skin.data);bm.free()
bpy.ops.object.transform_apply(location=True,rotation=True,scale=True)
for p in skin.data.polygons:p.use_smooth=True
skin.data.calc_loop_triangles()
# Three serial joints per arm; bind matrices are exported in model coordinates.
joints=[{'parent':-1,'position':[0,0,0]}]
for i in range(8):
    for j,t in enumerate((.12,.48,.80)):
        joints.append({'parent':0 if j==0 else len(joints)-1,'position':list(curve(i,t))})
paths=[[curve(i,j/64) for j in range(65)] for i in range(8)]

def bind_arm(i,t,strength=1):
    # Skin interpolates continuously from the body into root/middle/tip bones.
    if t<.12: ids=[0,1+i*3];w=[1-t/.12,t/.12]
    elif t<.48: q=(t-.12)/.36;ids=[1+i*3,2+i*3];w=[1-q,q]
    elif t<.80: q=(t-.48)/.32;ids=[2+i*3,3+i*3];w=[1-q,q]
    else: ids=[3+i*3];w=[1]
    weights={idx:weight*strength for idx,weight in zip(ids,w)};weights[0]=weights.get(0,0)+1-strength
    pairs=[(i,w) for i,w in weights.items() if w>1e-6]
    return [i for i,w in pairs]+[0]*(4-len(pairs)),[w for i,w in pairs]+[0.]*(4-len(pairs))

def bind(p):
    if p.y>.15 and math.hypot(p.x,p.z)<.85:return [0]*4,[1.,0,0,0]
    i,j=min(((i,j) for i in range(8) for j in range(65)),key=lambda ij:(p-paths[ij[0]][ij[1]]).length_squared)
    radial=math.hypot(p.x,p.z);q=max(0,min(1,(radial-.48)/.30));q=q*q*(3-2*q)
    neck=max(0,min(1,(p.y+.18)/.44))
    central=max(0,min(1,(.95-radial)/.18));central=central*central*(3-2*central)
    q*=1-neck*neck*(3-2*neck)*central
    return bind_arm(i,j/64,q)

def pack_skin():
    v=[];n=[];b=[];w=[]
    for vert in skin.data.vertices:
        v.extend(round(float(x),6) for x in vert.co);n.extend(round(float(x),6) for x in vert.normal)
        ids,weights=bind(vert.co);b.extend(ids);w.extend(round(x,6) for x in weights)
    return {'positions':v,'normals':n,'indices':[int(i) for f in skin.data.loop_triangles for i in f.vertices],'bones':b,'weights':w}
# Diffuse bind weights over surface adjacency, not Euclidean arm boundaries.
# This preserves soft webbing between arms instead of tearing at nearest-arm seams.
skinPacked=pack_skin()
vertices=np.array(skinPacked['positions']).reshape(-1,3)
triangles=np.array(skinPacked['indices']).reshape(-1,3)
edges=np.concatenate([triangles[:,[0,1]],triangles[:,[1,2]],triangles[:,[2,0]]]);edges=np.concatenate([edges,edges[:,::-1]])
weights=np.zeros((len(vertices),len(joints)))
for vi in range(len(vertices)):
 for b,w in zip(skinPacked['bones'][vi*4:vi*4+4],skinPacked['weights'][vi*4:vi*4+4]):weights[vi,b]+=w
counts=np.bincount(edges[:,0],minlength=len(vertices))[:,None]
for _ in range(400):
 sums=np.zeros_like(weights);np.add.at(sums,edges[:,0],weights[edges[:,1]])
 weights=weights*.25+sums/np.maximum(1,counts)*.75
 head=(vertices[:,1]>.15)&(np.linalg.norm(vertices[:,[0,2]],axis=1)<.85)
 weights[head]=0;weights[head,0]=1

# At the web between two arms, smoothly hand control back to the mantle.
# This avoids discontinuities from truncating competing arms to four GPU weights.
for vi,w in enumerate(weights):
 strengths=np.array([w[1+i*3:4+i*3].sum() for i in range(8)])
 order=np.argsort(strengths);arm=int(order[-1]);best=strengths[arm];second=strengths[order[-2]]
 confidence=max(0,(best-second)/(best+second+1e-8))
 projected=np.zeros_like(w);projected[1+arm*3:4+arm*3]=w[1+arm*3:4+arm*3]*confidence
 projected[0]=1-projected.sum();weights[vi]=projected

def compact(w):
 ids=np.argsort(w)[-4:][::-1];v=w[ids];v=v/v.sum()
 return ids.tolist(),v.tolist()
skinPacked['bones']=[];skinPacked['weights']=[]
for w in weights:
 ids,values=compact(w);skinPacked['bones'].extend(ids);skinPacked['weights'].extend(values)
bvh=BVHTree.FromPolygons([Vector(v) for v in vertices],triangles.tolist(),all_triangles=True)
def bind_surface(p):
 near,normal,index,distance=bvh.find_nearest(p)
 a,b,c=triangles[index]
 bary=barycentric_transform(near,Vector(vertices[a]),Vector(vertices[b]),Vector(vertices[c]),Vector((1,0,0)),Vector((0,1,0)),Vector((0,0,1)))
 return compact(weights[a]*bary.x+weights[b]*bary.y+weights[c]*bary.z)
# Forty cups, one draw call, with the SAME skin binding as the supporting arm.
cv=[];cn=[];ci=[];cb=[];cw=[]
cup_sides=24
profile=[(.74,-.06),(.94,.10),(1,.34),(.90,.58),(.65,.66),(.30,.64)]
cup_centre_height=.63
def cup_seat(i,t):
    p=curve(i,t);tan,u,normal=basis(i,t)
    # Cast out from the arm centre. A nearest-point query from outside can
    # slide onto a neighbouring part of a curl and bunch consecutive cups.
    hit,_,_,_=bvh.ray_cast(p,normal,radius(t,i)+.35)
    assert hit is not None, ('No supporting skin under cup',i,t)
    return hit-normal*.004
for i in range(8):
    samples=np.linspace(.45 if i in (1,6) else .36,.79 if i in (1,6) else .885,128)
    points=np.array([cup_seat(i,float(t)) for t in samples])
    lengths=np.concatenate([[0],np.cumsum(np.linalg.norm(np.diff(points,axis=0),axis=1))])
    # Equal spacing along the actual underside surface, after projection.
    cup_times=np.interp(np.linspace(0,lengths[-1],4 if i in (1,2,5,6) else 6),lengths,samples)
    for t in cup_times:
        t=float(t)
        tan,u,normal=basis(i,t);centre=cup_seat(i,t)
        oval_progress=max(0,min(1,(t-.78)/.105)) if i in (0,7) else 0
        oval_blend=oval_progress*oval_progress*(3-2*oval_progress)
        oval=1.15+.25*oval_blend
        # Slim the exposed front-tip cushions across the arm while keeping
        # their length, supporting seat and skin binding unchanged.
        across_scale=1-.22*oval_blend
        size=.082-t*.009;base=len(cv)//3
        ids,cupWeights=bind_surface(centre)
        for ring,(r,h) in enumerate(profile):
            prev=profile[max(0,ring-1)];nxt=profile[ring+1] if ring+1<len(profile) else (0,cup_centre_height)
            for k in range(cup_sides):
                a=k*math.tau/cup_sides;radial=tan*(oval*math.cos(a))+u*(across_scale*math.sin(a))
                point=centre+size*(radial*r+normal*h);normal_radial=tan*(math.cos(a)/oval)+u*(math.sin(a)/across_scale)
                norm=(normal_radial*(nxt[1]-prev[1])+normal*(prev[0]-nxt[0])).normalized()
                cv.extend(point);cn.extend(norm);cb.extend(ids);cw.extend(cupWeights)
                if ring<len(profile)-1:
                    a=base+ring*cup_sides+k;b=base+ring*cup_sides+(k+1)%cup_sides;c=a+cup_sides;d=b+cup_sides;ci.extend([a,c,b,b,c,d])
        # A single axial pole closes the shallow recess without coincident
        # centre vertices or degenerate faces. Its normal cannot form a star.
        pole=len(cv)//3;point=centre+normal*(size*cup_centre_height)
        cv.extend(point);cn.extend(normal);cb.extend(ids);cw.extend(cupWeights)
        last=base+(len(profile)-1)*cup_sides
        for k in range(cup_sides):ci.extend([last+k,pole,last+(k+1)%cup_sides])
# Bake broad crevice shading once, keeping runtime lighting free of SSAO passes.
ao=[];golden=math.pi*(3-math.sqrt(5));normals=np.array(skinPacked['normals']).reshape(-1,3)
for point,n in zip(vertices,normals):
 normal=Vector(n).normalized();tangent=normal.cross(Vector((0,1,0)))
 if tangent.length<.01:tangent=normal.cross(Vector((1,0,0)))
 tangent.normalize();bitangent=normal.cross(tangent);origin=Vector(point)+normal*.006
 occ=0
 for k in range(16):
  z=(k+.5)/16;r=math.sqrt(1-z*z);angle=k*golden
  direction=normal*z+tangent*(r*math.cos(angle))+bitangent*(r*math.sin(angle))
  hit,_,_,distance=bvh.ray_cast(origin,direction,.32)
  if hit is not None:occ+=1-distance/.32
 ao.append(round(1-.52*occ/16,5))
skinPacked['occlusion']=ao
asset={'version':1,'joints':joints,'skin':skinPacked,'cups':{'positions':cv,'normals':cn,'indices':ci,'bones':cb,'weights':cw,'occlusion':[1.]*(len(cv)//3)}}
# Fail production if a binding could collapse a vertex or indexes are invalid.
for group in ('skin','cups'):
    g=asset[group];count=len(g['positions'])//3
    assert len(g['normals'])==count*3 and len(g['bones'])==count*4 and len(g['weights'])==count*4
    assert max(g['indices'])<count and max(g['bones'])<len(joints)
    assert all(abs(sum(g['weights'][i:i+4])-1)<1e-4 for i in range(0,len(g['weights']),4))
    assert all(math.isfinite(x) for key in ('positions','normals','weights') for x in g[key])
# A closed, sculpted mouth replaces the radial runtime patch. Its analytical
# distance field has no pinched centre and preserves a real crease in profile.
lip_vertices,lip_faces=sculpt_mouth()
lips=mesh('Poulpi sculpted lips',lip_vertices.tolist(),lip_faces.tolist())
bm=bmesh.new();bm.from_mesh(lips.data)
bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001)
bmesh.ops.dissolve_degenerate(bm,edges=list(bm.edges),dist=.000002)
bmesh.ops.holes_fill(bm,edges=[e for e in bm.edges if e.is_boundary],sides=0)
bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
assert all(e.is_manifold for e in bm.edges), 'Non-manifold lip surface'
bm.to_mesh(lips.data);bm.free()
bpy.context.view_layer.objects.active=lips
smooth=lips.modifiers.new('Soft lip boundary','SMOOTH');smooth.factor=.45;smooth.iterations=3
bpy.ops.object.modifier_apply(modifier=smooth.name)
lips.data.calc_loop_triangles()
source_vertices=[v.co.copy() for v in lips.data.vertices]
source_triangles=[tuple(t.vertices) for t in lips.data.loop_triangles]
source_bvh=BVHTree.FromPolygons(source_vertices,source_triangles,all_triangles=True)
decimate=lips.modifiers.new('Mobile lips','DECIMATE');decimate.ratio=.35
bpy.ops.object.modifier_apply(modifier=decimate.name)
lips.data.calc_loop_triangles()
reduced_vertices=[v.co.copy() for v in lips.data.vertices]
reduced_triangles=[tuple(t.vertices) for t in lips.data.loop_triangles]
reduced_bvh=BVHTree.FromPolygons(reduced_vertices,reduced_triangles,all_triangles=True)
source_samples=source_vertices+[sum((source_vertices[i] for i in tri),Vector())/3 for tri in source_triangles]
reduced_samples=reduced_vertices+[sum((reduced_vertices[i] for i in tri),Vector())/3 for tri in reduced_triangles]
forward=max(reduced_bvh.find_nearest(p)[3] for p in source_samples)
backward=max(source_bvh.find_nearest(p)[3] for p in reduced_samples)
assert max(forward,backward)<.001, ('Lip reduction changes surface too much',forward,backward)
reduction={'sourceTriangles':len(source_triangles),'reducedTriangles':len(reduced_triangles),
           'maximumSampledForwardDistance':forward,'maximumSampledBackwardDistance':backward,
           'method':'Bidirectional nearest-surface distances at every vertex and triangle centroid, relative to smoothed high-resolution lips, before x/y scale. Not an exhaustive Hausdorff bound.'}
(ROOT/'docs/mascot-hd/mouth-reduction.json').write_text(json.dumps(reduction,indent=2)+'\n')
# Keep the lip coordinates expected by the existing material and face rig.
for v in lips.data.vertices:v.co.x*=1.28;v.co.y*=1.12
lips.data.update();lips.data.calc_loop_triangles()
for poly in lips.data.polygons:poly.use_smooth=True
mouth_mapping=json.loads((ROOT/'docs/mascot-hd/mouth-reference-contour.json').read_text())
ml,mt,mr,mb=mouth_mapping['bboxPixels'];mouth_uv=[]
for v in lips.data.vertices:
    px=(ml+mr)*.5+(v.co.x/1.28)/mouth_mapping['localWidth']*(mr-ml)
    py=mt+(mouth_mapping['localTop']-v.co.y/1.12)/mouth_mapping['localHeight']*(mb-mt)
    mouth_uv.extend([px/1254,py/1254])
asset['mouth']={'textureCoordinates':mouth_uv,'positions':[float(c) for v in lips.data.vertices for c in v.co],
                'normals':[float(c) for v in lips.data.vertices for c in v.normal],
                'indices':[int(i) for tri in lips.data.loop_triangles for i in tri.vertices]}
# Leave the body active so offline rebinding tools still select the skin.
bpy.context.view_layer.objects.active=skin
out=ROOT/'App/Resources/Mascot/poulpi-rig.json';out.write_text(json.dumps(asset,separators=(',',':')))
bpy.context.preferences.filepaths.save_version=0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'docs/mascot-hd/poulpi-sculpt.blend'))
print('POULPI_MESH',len(asset['skin']['positions'])//3,'vertices',len(asset['skin']['indices'])//3,'triangles',len(joints),'joints',out.stat().st_size,'bytes')
