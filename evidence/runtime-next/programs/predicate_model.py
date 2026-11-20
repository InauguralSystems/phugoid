"""Finite numeric observer rules, independently evaluated on physical samples.
Uses the runtime's independent reveal reference for the unchanged settled/raw
rules and its registered Keras reference for the D2 boundedness definitions.
No labels or count banks are inputs to this model.
"""
import sys, math
sys.path.insert(0,'RUNTIME_CHECKOUT/tools')
import reveal_restored_reference as I
sys.path.insert(0,'RUNTIME_CHECKOUT/tools/observer_oracle')
import reference as R
class Model:
    def __init__(self, seed):
        self.w=[seed]; self.best=seed; self.since=100000
    def step(self,v):
        self.since+=1
        if v < self.best - .001*max(abs(self.best),.001):
            self.best=v; self.since=0
        self.w=(self.w+[v])[-11:]
        xs=self.w; c=len(xs)-1
        win=I._steps(xs,c,'branch'); fl=I._floor(win,v,'branch')
        rel=[r for r,d,e in win]; raw=[d for r,d,e in win]
        settled=I.classify(xs,c,'branch')
        flips=sum(a*b<0 and abs(a)>.001 and abs(b)>.001 for a,b in zip(rel,rel[1:]))
        nonzero=[d for d in raw if abs(d)>fl]
        reversals=sum(a*b<0 for a,b in zip(nonzero,nonzero[1:]))
        folded=c>=10 and not all(abs(r)<.001 for r in rel) and sum(map(abs,raw))>fl and reversals>=2 and abs(sum(raw))<=.3*sum(map(abs,raw))
        osc=(c>=3 and flips>=4) or I._raw_oscillating(win,fl) or folded
        div=I._raw_diverging(win,fl)
        imp=self.since<10 and not R.diverging(xs) and not (c>=10 and R._expanding(xs))
        signs=[d for d in raw if d!=0]
        trend=len(signs)>=2 and all(d*signs[0]>0 for d in signs)
        mean=sum(rel)/len(rel)
        var=sum((r-mean)**2 for r in rel)/len(rel)
        eq=c>=10 and not trend and not I._raw_oscillating(win,fl) and abs(mean)<.001 and var<.001**2
        pred=dict(settled, improving=imp, diverging=div,oscillating=osc,equilibrium=eq)
        for k in ['oscillating','diverging','improving']:
            if pred[k]: return k,pred
        if c>=10:
            for k in ['converged','equilibrium','stable']:
                if pred[k]: return k,pred
            return 'moving',pred
        return ('stable' if all(abs(r)<.01 for r in rel) else 'moving'),pred
