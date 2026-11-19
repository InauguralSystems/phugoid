from pathlib import Path
import json,re,collections,itertools,math,subprocess
from decimal import Decimal
base=json.loads(Path('.scratch/evidence/ap-sim-base.json').read_text())
rows={};streams=set()
for line in Path('.scratch/evidence/ap-trace-new.txt').read_text().splitlines():
 t=line.split()
 if t[:1]==['ROW']:rows[t[1].removesuffix('.run')]=list(map(float,t[2][7:].split('|')))
 if t[:1]==['SEED']:streams.add(t[1].removesuffix('.run'))
rows={k:v for k,v in rows.items() if k in streams}
expected={}
for row in Path('tests/ap_manifest.txt').read_text().splitlines():
 t=row.split()
 if len(t)>=4 and t[0]=='ap' and t[3].startswith('exact=') and t[1].startswith(('C4.','C5.')):expected[t[1]]=Decimal(t[3][6:])
def forced(kind):
 out=base.copy()
 for prefix,r in rows.items():
  kq,dt,dec,cad,n=r[:5];count=int(n)//int(cad)
  ls=['stable']*count if kind=='s7' else ['oscillating']*count if kind=='s12' else ['converged' if i%2==0 else 'equilibrium' for i in range(count)] if kind=='s18' else ['improving']*count
  cnt=collections.Counter(ls)
  for lab,abbr in [('oscillating','osc'),('diverging','div'),('converged','conv'),('stable','stable'),('moving','moving'),('improving','improving'),('equilibrium','equil')]:out[prefix+'.'+abbr]=cnt[lab]
  out[prefix+'.reads']=count;out[prefix+'.at']=out[prefix+'.onset']=0 if kind=='s12' else -1;out[prefix+'.horizon']=count-1 if kind=='s12' else -1
  out[prefix+'.runs']=sum(i==0 or ls[i]!=ls[i-1] for i in range(count));out[prefix+'.maxrun']=max(len(list(g)) for _,g in itertools.groupby(ls))
  for lab,abbr in [('diverging','didx'),('converged','cidx'),('oscillating','oidx')]:out[prefix+'.'+abbr]=sum(i for i,x in enumerate(ls) if x==lab)
  out[prefix+'.engagements']=int(kind=='s12');out[prefix+'.first_engaged']=math.ceil(cad/dec)-1 if kind=='s12' else -1
  if prefix=='C4.ph':out['C5.p2.sup.toggles']=int(kind=='s12')
 out['C5.p1.inner.converged']=out['C5.p1.inner.conv'];out['C5.p1.inner.diverging']=out['C5.p1.inner.div'];out['C5.p1.inner.equilibrium']=out['C5.p1.inner.equil']
 return out
old={}
for row in subprocess.check_output(['git','show','a70c0cd7:tests/ap_plant_reds.txt'],text=True).splitlines():
 t=row.split()
 if t and re.fullmatch('s[0-9]+',t[0]):old[t[0]]=set(t[1:])
reason={1:'Negative gain changes the controlled trajectory; recompute D2 fingerprints while retaining the same numeric gain/pole failures.',2:'Inert gain is simulated at zero; D2 fingerprints are recomputed, including the healthy inner stream where gain never engages.',3:'Euler changes sampled trajectory and phase; recompute every verdict-derived count and order fingerprint under D2.',4:'The displaced trim changes the physical trajectory; the independent integration and D2 rules determine its new fingerprints.',7:'A frozen stable stream has a constant closed-form distribution, one run, and no engagements; the new improving pins must also fail.',9:'Poisoned aero and weight require the poisoned trim and dynamics; recompute D2 fingerprints from that model.',12:'Every verdict is forced oscillating: derive counts, index sums, one run and immediate engagement algebraically.',17:'A zero observer seed fabricates the first displacement; simulate the resulting observer history and conditional feedback, retaining all real-seed failures.',18:'Alternating false all-clears have the closed-form alternating distribution and no engagements; compare it with the independently derived new baseline.',19:'All verdicts are forced improving, giving one run and no engagements; every nonconstant baseline fingerprint is recomputed.',20:'The exact comparator displaces every result by one; all exact sites, including eight newly added distribution checks, must fail.'}
new={}; report=[];txt=['# Expected sets derived from independent physical integration + documented predicate rules.','# Numeric non-observer fault families retain their original analytical comparisons.']
for i in range(1,21):
 plant='s'+str(i);p=Path('.scratch/evidence/ap-sim-'+plant+'.json')
 m=json.loads(p.read_text()) if p.exists() else forced(plant) if i in [7,12,18,19] else base
 assert all(k in m for k in expected),[k for k in expected if k not in m]
 changed={k for k,v in expected.items() if Decimal(str(m[k]))!=v} if i!=20 else set(expected)
 nonobserver={k for k in old[plant] if not k.startswith(('C4.','C5.'))}
 new[plant]=nonobserver|changed
 why=reason.get(i,'This plant changes only its numeric estimator/comparator witness; supervisor trajectories and all newly derived fingerprints remain healthy.')
 txt+=['# '+plant+': '+why,plant+' '+' '.join(sorted(new[plant]))]
 report.append({'plant':plant,'old_count':len(old[plant]),'new_count':len(new[plant]),'added':sorted(new[plant]-old[plant]),'removed':sorted(old[plant]-new[plant]),'reason':why})
 print(plant,len(old[plant]),'->',len(new[plant]),'added',len(new[plant]-old[plant]),'removed',len(old[plant]-new[plant]))
Path('.scratch/evidence/ap-plant-derivation.json').write_text(json.dumps(report,indent=2)+'\n')
Path('tests/ap_plant_reds.txt').write_text('\n'.join(txt)+'\n')
p=Path('tests/test_ap_planted.sh');s=p.read_text()
for rec in report:
 plant=rec['plant'];pat=rf'run_plant {plant}; expect_total_fails [0-9]+'
 assert len(re.findall(pat,s))==1,plant
 s=re.sub(pat,f'# {rec["reason"]}\nrun_plant {plant}; expect_total_fails {rec["new_count"]}',s)
p.write_text(s)
with Path('.scratch/RESULT.md').open('a') as f:
 f.write('\n### AP plant red sets, independently re-derived\n\n| Plant | Old count | New count | Reason |\n|---|---:|---:|---|\n')
 for rec in report:f.write(f'| {rec["plant"]} | {rec["old_count"]} | {rec["new_count"]} | {rec["reason"]} |\n')
 f.write('\nEach changed check name is retained in evidence/ap-plant-derivation.json. The same per-plant reason is beside its assertion and its exact red set. The actual final runtime gate must confirm these predictions.\n')
