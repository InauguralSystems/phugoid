from pathlib import Path
import sys,json,collections
sys.path.insert(0,str(Path('.scratch').resolve()))
from predicate_model import Model
models={}; seq={}; vals={}; flags={}; mismatches=[]
for row in Path('.scratch/evidence/ap-trace-new.txt').read_text().splitlines():
 t=row.split()
 if t[:1]==['SEED']:
  models[t[1]]=Model(float(t[2])); seq[t[1]]=[];vals[t[1]]=[float(t[2])];flags[t[1]]=[]
 elif t[:1]==['SAMPLE']:
  name=t[1];v=float(t[2]);label,p=models[name].step(v)
  actual=[x=='true' for x in t[4:]]
  want=[p[k] for k in ['converged','stable','diverging','oscillating','equilibrium']]
  if label!=t[3] or actual!=want:mismatches.append((name,len(seq[name]),label,t[3],want,actual))
  seq[name].append(label);vals[name].append(v);flags[name].append(p)
Path('.scratch/evidence/ap-model-mismatches.json').write_text(json.dumps(mismatches,indent=2))
print('raw samples',sum(map(len,seq.values())),'streams',len(seq),'model mismatches',len(mismatches)); print(mismatches[:8])
metrics={}
for name,ls in seq.items():
 name=name.removesuffix('.run');cnt=collections.Counter(ls)
 for k,val in cnt.items():metrics[name+'.'+{'diverging':'div','converged':'conv','equilibrium':'equil'}.get(k,k)]=val
 metrics[name+'.runs']=sum(i==0 or ls[i]!=ls[i-1] for i in range(len(ls)))
 metrics[name+'.maxrun']=max(len(list(g)) for _,g in __import__('itertools').groupby(ls))
 for k,abbr in [('diverging','didx'),('converged','cidx'),('oscillating','oidx')]:metrics[name+'.'+abbr]=sum(i for i,x in enumerate(ls) if x==k)
 for k in ['stable','moving','improving']:metrics.setdefault(name+'.'+k,0)
# The C5.p1.inner check names spell the two counts out.
metrics['C5.p1.inner.converged']=metrics.get('C5.p1.inner.conv',0)
metrics['C5.p1.inner.diverging']=metrics.get('C5.p1.inner.div',0)
changes={}
import re
for name,old,new in re.findall(r'^FAIL (\S+) exact=(\d+) val=(\d+)$',Path('.scratch/evidence/ap-initial.txt').read_text(),re.M):
 assert metrics[name]==int(new),(name,metrics.get(name),new)
 changes[name]={'old':int(old),'new':metrics[name]}
Path('.scratch/evidence/ap-derived-changes.json').write_text(json.dumps(changes,indent=2)+'\n')
Path('.scratch/evidence/ap-derived-metrics.json').write_text(json.dumps(metrics,indent=2)+'\n')
# Include every transition's whole input window, for review against the model.
old={}
for row in Path('.scratch/evidence/ap-trace-old.txt').read_text().splitlines():
 t=row.split()
 if t[:1]==['SEED']:old[t[1]]=[]
 elif t[:1]==['SAMPLE']:old[t[1]].append(t[3])
with Path('.scratch/evidence/ap-verdict-transitions.jsonl').open('w') as f:
 for name,ls in seq.items():
  for i,label in enumerate(ls):
   if label!=old[name][i]:
    f.write(json.dumps({'stream':name,'sample':i,'values':vals[name][max(0,i-9):i+2], 'old':old[name][i],'new':label,'predicates':flags[name][i]})+'\n')
print('derived changed pins',len(changes))
