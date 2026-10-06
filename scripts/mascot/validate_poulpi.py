"""Blender Python: validate bind pose and posed mesh edge strain over one full cycle."""
import json, math
from pathlib import Path
import numpy as np
from mathutils import Matrix,Vector
root=Path(__file__).resolve().parents[2]
a=json.loads((root/'App/Resources/Mascot/poulpi-rig.json').read_text()); joints=a['joints']
def matrices(t,animated):
 out=[]
 for index,j in enumerate(joints):
  p=Vector(j['position']);parent=j['parent'];offset=p-(Vector(joints[parent]['position']) if parent>=0 else Vector())
  local=Matrix.Translation(offset)
  if index>0 and animated:
   arm=(index-1)//3;segment=(index-1)%3;angle=math.pi/8+arm*math.pi/4
   bend=math.sin(t*math.pi/12*(6+arm%3)+angle-segment*.55)*(.07+segment*.045)*1.65
   rotation=Matrix.Rotation(bend,4,Vector((math.cos(angle),0,-math.sin(angle))))
   if segment==0:
    euler=rotation.to_euler('XYZ');euler.y+=math.sin(t*math.pi/12*(6+arm%3)+angle)*.035;rotation=euler.to_matrix().to_4x4()
   local=local@rotation
  elif index==0 and animated:
   wave=math.sin(t*math.pi/12*6);local=local@Matrix.Diagonal((1+.012*wave,1+.015*wave,1+.012*wave,1))
  world=(out[parent]@local) if parent>=0 else local;out.append(world)
 return np.array([np.array(m@Matrix.Translation(-Vector(j['position']))) for m,j in zip(out,joints)])
report={}
for name in ('skin','cups'):
 g=a[name];v=np.array(g['positions']).reshape(-1,3);w=np.array(g['weights']).reshape(-1,4);ids=np.array(g['bones']).reshape(-1,4)
 homogeneous=np.concatenate([v,np.ones((len(v),1))],axis=1)
 def deform(t,animated=True):
  m=matrices(t,animated);return np.sum(np.einsum('nvij,nj->nvi',m[ids],homogeneous)*w[:,:,None],axis=1)[:,:3]
 rest=deform(0,False);error=float(np.max(np.abs(rest-v)));assert error<1e-5,error
 triangles=np.array(g['indices']).reshape(-1,3);edges=np.concatenate([triangles[:,[0,1]],triangles[:,[1,2]],triangles[:,[2,0]]])
 if name=='cups':
  normals=np.array(g['normals']).reshape(-1,3)
  assert np.isfinite(normals).all() and np.max(np.abs(np.linalg.norm(normals,axis=1)-1))<1e-4
  area=np.linalg.norm(np.cross(v[triangles[:,1]]-v[triangles[:,0]],v[triangles[:,2]]-v[triangles[:,0]]),axis=1)
  assert np.min(area)>1e-12, 'Degenerate cup triangle'
  unique_c,counts_c=np.unique(np.sort(edges,axis=1),axis=0,return_counts=True)
  assert np.max(counts_c)==2, 'Non-manifold cup surface'
  # Each cup has one open base buried in the supporting arm.
  rim=unique_c[counts_c==1]
  _,degree=np.unique(rim,return_counts=True)
  assert np.all(degree==2) and len(rim)==40*24, 'Unexpected cup boundary'
  rim_neighbors={}
  for i,j in rim:
   rim_neighbors.setdefault(int(i),[]).append(int(j));rim_neighbors.setdefault(int(j),[]).append(int(i))
  remaining=set(rim_neighbors);rim_loops=0
  while remaining:
   rim_loops+=1;stack=[remaining.pop()]
   while stack:
    for neighbor in rim_neighbors[stack.pop()]:
     if neighbor in remaining:remaining.remove(neighbor);stack.append(neighbor)
  assert rim_loops==40, ('Unexpected number of cup bases',rim_loops)

 boundary=nonmanifold=0
 if name=='skin':
  unique,counts=np.unique(np.sort(edges,axis=1),axis=0,return_counts=True)
  boundary=int(np.count_nonzero(counts==1));nonmanifold=int(np.count_nonzero(counts>2))
  assert boundary==0 and nonmanifold==0,('skin topology',boundary,nonmanifold)
  # A free arm has one attachment. A second attachment to the face creates a
  # handle in this closed sculpt; the former broken mesh had Euler = -2.
  euler=len(np.unique(triangles))-len(unique)+len(triangles)
  assert euler==2,('unexpected fused arm/handle',euler)
  adjacency=[[] for _ in range(len(v))]
  for left,right in unique:adjacency[left].append(right);adjacency[right].append(left)
  remaining=set(np.unique(triangles));components=0
  while remaining:
   components+=1;stack=[remaining.pop()]
   while stack:
    for neighbor in adjacency[stack.pop()]:
     if neighbor in remaining:remaining.remove(neighbor);stack.append(neighbor)
  assert components==1,('detached sculpt components',components)
 lengths=np.linalg.norm(v[edges[:,1]]-v[edges[:,0]],axis=1);edges=edges[lengths>.002];lengths=lengths[lengths>.002]
 clearance=float('inf')
 if name=='skin':
  raised=np.sum(np.where(((ids>=4)&(ids<=6))|((ids>=19)&(ids<=21)),w,0),axis=1)
  free_ends=(raised>.55)&(np.abs(v[:,0])>.58)&(v[:,1]>-.25)
  assert np.count_nonzero(free_ends)>100, 'Missing raised arm clearance samples'
 max_stretch=0
 for t in np.linspace(0,24,97):
  d=deform(t);assert np.isfinite(d).all()
  if name=='skin':
   breath=math.sin(t*math.pi/12*6)
   unscaled=d[free_ends]/np.array([1+.012*breath,1+.015*breath,1+.012*breath])
   p=unscaled-np.array([0,.46,-.035]);r=np.array([.83,.69,.60])
   k0=np.linalg.norm(p/r,axis=1);k1=np.linalg.norm(p/(r*r),axis=1)
   clearance=min(clearance,float(np.min(k0*(k0-1)/k1)))
  stretch=np.linalg.norm(d[edges[:,1]]-d[edges[:,0]],axis=1)/lengths;
  if float(stretch.max())>max_stretch:
   max_stretch=float(stretch.max());worst=(float(t),edges[int(np.argmax(stretch))].tolist())
 assert max_stretch<3.0,(name,max_stretch,worst,v[worst[1]].tolist(),ids[worst[1]].tolist(),w[worst[1]].tolist())
 loop=float(np.max(np.abs(deform(0)-deform(24))));assert loop<1e-5
 report[name]={'vertices':len(v),'triangles':len(triangles),'bindError':error,'maximumEdgeStretch':max_stretch,'loopError':loop,'sampledPoses':97}
 if name=='cups':
  report[name].update(boundaryLoops=rim_loops,minimumDoubleTriangleArea=float(np.min(area)),boundaryEdges=len(rim),maximumNormalLengthError=float(np.max(np.abs(np.linalg.norm(normals,axis=1)-1))))
 if name=='skin':
  assert clearance>.025,('raised tentacle touches head',clearance)
  report[name].update(boundaryEdges=boundary,nonManifoldEdges=nonmanifold,eulerCharacteristic=int(euler),connectedComponents=components,minimumRaisedArmHeadClearance=clearance)
# The rigid mouth must be a single closed volume, including its lip junction.
mouth=a['mouth'];mv=np.array(mouth['positions']).reshape(-1,3);mn=np.array(mouth['normals']).reshape(-1,3);mt=np.array(mouth['indices']).reshape(-1,3)
assert np.isfinite(mv).all() and np.isfinite(mn).all()
muv=np.array(mouth['textureCoordinates']).reshape(-1,2)
assert len(muv)==len(mv) and np.isfinite(muv).all() and (muv>=0).all() and (muv<=1).all()
assert np.max(np.abs(np.linalg.norm(mn,axis=1)-1))<1e-4
me=np.concatenate([mt[:,[0,1]],mt[:,[1,2]],mt[:,[2,0]]]);unique,counts=np.unique(np.sort(me,axis=1),axis=0,return_counts=True)
assert np.all(counts==2), 'Open or non-manifold lips'
euler=len(mv)-len(unique)+len(mt);assert euler==2,('Lip junction has a hole or detached volume',euler)
adj=[[] for _ in mv]
for i,j in unique:adj[i].append(j);adj[j].append(i)
seen=set();components=0
for start in range(len(mv)):
 if start in seen:continue
 components+=1;stack=[start];seen.add(start)
 while stack:
  for nxt in adj[stack.pop()]:
   if nxt not in seen:seen.add(nxt);stack.append(nxt)
assert components==1, ('Disconnected lips',components)
areas=np.linalg.norm(np.cross(mv[mt[:,1]]-mv[mt[:,0]],mv[mt[:,2]]-mv[mt[:,0]]),axis=1)
assert np.min(areas)>1e-12, 'Degenerate lip triangle'
report['mouth']={'connectedComponents':components,'minimumDoubleTriangleArea':float(np.min(areas)),'vertices':len(mv),'triangles':len(mt),'boundaryEdges':int(np.count_nonzero(counts==1)),'nonManifoldEdges':int(np.count_nonzero(counts>2)),'eulerCharacteristic':int(euler),'maximumNormalLengthError':float(np.max(np.abs(np.linalg.norm(mn,axis=1)-1)))}
report['ok']=True
(root/'docs/mascot-hd/rig-validation.json').write_text(json.dumps(report,indent=2));print(json.dumps(report))
