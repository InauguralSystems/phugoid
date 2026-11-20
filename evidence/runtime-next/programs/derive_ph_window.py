import sys,json
from pathlib import Path
sys.dont_write_bytecode=True
sys.path.insert(0,'.scratch')
from simulate_ap import deriv,base
from predicate_model import Model
s=base['state'].copy();u=[s[0]];dt=.05;P=base['P']
def d(s,t):return deriv(s,base['de']+(.005 if t<20. else 0.),P)
for n in range(5600):
 t=n*dt;k1=d(s,t);k2=d([a+.5*dt*b for a,b in zip(s,k1)],t+.5*dt);k3=d([a+.5*dt*b for a,b in zip(s,k2)],t+.5*dt);k4=d([a+dt*b for a,b in zip(s,k3)],t+dt)
 s=[s[i]+dt/6.*(k1[i]+2.*k2[i]+2.*k3[i]+k4[i]) for i in range(4)]
 if (n+1)%20==0:u.append(s[0])
m=Model(u[45])
for i in range(45,281):label,preds=m.step(u[i])
result=dict(t280=u[280],minimum_since45=min(u[45:]),running_best=m.best,steps_since_best=None if m.since>=100000 else m.since,independent_report=label,predicates=preds,window=u[270:281])
Path('.scratch/evidence/ph-window-model.json').write_text(json.dumps(result,indent=2));print(json.dumps(result))
assert label=='stable'
