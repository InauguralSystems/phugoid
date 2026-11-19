from pathlib import Path
import sys,json,collections
sys.path.insert(0,'.scratch');from predicate_model import Model
streams={}
for row in Path('.scratch/evidence/ap-trace-new.txt').read_text().splitlines():
 t=row.split()
 if t[:1]==['SEED']:streams[t[1]]=[float(t[2])]
 elif t[:1]==['SAMPLE']:streams[t[1]].append(float(t[2]))
result={}
for name,xs in streams.items():
 labels=[]
 for scale in [1.,57.29577951308232,1000.]:
  model=Model(xs[0]*scale);labels.append([model.step(x*scale)[0] for x in xs[1:]])
 result[name]={'different_deg':sum(a!=b for a,b in zip(labels[0],labels[1])),'different_mrad':sum(a!=b for a,b in zip(labels[0],labels[2])),'counts':[dict(collections.Counter(ls)) for ls in labels],'osc_differences':sum((a=='oscillating')!=(b=='oscillating') for a,b in zip(labels[0],labels[2]))}
Path('.scratch/evidence/ap-unit-variations.json').write_text(json.dumps(result,indent=2))
for k,v in result.items():print(k,v['different_deg'],v['different_mrad'],'osc differences',v['osc_differences'])
