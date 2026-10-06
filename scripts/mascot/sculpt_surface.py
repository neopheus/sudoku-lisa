"""Smooth signed-distance sculpt and marching tetrahedra, offline NumPy only.
No extra runtime geometry or image dependency. Coordinates are Y-up.
"""
import numpy as np


def sculpt(curve, radius, step=.018):
    lo=np.array([-1.22,-1.20,-1.22],dtype=np.float32)
    hi=np.array([1.22,1.25,1.22],dtype=np.float32)
    shape=np.ceil((hi-lo)/step).astype(int)+1
    axes=[lo[i]+np.arange(shape[i],dtype=np.float32)*step for i in range(3)]
    xyz=np.stack(np.meshgrid(*axes,indexing='ij'),axis=-1)

    def ellipsoid(center,radii):
        p=xyz-np.array(center,dtype=np.float32);r=np.array(radii,dtype=np.float32)
        k0=np.linalg.norm(p/r,axis=-1);k1=np.linalg.norm(p/(r*r),axis=-1)
        return k0*(k0-1)/np.maximum(k1,1e-6)

    def union(a,b,k):
        h=np.maximum(k-np.abs(a-b),0)/k
        return np.minimum(a,b)-h*h*k*.25

    field=union(ellipsoid((0,.46,-.035),(.83,.69,.60)),
                ellipsoid((0,.10,.025),(.64,.50,.50)),.42)
    for i in range(8):
        points=np.array([curve(i,t) for t in np.linspace(0,1,65)],dtype=np.float32)
        radii=np.array([radius(t,i) for t in np.linspace(0,1,65)],dtype=np.float32)
        lower=np.maximum(0,np.floor((points.min(axis=0)-radii.max()-.12-lo)/step).astype(int))
        upper=np.minimum(shape,np.ceil((points.max(axis=0)+radii.max()+.12-lo)/step).astype(int)+1)
        box=tuple(slice(a,b) for a,b in zip(lower,upper));p=xyz[box]
        arm=np.full(p.shape[:-1],10,dtype=np.float32)
        for j in range(len(points)-1):
            delta=points[j+1]-points[j];q=p-points[j]
            t=np.clip(np.sum(q*delta,axis=-1)/np.dot(delta,delta),0,1)
            distance=np.linalg.norm(q-t[...,None]*delta,axis=-1)-(radii[j]+t*(radii[j+1]-radii[j]))
            arm=np.minimum(arm,distance)
        # Broad blending belongs at the arm roots, below the mantle. The
        # raised free ends must never acquire a second attachment to the face.
        root_blend=.02+.11*np.clip((-p[...,1]-.12)/.22,0,1)
        if i in (0,7):
            # Front roots continue the mantle into the two resting curls.
            # This larger blend does not apply to the free raised tips.
            root_blend=.08+.08*np.clip((-p[...,1]+.10)/.25,0,1)
            # Keep the descending front arms distinct below the mantle.
            # Their close inner surfaces need less union smoothing than roots.
            inner=np.exp(-(p[...,0]/.15)**4)
            below=np.clip((-p[...,1]-.22)/.18,0,1)
            root_blend*=1-.23*inner*below
        field[box]=union(field[box],arm,root_blend)
    # Shallow orbital depressions embed the whites in the face. Soft cheek
    # cushions and a muzzle sit under the pigment rather than on top of it.
    x,y,z=xyz[...,0],xyz[...,1],xyz[...,2]
    front=np.clip((z-.25)/.16,0,1)
    sockets=np.exp(-((np.abs(x)-.380)/.23)**4-((y-.44)/.23)**4)*front
    cheeks=np.exp(-((np.abs(x)-.47)/.18)**2-((y-.20)/.14)**2)*front
    field+=.027*sockets-.016*cheeks
    # Sculpt the upper orbital cushion into the skin, outside the ivory shell.
    # Unlike an enlarged eye backing, this volume remains continuous with the
    # forehead and does not add a separate ring in front of the eye.
    orbit=np.sqrt(((np.abs(x)-.380)/.265)**2+((y-.44)/.24)**2)
    upper=np.clip((y-.40)/.18,0,1)
    orbital_rim=np.exp(-((orbit-1.08)/.24)**2)*upper*front
    field-=.032*orbital_rim
    # A closed result must come from a closed iso-surface, not hole filling
    # after a limb has been clipped by the sampling domain.
    assert all(np.min(np.take(field,[0,-1],axis=axis))>0 for axis in range(3)), 'Sculpt exceeds sampling domain'
    return triangulate(field,lo,step)


def triangulate(field,lo,step):
    # Six tetrahedra share the same cube diagonal, so neighbouring cells weld.
    offsets=np.array([[0,0,0],[1,0,0],[1,1,0],[0,1,0],[0,0,1],[1,0,1],[1,1,1],[0,1,1]])
    cell_shape=np.array(field.shape)-1
    corner_values=[field[tuple(slice(int(o),int(o+n)) for o,n in zip(off,cell_shape))] for off in offsets]
    minimum=np.minimum.reduce(corner_values);maximum=np.maximum.reduce(corner_values)
    cells=np.argwhere((minimum<0)&(maximum>=0))
    coords=cells[:,None,:]+offsets[None,:,:]
    values=field[coords[:,:,0],coords[:,:,1],coords[:,:,2]]
    positions=lo+coords*step
    tets=[[0,1,2,6],[0,2,3,6],[0,3,7,6],[0,7,4,6],[0,4,5,6],[0,5,1,6]]
    triangles=[]
    for tet in tets:
        p=positions[:,tet];v=values[:,tet]
        masks=np.sum((v<0)*(1<<np.arange(4)),axis=1)
        for mask in range(1,15):
            ids=np.flatnonzero(masks==mask)
            if len(ids)==0:continue
            inside=[i for i in range(4) if mask&(1<<i)];outside=[i for i in range(4) if not mask&(1<<i)]
            def intersection(a,b):
                t=v[ids,a]/(v[ids,a]-v[ids,b])
                return p[ids,a]+t[:,None]*(p[ids,b]-p[ids,a])
            if len(inside)==1:
                a=inside[0];polys=[[intersection(a,b) for b in outside]]
            elif len(inside)==3:
                a=outside[0];polys=[[intersection(a,b) for b in inside]]
            else:
                a,b=inside;c,d=outside
                ac,ad,bc,bd=intersection(a,c),intersection(a,d),intersection(b,c),intersection(b,d)
                polys=[[ac,ad,bd],[ac,bd,bc]]
            outward=p[ids][:,outside].mean(axis=1)-p[ids][:,inside].mean(axis=1)
            for poly in polys:
                tri=np.stack(poly,axis=1)
                normal=np.cross(tri[:,1]-tri[:,0],tri[:,2]-tri[:,0])
                flip=np.sum(normal*outward,axis=1)<0
                tri[flip]=tri[flip][:,[0,2,1]]
                triangles.append(tri)
    triangles=np.concatenate(triangles)
    points,indices=np.unique(np.round(triangles.reshape(-1,3),6),axis=0,return_inverse=True)
    faces=indices.reshape(-1,3)
    valid=(faces[:,0]!=faces[:,1])&(faces[:,1]!=faces[:,2])&(faces[:,2]!=faces[:,0])
    return points,faces[valid]
