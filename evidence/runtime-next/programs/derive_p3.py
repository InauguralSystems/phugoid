from pathlib import Path
import json, math, sys,re
sys.path.insert(0,'.scratch');from predicate_model import Model
tr=json.loads(Path('.scratch/evidence/residual-new.txt').read_text().splitlines()[-1]);P=tr['P'];s0=tr['state']
def deriv(s):
 u,w,q,th=s;V=math.sqrt(u*u+w*w);alpha=math.atan2(w,u);QS=.5*P['rho']*V*V*P['S'];ac=P['cbar']/(2.*V);qh=q*ac;ca=math.cos(alpha);sa=math.sin(alpha)
 CLp=P['CL0']+P['CLa']*alpha+P['CLq']*qh+P['CLde']*tr['de'];CD=P['CD0']+P['CDa']*alpha+P['CDde']*tr['de'];Cmp=P['Cm0']+P['Cma']*alpha+P['Cmq']*qh+P['Cmde']*tr['de'];L0=QS*CLp;D=QS*CD;X0=L0*sa-D*ca+P['thrust'];Z0=(-L0)*ca-D*sa
 ud0=X0/P['m']-P['g']*math.sin(th)-q*w;wd0=Z0/P['m']+P['g']*math.cos(th)+q*u;K=QS*P['CLadot']*ac/P['m'];adot=((u*wd0-w*ud0)/(V*V))/(1.+K/V);dL=QS*P['CLadot']*ac*adot;M=QS*P['cbar']*(Cmp+P['Cmadot']*ac*adot)
 return [ud0+dL*sa/P['m'],wd0-dL*ca/P['m'],M/P['Iy'],q]
def rk(s):
 dt=.05;k1=deriv(s);k2=deriv([a+.5*dt*b for a,b in zip(s,k1)]);k3=deriv([a+.5*dt*b for a,b in zip(s,k2)]);k4=deriv([a+dt*b for a,b in zip(s,k3)])
 return [s[i]+dt/6.*(k1[i]+2.*k2[i]+2.*k3[i]+k4[i]) for i in range(4)]
traces={}
for ac in [0,1]:
 for sp in [.02,.05]:
  s=s0.copy();s[2]+=sp*math.sin(.5+ac*.7);xs=[s[2]]
  for _ in range(8000):s=rk(s);xs.append(s[2])
  traces[ac,sp]=xs
output=[]
for name,scale in [('rad',1.),('deg',57.29577951308232),('mrad',1000.)]:
 for ac in [0,1]:
  for sp in [.02,.05]:
   for cad in [74,84,94,104,114,124,134,148]:
    xs=traces[ac,sp];m=Model(xs[0]*scale);v=dict.fromkeys(['conv','osc','moving','stable','equil','improving','diverging','other','full','fosc','fquiet','fnoclaim','fother'],0);rd=0
    for i in range(cad,8001,cad):
     label,_=m.step(xs[i]*scale);rd+=1;key={'converged':'conv','oscillating':'osc','equilibrium':'equil'}.get(label,label);v[key]+=1
     if rd>=10:
      v['full']+=1;v['fosc' if label=='oscillating' else 'fquiet' if label in ['converged','stable','equilibrium'] else 'fnoclaim' if label=='moving' else 'fother']+=1
    output.append(f'p3 unit={name} ac={ac} sp={sp} cad={cad} reads={rd} '+' '.join(f'{k}={a}' for k,a in v.items()))
Path('.scratch/evidence/p3-derived-rows.txt').write_text('\n'.join(output)+'\n')
actual=[r for r in Path('.scratch/evidence/p3-original-new.txt').read_text().splitlines() if r.startswith('p3 unit=')]
diff=[(a,b) for a,b in zip(output,actual) if a!=b]
print('independent RK4 + predicate model:',len(output),'rows;',len(diff),'differences from full NEW producer');print(diff[:3])
Path('.scratch/evidence/p3-model-diff.json').write_text(json.dumps(diff,indent=2))
monos=[];mdiff=[]
for row in Path('.scratch/evidence/p3-original-new.txt').read_text().splitlines():
 if not row.startswith('p3mono kind='):continue
 p=dict(x.split('=') for x in row.split()[1:]);kind=p['kind'];name=p['unit'];cad=int(p['cad']);scale={'rad':1.,'deg':57.29577951308232,'mrad':1000.}[name];amp=.02643;rs=12345.;t=0.
 v0=amp if kind.startswith('decay_') else 0. if kind=='ramp' else amp/2.*((rs/65537.)*2.-1.)
 m=Model(v0*scale);cnt=dict.fromkeys(['full','fosc','conv','stable','moving','improving','diverging','equil'],0);rd=0
 for f in range(8000):
  if f%cad==cad-1:
   a=amp*math.exp(-t/350.) if kind=='decay_slow' else amp*math.exp(-t/90.) if kind=='decay_fast' else amp*(t/400.) if kind=='ramp' else (amp/2.)*(((rs/65537.)*2.)-1.)
   label,_=m.step(a*scale);rd+=1
   if rd>=11:
    cnt['full']+=1
    key={'oscillating':'fosc','converged':'conv','equilibrium':'equil'}.get(label,label);cnt[key]+=1
  rs=(rs*75.+74.)%65537.;t+=.05
 mono=f'p3mono kind={kind} unit={name} cad={cad} '+' '.join(f'{k}={cnt[k]}' for k in ['full','fosc','conv','stable','moving','improving','diverging','equil']);monos.append(mono)
 if any(str(cnt[k])!=v for k,v in p.items() if k in cnt):mdiff.append((row,mono))
Path('.scratch/evidence/p3-derived-mono.txt').write_text('\n'.join(monos)+'\n')
print('independent controls:',len(monos),'rows;',len(mdiff),'differences on original producer fields');print(mdiff[:2])
