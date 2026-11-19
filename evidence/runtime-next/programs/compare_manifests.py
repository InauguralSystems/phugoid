from pathlib import Path
import re, subprocess
from decimal import Decimal
number = re.compile(r'(?<![A-Za-z_])[-+]?(?:\d+\.\d*|\.\d+|\d+)(?:[eE][-+]?\d+)?')
for fn in ['tests/sim_manifest.txt', 'tests/latsim_manifest.txt', 'tests/check_manifest.txt']:
    old = subprocess.check_output(['git', 'show', 'a70c0cd7:'+fn], text=True)
    new = Path(fn).read_text()
    a, b = [[Decimal(m[0]) for m in number.finditer(s)] for s in (old,new)]
    assert a == b and number.sub('@',old) == number.sub('@',new), fn
    print(fn, len(a), 'number tokens equal; nonnumeric text identical')
