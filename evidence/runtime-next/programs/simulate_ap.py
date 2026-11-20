from pathlib import Path
import json,math,sys,collections,itertools
sys.path.insert(0,'.scratch');from predicate_model import Model
base=json.loads(Path('.scratch/evidence/residual-new.txt').read_text().splitlines()[-1]); poison=json.loads(Path('.scratch/evidence/s9-params.txt').read_text())
rows={}; actual={}
for line in Path('.scratch/evidence/ap-trace-new.txt').read_text().splitlines():
 t=line.split()
 if t[:1]==['ROW']: rows[t[1]]=list(map(float,t[2].removeprefix('params=').split('|')))
 if t[:1]==['SEED']:actual[t[1]]=[]
 if t[:1]==['SAMPLE']:actual[t[1]].append(t[3])
rows={k:v for k,v in rows.items() if k in actual}
def deriv(s,de,P):
 u,w,q,th=s;V=math.sqrt(u*u+w*w);alpha=math.atan2(w,u);QS=.5*P['rho']*V*V*P['S'];ac=P['cbar']/(2.*V);qh=q*ac;ca=math.cos(alpha);sa=math.sin(alpha)
 CLp=P['CL0']+P['CLa']*alpha+P['CLq']*qh+P['CLde']*de;CD=P['CD0']+P['CDa']*alpha+P['CDde']*de;Cmp=P['Cm0']+P['Cma']*alpha+P['Cmq']*qh+P['Cmde']*de;L0=QS*CLp;D=QS*CD;X0=L0*sa-D*ca+P['thrust'];Z0=(-L0)*ca-D*sa
 ud0=X0/P['m']-P['g']*math.sin(th)-q*w;wd0=Z0/P['m']+P['g']*math.cos(th)+q*u;K=QS*P['CLadot']*ac/P['m'];adot=((u*wd0-w*ud0)/(V*V))/(1.+K/V);dL=QS*P['CLadot']*ac*adot;M=QS*P['cbar']*(Cmp+P['Cmadot']*ac*adot)
 return [ud0+dL*sa/P['m'],wd0-dL*ca/P['m'],M/P['Iy'],q]
def simulate(plant):
 out={};labels={}
 tr=poison if plant=='s9' else base
 ts=tr['state'].copy()
 if plant=='s4':
  a=base['alpha']+.01;ts=[base['P']['u0']*math.cos(a),base['P']['u0']*math.sin(a),0.,a]
 for rn,r in rows.items():
  kq,dt,dec,cad,frames=r[:5];dec,cad,frames=int(dec),int(cad),int(frames);s=[v+a-b for v,a,b in zip(r[5:],ts,base['state'])]
  if plant=='s1':kq=-kq
  if plant=='s2':kq=0.
  seed=0. if plant=='s17' else s[2];model=Model(seed);gain=0.;toggles=0;eng=[];ls=[]
  P=tr['P'];de=tr['de']
  for n in range(1,frames+1):
   def d(st):return deriv(st,de+gain*st[2],P)
   k1=d(s)
   if plant=='s3':s=[a+dt*b for a,b in zip(s,k1)]
   else:
    k2=d([a+.5*dt*b for a,b in zip(s,k1)]);k3=d([a+.5*dt*b for a,b in zip(s,k2)]);k4=d([a+dt*b for a,b in zip(s,k3)])
    s=[s[i]+dt/6.*(k1[i]+2.*k2[i]+2.*k3[i]+k4[i]) for i in range(4)]
   if n%cad==0:
    label,_=model.step(s[2])
    if plant=='s7':label='stable'
    if plant=='s12':label='oscillating'
    if plant=='s18':label='converged' if len(ls)%2==0 else 'equilibrium'
    if plant=='s19':label='improving'
    newgain=kq if label=='oscillating' else 0.;toggles+=newgain!=gain;gain=newgain;ls.append(label)
   if n%dec==0:eng.append(gain)
  prefix=rn.removesuffix('.run');cnt=collections.Counter(ls)
  for label,abbr in [('oscillating','osc'),('diverging','div'),('converged','conv'),('stable','stable'),('moving','moving'),('improving','improving'),('equilibrium','equil')]:out[prefix+'.'+abbr]=cnt[label]
  out[prefix+'.seed']=seed;out[prefix+'.reads']=len(ls)
  oi=[i for i,v in enumerate(ls) if v=='oscillating']
  out[prefix+'.at']=out[prefix+'.onset']=oi[0] if oi else -1
  out[prefix+'.horizon']=oi[-1] if oi else -1
  out[prefix+'.runs']=sum(i==0 or ls[i]!=ls[i-1] for i in range(len(ls)))
  out[prefix+'.maxrun']=max(len(list(g)) for _,g in itertools.groupby(ls))
  for label,abbr in [('diverging','didx'),('converged','cidx'),('oscillating','oidx')]:out[prefix+'.'+abbr]=sum(i for i,x in enumerate(ls) if x==label)
  out[prefix+'.engagements']=toggles
  out[prefix+'.first_engaged']=next((i for i,x in enumerate(eng) if x),-1)
  if prefix=='C4.ph':out['C5.p2.sup.toggles']=toggles
  labels[rn]=ls
 out['C5.p1.inner.converged']=out['C5.p1.inner.conv'];out['C5.p1.inner.diverging']=out['C5.p1.inner.div'];out['C5.p1.inner.equilibrium']=out['C5.p1.inner.equil']
 return out,labels
if __name__=='__main__':
 metrics,ls=simulate('base');diff=[k for k in ls if ls[k]!=actual[k]]
 print('independent controlled RK4 + predicates:',sum(map(len,ls.values())),'samples;',len(diff),'differing streams',flush=True)
 if diff:print([(k,[(i,a,b) for i,(a,b) in enumerate(zip(ls[k],actual[k])) if a!=b][:5]) for k in diff]);sys.exit(1)
 Path('.scratch/evidence/ap-sim-base.json').write_text(json.dumps(metrics,indent=2))
 for plant in ['s1','s2','s3','s4','s9','s17']:
  metrics,_=simulate(plant);Path('.scratch/evidence/ap-sim-'+plant+'.json').write_text(json.dumps(metrics,indent=2));print('derived',plant,flush=True)
