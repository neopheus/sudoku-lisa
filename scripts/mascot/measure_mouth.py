"""Read the supplied reference and save mouth contour measurements (no image edits).
Run with Python 3, NumPy and Pillow before rebuilding the offline sculpt.
"""
from pathlib import Path
import hashlib,json
import numpy as np
from PIL import Image
root=Path(__file__).resolve().parents[2]
p=root/'docs/mascot-hd/poulpi-reference-hd.png'
a=np.array(Image.open(p)).astype(float)
mask=(a[:,:,0]>150)&(a[:,:,0]>a[:,:,1]*1.35)&(a[:,:,0]>a[:,:,2]*2.5)
mask[:545]=False;mask[670:]=False;mask[:,:530]=False;mask[:,720:]=False
y,x=np.nonzero(mask);left,right=int(x.min()),int(x.max())
xs=np.arange(left,right+1)
top=np.array([np.flatnonzero(mask[:,i])[0] for i in xs],dtype=float)
bottom=np.array([np.flatnonzero(mask[:,i])[-1] for i in xs],dtype=float)
# Remove pixel-sized steps while retaining the reference's two asymmetric lobes.
for values in [top,bottom]:values[:]=np.convolve(np.pad(values,2,mode='edge'),np.ones(5)/5,mode='valid')
crease_x=np.arange(580,672);crease_y=[]
for xx in crease_x:
 rows=np.arange(585,630);rows=rows[mask[rows,xx]]
 crease_y.append(float(rows[np.argmin(a[rows,xx,1])]))
coeff=np.polyfit(crease_x-625,crease_y,2)
r={'source':str(p.relative_to(root)),'sha256':hashlib.sha256(p.read_bytes()).hexdigest(),
   'method':'Orange RGB segmentation in a fixed mouth ROI; 5-pixel contour smoothing; quadratic fit to minimum green channel in the smile crease. Measurements, not a reconstructed depth map.',
   'bboxPixels':[left,int(y.min()),right,int(y.max())],
   'columns':xs.tolist(),'topPixels':top.tolist(),'bottomPixels':bottom.tolist(),
   'creasePixelPolynomialAboutX625':coeff.tolist(),
   'localWidth':.270,'localHeight':.164,'localTop':.0695}
(root/'docs/mascot-hd/mouth-reference-contour.json').write_text(json.dumps(r,indent=2)+'\n')
print('Mouth bounds',r['bboxPixels'],'crease fit',coeff.tolist())
