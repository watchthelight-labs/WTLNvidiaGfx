#!/usr/bin/env python3
# Splits out/undefined.txt into symbols the macOS kernel already exports (with the bundle that exports them) and the
# ones XeGfx must implement itself. Uses Bash's kcabi reader on the boot kernel collection, and saves what it read per
# macOS build. NO_LINKCHECK=1 works from that saved list alone: no kernel collection is read while an XeGfx kext is
# loaded (I-116), and a symbol the list does not know stops the build.
import json, os, subprocess, sys
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
BUILD = subprocess.run(["sw_vers", "-buildVersion"], capture_output=True, text=True).stdout.strip() or "unknown"
CACHE = os.path.join(os.environ.get("XEGFX_KPI_CACHE", os.path.expanduser("~/.cache/xegfx")), f"kpi-{BUILD}.json")
want = [line.split()[1] for line in open(os.path.join(ROOT, "out/undefined.txt"))]
if os.environ.get("NO_LINKCHECK"):
    if not os.path.exists(CACHE):
        sys.exit(f"STOP: NO_LINKCHECK needs {CACHE}; run tools/link.sh once without it when no XeGfx kext is loaded")
    c = json.load(open(CACHE))
    exp = c["exported"]
    new = [] if c["full"] else [s for s in want if s not in exp and s not in c["absent"]]
    if new:
        sys.exit("STOP: not in the saved export list, the kernel collection has to be read for: " + " ".join(new))
else:
    sys.path.insert(0, os.path.expanduser("~/src/kcabi"))
    import kcfile, linkcheck
    exp = linkcheck.exported(kcfile.KC("/System/Library/KernelCollections/BootKernelExtensions.kc"))
    os.makedirs(os.path.dirname(CACHE), exist_ok=True)
    json.dump({"build": BUILD, "full": True, "exported": exp, "absent": []}, open(CACHE, "w"))
# XNU exports some names FreeBSD also uses with another ABI (eventhandler_*, selrecord, ...): a name binds to XNU
# only when tools/xnu-allow.txt lists it as checked
allow = {l.strip() for l in open(os.path.join(ROOT, "tools/xnu-allow.txt")) if l.strip()}
have, todo, clash = [], [], []
for line in open(os.path.join(ROOT, "out/undefined.txt")):
    n, sym = line.split()
    if sym in exp and sym[1:] in allow:
        have.append((int(n), sym, exp[sym]))
    elif sym in exp and not sym[1:].startswith("xg_"):
        clash.append((int(n), sym, exp[sym]))
    else:
        todo.append((int(n), sym, ""))
open(os.path.join(ROOT, "out/kpi-clash.txt"), "w").write("".join(f"{s} {o}\n" for _, s, o in clash))
if clash:
    print("ABI CHECK NEEDED (exported by XNU, not on tools/xnu-allow.txt): " + " ".join(s for _, s, _ in clash))
open(os.path.join(ROOT, "out/kpi-have.txt"), "w").write("".join(f"{s} {o}\n" for _, s, o in have))
open(os.path.join(ROOT, "out/kpi-todo.txt"), "w").write("".join(f"{n} {s}\n" for n, s, _ in todo))
print(f"exported by macOS: {len(have)}   to implement: {len(todo)}")
