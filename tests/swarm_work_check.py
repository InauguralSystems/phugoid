#!/usr/bin/env python3
"""Untimed stored-work witnesses from the actual, identity-pinned arm bodies.

Derived copies and receipts stay outside the repository. No hook is added to
timed runs or the genuinely unarmed control. This is not a cost measurement.
"""
import hashlib
import json
import math
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parent.parent
FILES = ("swarm.eigs", "sim_core.eigs", "sim.eigs", "data/b747_approach.eigs",
         "tests/swarm_profile.eigs", "eigs.json")
ARMS = ("ceiling", "disciplined", "floor", "ceiling0", "ceiling0pb")
DIGEST = {1: 279590118, 4: 1119436234, 16: 4466955440}
HITS = {1: 0, 4: 5974, 16: 21126}
INTEGRATE = "fleet is frame_step of [fleet, t, dt, sched, P]\n"
QOBS = "local qobs is fleet[i][2] + 0.0\n"
PREDICATE = "            if oscillating of qobs:\n"
RETURN = "    return [ud, wd, M / P.Iy, q]\n"
SHA = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()


def require(ok, name):
    if not ok:
        raise AssertionError(name)


def once(text, old, new):
    require(text.count(old) == 1, "source-boundary: " + old.strip())
    return text.replace(old, new)


def body(text, name):
    pattern = rf"(?m)^define {name}\([^\n]+\) as:\n.*?(?=^define |\Z)"
    found = list(re.finditer(pattern, text, re.S | re.M))
    require(len(found) == 1, "unique-arm: " + name)
    return found[0]


def change(text, name, transform):
    m = body(text, name)
    return text[:m.start()] + transform(m.group()) + text[m.end():]


def elide_assignment(arm, needle):
    rows = arm.splitlines(True)
    matches = [i for i, row in enumerate(rows) if row.lstrip() == needle]
    require(len(matches) == 1, "unique-assignment: " + needle.strip())
    i = matches[0]
    indent = rows[i][:len(rows[i]) - len(rows[i].lstrip())]
    rows[i] = indent + "unobserved:\n" + "    " + rows[i]
    return "".join(rows)


def gut(arm, condition):
    # Original N-scoped shape: same integration/read/population, no fold or
    # predicate work in the selected branch. The healthy branch is untouched.
    require(arm.count("        local i is 0\n") == 1 and
            arm.count("        t is t + dt\n") == 1, "gut.unique-loop")
    a = arm.index("        local i is 0\n")
    b = arm.index("        t is t + dt\n", a)
    original = arm[a:b]
    replacement = """            unobserved:
                local i is 0
                loop while i < n:
                    local qobs is fleet[i][2] + 0.0
                    reads is reads + 1
                    evals is evals + 1
                    i is i + 1
"""
    return arm[:a] + f"        if {condition}:\n" + replacement + "        else:\n" + \
        "".join("    " + row if row.strip() else row for row in original.splitlines(True)) + arm[b:]


def instrument(swarm, core, driver):
    # Dictionary mutation crosses module boundaries without rebinding globals.
    core = once(core, "define deriv(s, de, P) as:\n", """unobserved:
    fold_work is {"active": 0, "vc": 0, "vf": 0, "vz": 0, "vb": 0, "qc": 0, "qf": 0, "qz": 0, "qb": 0}
define deriv(s, de, P) as:
""")
    hook = """    unobserved:
        if fold_work.active:
            local work_v is trajectory of V
            fold_work.vc is fold_work.vc + 1
            if work_v.last_entropy > 0 and (len of work_v.dh) == 0 and (len of work_v.raw) == 0:
                fold_work.vf is fold_work.vf + 1
            elif work_v.last_entropy == 0 and (len of work_v.dh) == 0 and (len of work_v.raw) == 0:
                fold_work.vz is fold_work.vz + 1
            else:
                fold_work.vb is fold_work.vb + 1
"""
    core = once(core, RETURN, hook + RETURN)
    # Place one final-frame hook after each actual qobs read/predicate loop,
    # preserving its indentation, including the floor's unobserved scope.
    for name in ("run_ceiling", "run_disciplined", "run_floor"):
        def add(arm):
            rows = arm.splitlines(True)
            sites = [i for i, row in enumerate(rows) if row.lstrip() == "i is i + 1\n"]
            require(len(sites) in ((1, 2) if name == "run_ceiling" else (1,)), "qobs-loop: " + name)
            # Gutting produces two mutually exclusive qobs loops.
            for i in reversed(sites):
                indent = rows[i][:len(rows[i]) - len(rows[i].lstrip())]
                qhook = """if f == frames - 1:
    unobserved:
        local work_q is trajectory of qobs
        fold_work.qc is fold_work.qc + 1
        if work_q.last_entropy > 0 and (len of work_q.dh) == 10 and (len of work_q.raw) == 10:
            fold_work.qf is fold_work.qf + 1
        elif work_q.last_entropy == 0 and (len of work_q.dh) == 0 and (len of work_q.raw) == 10:
            fold_work.qz is fold_work.qz + 1
        else:
            fold_work.qb is fold_work.qb + 1
"""
                rows[i] = "".join(indent + row for row in qhook.splitlines(True)) + rows[i]
            return "".join(rows)
        swarm = change(swarm, name, add)
    driver = once(driver, 'if arm == "ceiling":\n', 'unobserved:\n    fold_work.active is 1\nif arm == "ceiling":\n')
    driver += '\nprint of f"WORK {fold_work.vc} {fold_work.vf} {fold_work.vz} {fold_work.vb} {fold_work.qc} {fold_work.qf} {fold_work.qz} {fold_work.qb}"\n'
    return swarm, core, driver


def verdict(output, arm, n, positive=False, disabled=()):
    # Every failure is attributable. Physics is checked before stored work.
    require(arm in ARMS and n in DIGEST, "population.classification")
    frames, digest = (150, 280833547) if positive else (1500, DIGEST[n])
    rows = [r for r in output.splitlines() if r.startswith(arm + " ")]
    require(len(rows) == 1, "population.arm-row")
    values = [int(x) for x in rows[0].split()[1:]]
    want_hits = 1 if positive else HITS[n] if arm in ("ceiling", "disciplined") else 0
    evals = n * frames if arm in ("ceiling", "disciplined") else 0
    require(values[:2] == [n, frames] and values[3:] == [digest, n * frames, evals], "physics.bank")
    summaries = [r for r in output.splitlines() if r.startswith("profiled ")]
    require(summaries == [f"profiled {arm} n={n} digest={digest}"], "population.dispatch")
    if "query" not in disabled:
        require(values[2] == want_hits, "semantic.query")
    rows = [r for r in output.splitlines() if r.startswith("WORK ")]
    require(len(rows) == 1, "population.work-row")
    v = [int(x) for x in rows[0].split()[1:]]
    require(len(v) == 8, "population.work-fields")
    observed_v = arm in ("ceiling", "ceiling0")
    want_v = [4 * n * frames, 4 * n * frames if observed_v else 0,
              0 if observed_v else 4 * n * frames, 0]
    if "integration" not in disabled:
        require(v[:4] == want_v, "semantic.integration-fold")
    observed_q = arm in ("ceiling", "disciplined")
    want_q = [n, n if observed_q else 0, 0 if observed_q else n, 0] if arm in ARMS[:3] else [0] * 4
    if "qobs" not in disabled:
        require(v[4:] == want_q, "semantic.qobs-fold")
    return v


def main():
    exe = shutil.which(os.environ.get("EIGENSCRIPT", "eigenscript"))
    require(exe is not None, "runtime.executable")
    exe = str(Path(exe).resolve())
    out = Path(os.environ["PHUGOID_WORK_ARTIFACTS"]) if "PHUGOID_WORK_ARTIFACTS" in os.environ else Path(tempfile.mkdtemp(prefix="phugoid-work-"))
    out.mkdir(parents=True, exist_ok=True)
    require(not any(out.iterdir()), "artifacts.must-be-empty")
    pins = {f: SHA(ROOT / f) for f in FILES}
    # Reuse the timed gate's declared identities, not another set of pins.
    gate = (ROOT / "tests/test_swarm_profile.sh").read_text()
    for f in FILES[:-1]:
        code = [r for r in (ROOT / f).read_text().splitlines() if r.strip() and not r.lstrip().startswith("#")]
        if f == "tests/swarm_profile.eigs":
            hs = re.findall(r"(?m)^PROFILE_HASH=([0-9a-f]{12})$", gate)
            ns = re.findall(r"(?m)^PROFILE_LINES=([0-9]+)$", gate)
        else:
            declared = re.findall(r"(?m)^file_pin " + re.escape(f) + r" +([0-9a-f]{12}) +([0-9]+)$", gate)
            require(len(declared) == 1, "identity.declaration." + f)
            hs, ns = [declared[0][0]], [declared[0][1]]
        require(len(hs) == len(ns) == 1, "identity.declaration." + f)
        require(len(code) == int(ns[0]) and hashlib.md5(("\n".join(code) + "\n").encode()).hexdigest()[:12] == hs[0], "identity.source." + f)
    source = [(ROOT / f).read_text() for f in ("swarm.eigs", "sim_core.eigs", "tests/swarm_profile.eigs")]
    env = {k: v for k, v in os.environ.items() if not k.startswith("EIGS_")}
    tier = os.environ.get("EIGS_JIT_OFF", "0")
    require(tier in ("0", "1"), "runtime.tier")
    env.update(EIGS_STRICT="1")
    receipt = {"purpose": "untimed actual-source stored-work acceptance", "runtime": exe,
               "runtime_sha256": SHA(Path(exe)), "source_sha256": pins, "runs": []}

    def run(label, texts, arm, n, jit):
        d = out / label
        d.mkdir()
        for f in FILES:
            p = d / f
            p.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / f, p)
        for f, txt in zip(("swarm.eigs", "sim_core.eigs", "tests/swarm_profile.eigs"), texts):
            (d / f).write_text(txt)
        p = subprocess.run([exe, "tests/swarm_profile.eigs", arm, str(n)], cwd=d,
                           env=dict(env, EIGS_JIT_OFF=jit), capture_output=True, timeout=180)
        (d / "stdout").write_bytes(p.stdout)
        (d / "stderr").write_bytes(p.stderr)
        receipt["runs"].append({"label": label, "arm": arm, "n": n, "jit_off": jit,
                                "rc": p.returncode, "files": {f: SHA(d / f) for f in FILES}})
        (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
        require(p.returncode == 0, "execution." + label)
        return p.stdout.decode()

    def ordinary(s):
        return "\n".join(r for r in s.splitlines() if not r.startswith(("WORK ", "STATE ")))

    def calibrate(label, texts, n, expected, disabled, positive=False, jit=tier, arm="ceiling"):
        output = run(label, instrument(*texts), arm, n, jit)
        try:
            verdict(output, arm, n, positive)
        except AssertionError as e:
            require(str(e) == expected, "calibration.named-red." + label + ": " + str(e))
        else:
            raise AssertionError("calibration.required-red." + label)
        # Use the SAME checker and retained real output. Only the named new
        # witness is disabled; physics and all other witnesses still enforce.
        verdict(output, arm, n, positive, disabled)
        print(f"PASS calibration {label}: {expected}; disabled witness exposes missing enforcement", flush=True)

    print("stored-work artifacts: " + str(out), flush=True)
    for n in (1, 4, 16):
        for arm in ARMS:
            plain = run(f"plain-{arm}-{n}", source, arm, n, tier)
            hooked = run(f"work-{arm}-{n}", instrument(*source), arm, n, tier)
            require(ordinary(plain) == ordinary(hooked), f"instrumentation.stdout.{arm}.{n}")
            counts = verdict(hooked, arm, n)
            print(f"PASS stored-work {arm} N={n} counts={counts}", flush=True)
        for kind, needle, name in (("qobs", QOBS, "semantic.qobs-fold"),
                                   ("integration", INTEGRATE, "semantic.integration-fold")):
            changed = change(source[0], "run_ceiling", lambda arm: elide_assignment(arm, needle))
            calibrate(f"{kind}-elided-{n}", [changed, *source[1:]], n, name, (kind,))
    # Source-derived small-N and above-N1 gutting controls, before hooks.
    # These reproduce the documented historical conditions, not a claim
    # that an unretained historical mutant has the same exact source hash.
    # At N1 hits=0 so only stored qobs history exposes lost observation.
    # At N4/16 the old banked verdict witness still rejects the real gutting.
    for condition, ns in (("n < 8", (1, 4)), ("n > 1", (4, 16))):
        changed = change(source[0], "run_ceiling", lambda arm: gut(arm, condition))
        for n in ns:
            label = f"gut-{condition.replace(' ', '')}-{n}"
            disabled = ("qobs",) if n == 1 else ("qobs", "query")
            expected = "semantic.qobs-fold" if n == 1 else "semantic.query"
            calibrate(label, [changed, *source[1:]], n, expected, disabled)
    partial = change(source[0], "run_disciplined", lambda arm: once(arm,
        "        unobserved:\n            " + INTEGRATE,
        "        if f % 3 == 0:\n            " + INTEGRATE +
        "        else:\n            unobserved:\n                " + INTEGRATE))
    calibrate("disciplined-partial-observed-16", [partial, *source[1:]], 16,
              "semantic.integration-fold", ("integration",), arm="disciplined")
    positive_driver = once(source[2], "FRAMES is 1500\n", "FRAMES is 150\n")
    positive_driver = once(positive_driver, "DT is 0.0166667\n", "DT is 0.5\n")
    # Stored states are a bounded 150-row untimed calibration only, permitting
    # byte-exact physics comparison with the actual constant-false predicate.
    positive_swarm = change(source[0], "run_ceiling", lambda arm: once(arm, "        " + INTEGRATE,
        "        " + INTEGRATE + '        print of f"STATE {fleet[0][0]} {fleet[0][1]} {fleet[0][2]} {fleet[0][3]}"\n'))
    positive = [positive_swarm, source[1], positive_driver]
    originals = []
    for jit in ("1", "0"):
        plain = run("positive-plain-" + jit, positive, "ceiling", 1, jit)
        hooked = run("positive-work-" + jit, instrument(*positive), "ceiling", 1, jit)
        require(ordinary(plain) == ordinary(hooked), "positive.instrumentation.stdout")
        verdict(hooked, "ceiling", 1, True)
        states = [r for r in plain.splitlines() if r.startswith("STATE ")]
        require(len(states) == 150 and all(len(r.split()[1:]) == 4 and
                all(math.isfinite(float(x)) for x in r.split()[1:]) for r in states), "positive.physics-population")
        require(states == [r for r in hooked.splitlines() if r.startswith("STATE ")], "positive.instrumentation.physics")
        false = change(positive_swarm, "run_ceiling", lambda arm: once(arm, PREDICATE, "            if 0:\n"))
        calibrate("positive-false-" + jit, [false, source[1], positive_driver], 1,
                  "semantic.query", ("query",), True, jit)
        false_states = (out / ("positive-false-" + jit) / "stdout").read_text().splitlines()
        require(states == [r for r in false_states if r.startswith("STATE ")], "positive.false.physics")
        originals.append(plain)
    require(originals[0] == originals[1], "positive.VM-JIT.stdout")
    require(pins == {f: SHA(ROOT / f) for f in FILES}, "source.unchanged")
    receipt["complete"] = True
    receipt["source_unchanged"] = True
    (out / "receipt.json").write_text(json.dumps(receipt, indent=2) + "\n")
    print(f"PASS stored-work complete: 15 ladder shapes, 13 real fault controls, {len(receipt['runs'])} executions", flush=True)


if __name__ == "__main__":
    try:
        main()
    except (AssertionError, OSError, ValueError, subprocess.TimeoutExpired) as e:
        raise SystemExit("FAIL stored-work: " + str(e))
