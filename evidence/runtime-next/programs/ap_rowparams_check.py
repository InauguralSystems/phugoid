"""Compare supervisory input identities, including conditioned trim rounding.
Only the final four solved-state components have a forward-error allowance;
all controls, cadences, times, amplitudes and populations remain exact.
"""
import sys
from decimal import Decimal, InvalidOperation
from pathlib import Path
BOUNDS = list(map(Decimal, ('2e-13','1e-11','0','4e-14')))
def parse(text, manifest=False):
    rows={}
    for line in text.splitlines():
        if manifest:
            if not line.startswith('rowparams '):continue
            line=line.removeprefix('rowparams ')
        name, fields=line.split()
        if name in rows or not fields.startswith('params='):raise ValueError('duplicate/malformed row')
        values=[Decimal(v) for v in fields[7:].split('|')]
        if len(values)<8 or not all(v.is_finite() for v in values):raise ValueError('invalid parameters')
        rows[name]=values
    if not rows:raise ValueError('empty population')
    return rows
def compare(a,b):
    if a.keys()!=b.keys():return False
    for k,v in a.items():
        w=b[k]
        if len(v)!=len(w) or v[:-4]!=w[:-4]:return False
        if any(abs(x-y)>eps for x,y,eps in zip(v[-4:],w[-4:],BOUNDS)):return False
    return True
if __name__=='__main__':
    if sys.argv[1:]==['--selftest']:
        a={'x':[Decimal(0)]*8}
        assert compare(a,a)
        for i in range(8):
            b={'x':a['x'].copy()};b['x'][i]=Decimal('1e-6')
            assert not compare(a,b),i
        assert not compare(a,{})
        assert not compare(a,{'y':a['x']})
        for text in ['x params=0|0|0|0|0|0|0|nan','x params=0|0|0|0|0|0|0|0\nx params=0|0|0|0|0|0|0|0']:
            try:parse(text)
            except ValueError:pass
            else:raise AssertionError('invalid row accepted')
        print('PASS: input identity: exact controls, bounded trim, missing/duplicate/nonfinite controls')
    else:
        try:ok=compare(parse(Path(sys.argv[1]).read_text(),True),parse(Path(sys.argv[2]).read_text()))
        except (ValueError,InvalidOperation):ok=False
        sys.exit(0 if ok else 1)
