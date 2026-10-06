"""Closed lip volume whose frontal outline follows the measured reference."""
import json,hashlib
from pathlib import Path
import numpy as np
from sculpt_surface import triangulate


def sculpt_mouth(step=.004):
    data=json.loads((Path(__file__).resolve().parents[2]/'docs/mascot-hd/mouth-reference-contour.json').read_text())
    source=Path(__file__).resolve().parents[2]/data['source']
    assert hashlib.sha256(source.read_bytes()).hexdigest()==data['sha256'], 'Refresh mouth measurements for this reference'
    left,top,right,bottom=data['bboxPixels']
    sx=data['localWidth']/(right-left);sy=data['localHeight']/(bottom-top)
    xs=(np.array(data['columns'])-(left+right)*.5)*sx
    upper=data['localTop']-(np.array(data['topPixels'])-top)*sy
    lower=data['localTop']-(np.array(data['bottomPixels'])-top)*sy
    contour=np.concatenate([np.stack([xs,upper],axis=-1),np.stack([xs[::-1],lower[::-1]],axis=-1)])
    lo=np.array([-.165,-.12,-.075],dtype=np.float32)
    hi=np.array([.165,.10,.075],dtype=np.float32)
    shape=np.ceil((hi-lo)/step).astype(int)+1
    axes=[lo[i]+np.arange(shape[i],dtype=np.float32)*step for i in range(3)]
    xy=np.stack(np.meshgrid(*axes[:2],indexing='ij'),axis=-1)
    distance=np.full(xy.shape[:-1],10,dtype=np.float32)
    for a,b in zip(contour,np.roll(contour,-1,axis=0)):
        delta=b-a;q=xy-a;length=np.dot(delta,delta)
        if length<1e-12:continue
        t=np.clip(np.sum(q*delta,axis=-1)/length,0,1)
        distance=np.minimum(distance,np.linalg.norm(q-t[...,None]*delta,axis=-1))
    u=np.interp(xy[:,:,0],xs,upper);l=np.interp(xy[:,:,0],xs,lower)
    inside=(xy[:,:,0]>=xs[0])&(xy[:,:,0]<=xs[-1])&(xy[:,:,1]<=u)&(xy[:,:,1]>=l)
    signed=np.where(inside,-distance,distance)
    centre=(u+l)*.5;half=np.maximum(.001,(u-l)*.5)
    height=.052*np.sqrt(np.maximum(0,1-((xy[:,:,1]-centre)/half)**2))
    height*=np.sqrt(np.maximum(0,1-(xy[:,:,0]/(.5*data['localWidth']))**8))
    a,b,c=data['creasePixelPolynomialAboutX625']
    crease=data['localTop']-((a*(xy[:,:,0]/sx)**2+b*(xy[:,:,0]/sx)+c)-top)*sy
    crease_end=np.clip((.10-np.abs(xy[:,:,0]))/.025,0,1)
    crease_end=crease_end*crease_end*(3-2*crease_end)
    depression=.012*np.exp(-((xy[:,:,1]-crease)/.012)**2)*crease_end
    front=height-np.minimum(height*.65,depression)
    z=axes[2][None,None,:]
    field=np.maximum(signed[:,:,None],np.maximum(z-front[:,:,None],-z-height[:,:,None]*.70))
    assert all(np.min(np.take(field,[0,-1],axis=axis))>0 for axis in range(3)), 'Lip sculpt exceeds sampling domain'
    return triangulate(field,lo,step)
