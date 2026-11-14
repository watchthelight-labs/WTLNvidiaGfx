#!/bin/bash
# NvGfx: make an installable package from the shipped NullMoth pkgroot with our builds swapped in.
#   REF  = shipped pkgroot (default: the audited 2.9 package under tooling/quarantine)
#   OUT  = output pkgroot (default ~/src/NvGfx-build/pkg/<label>)
#   Components to swap are given as env vars pointing at built files (unset = keep shipped):
#     NVGFX_PLUGIN (NVMTLDriver), NVGFX_XLATE (libnvmtl_translate.dylib), NVGFX_NVK (libvulkan_nouveau.dylib),
#     NVGFX_NVRM, NVGFX_NVRMFB, NVGFX_NVACCEL15, NVGFX_NVACCEL26 (.kext bundles)
#   NVGFX_AUDIO=1 keeps the shipped NMXAudio.kext (left out by default)
#   NVGFX_FW_FROM=<pkgroot> carries NVIDIA's GSP firmware (Users/Shared/nvfw) from an older package: since 2.9 the shipped
#     package has none and its installer would download NVIDIA's 550 MB driver package. Every file is checked against the
#     pins in the package's own fw_fetch.sh first, and the files are added to SHA256SUMS.
# The result keeps install.sh/uninstall.sh as shipped except the two restarts (see below); SHA256SUMS, BASELINE-IDENTITY.json and NVGFX-VERSION are rewritten.
# <wtl> fork: nvgfx | author: watchthelight </wtl>
set -euo pipefail
LABEL=${1:?usage: package.sh <label, e.g. 2.1.0-nvgfx.1>}
REF=${REF:-$HOME/Hackintosh/tooling/quarantine/nullmoth-release-2.9/x/pkgroot}
OUT=${OUT:-$HOME/src/NvGfx-build/pkg/$LABEL}
R=$(cd "$(dirname "$0")/../.." && pwd)
rm -rf "$OUT"; mkdir -p "$(dirname "$OUT")"; mkdir -p "$OUT"
# 2.8 installs NMXAudio on macOS 26 whenever an HD Audio controller exists; the Legion already runs VoodooHDA on it.
AUDIO_SKIP=(); [ "${NVGFX_AUDIO:-0}" = 1 ] || AUDIO_SKIP=(--exclude ./Library/Extensions/NMXAudio.kext)
(cd "$REF" && tar cf - ${AUDIO_SKIP[@]+"${AUDIO_SKIP[@]}"} .) | (cd "$OUT" && tar xpf -)
if [ "${NVGFX_AUDIO:-0}" != 1 ] && grep -q ' Library/Extensions/NMXAudio\.kext/' "$OUT/SHA256SUMS"; then
  grep -v ' Library/Extensions/NMXAudio\.kext/' "$OUT/SHA256SUMS" > "$OUT/SHA256SUMS.new" && mv "$OUT/SHA256SUMS.new" "$OUT/SHA256SUMS"
  echo "left out NMXAudio.kext (NVGFX_AUDIO=1 keeps it)"
fi
# 2.9's fallback job (lastgood) and boot guard each end in `shutdown -r now`. Our gpu-guard owns restarts and rollbacks for a
# staged boot, so the package keeps the NVRAM bookkeeping and drops the two restarts (NVGFX_KEEP_UPSTREAM_RESTART=1 keeps them).
# The first sits in the unquoted heredoc that writes lastgood.sh (so $ stays escaped), the second in the quoted boot-guard one.
if [ "${NVGFX_KEEP_UPSTREAM_RESTART:-0}" != 1 ]; then
  [ "$(grep -c '^shutdown -r now$' "$OUT/install.sh")" = 1 ] && [ "$(grep -c '^        shutdown -r now$' "$OUT/install.sh")" = 1 ] \
    || { echo "FAIL install.sh restart lines changed upstream; re-read the boot guard"; exit 3; }
  sed -e 's|^shutdown -r now$|echo "\\$(date) restart left to the gpu-guard" >> \\$LOG|' \
      -e 's|^        shutdown -r now$|        echo "$(date) restart left to the gpu-guard" >> $LOG|' \
      "$OUT/install.sh" > "$OUT/install.sh.new" && chmod 755 "$OUT/install.sh.new" && mv "$OUT/install.sh.new" "$OUT/install.sh"
fi
B=$OUT/Library/GPUBundles/NVMTLDriver.bundle
swap_file() { [ -n "${1:-}" ] || return 0; cp "$1" "$2"; codesign -f -s - "$2" 2>/dev/null; echo "swapped $(basename "$2") <- $1"; }
swap_kext() { [ -n "${1:-}" ] || return 0; rm -rf "$2"; cp -Rp "$1" "$2"; echo "swapped $(basename "$2") <- $1"; }
swap_file "${NVGFX_PLUGIN:-}" "$B/Contents/MacOS/NVMTLDriver"
swap_file "${NVGFX_XLATE:-}" "$B/Contents/MacOS/libnvmtl_translate.dylib"
NVK_DST=$(cd "$OUT" && find . -name libvulkan_nouveau.dylib | head -1); [ -n "${NVGFX_NVK:-}" ] && swap_file "$NVGFX_NVK" "$OUT/$NVK_DST"
swap_kext "${NVGFX_NVRM:-}" "$OUT/Library/Extensions/NVRM.kext"
swap_kext "${NVGFX_NVRMFB:-}" "$OUT/Library/Extensions/NVRMFB.kext"
sign_kext() { [ -n "${1:-}" ] && codesign -f -s - --digest-algorithm=sha256 "$2" >/dev/null 2>&1 || true; }   # ad hoc, as the NVRM harness did
sign_kext "${NVGFX_NVRM:-}" "$OUT/Library/Extensions/NVRM.kext"; sign_kext "${NVGFX_NVRMFB:-}" "$OUT/Library/Extensions/NVRMFB.kext"
swap_kext "${NVGFX_NVACCEL15:-}" "$OUT/Library/Extensions/NVAccel.kext"
[ -d "$OUT/Library/NullMoth/kexts/15/NVAccel.kext" ] && swap_kext "${NVGFX_NVACCEL15:-}" "$OUT/Library/NullMoth/kexts/15/NVAccel.kext"
[ -d "$OUT/Library/NullMoth/kexts/26/NVAccel.kext" ] && swap_kext "${NVGFX_NVACCEL26:-}" "$OUT/Library/NullMoth/kexts/26/NVAccel.kext"
if [ -n "${NVGFX_FW_FROM:-}" ]; then
  FWV=$(sed -n 's/^VER=//p' "$OUT/fw_fetch.sh" | head -1)
  [ -n "$FWV" ] && [ -d "$NVGFX_FW_FROM/Users/Shared/nvfw/nvidia/$FWV" ] || { echo "FAIL no firmware $FWV under $NVGFX_FW_FROM/Users/Shared/nvfw"; exit 3; }
  mkdir -p "$OUT/Users/Shared/nvfw/nvidia"; cp -Rp "$NVGFX_FW_FROM/Users/Shared/nvfw/nvidia/$FWV" "$OUT/Users/Shared/nvfw/nvidia/"
  for f in "$OUT/Users/Shared/nvfw/nvidia/$FWV"/*; do
    pin=$(sed -n "s/^ *$(basename "$f") *) *echo \([0-9a-f]*\);;.*/\1/p" "$OUT/fw_fetch.sh")
    [ -n "$pin" ] && [ "$(shasum -a 256 "$f" | cut -d' ' -f1)" = "$pin" ] || { echo "FAIL firmware $(basename "$f") does not match the pin in fw_fetch.sh"; exit 3; }
    echo "0000000000000000000000000000000000000000000000000000000000000000  ${f#"$OUT"/}" >> "$OUT/SHA256SUMS"
  done
  echo "carried firmware $FWV from $NVGFX_FW_FROM (pins match)"
fi
codesign -f -s - "$B" 2>/dev/null   # the shipped bundle is ad-hoc signed as a bundle
printf '%s\nbase NullMoth %s, NvGfx %s\n' "$LABEL" "$(cat "$REF/VERSION")" "$(git -C "$R" rev-parse --short HEAD)" > "$OUT/NVGFX-VERSION"
# Rewrite the identity of the four paired kexts the same way the shipped file lists them, then every checksum.
[ ! -f "$OUT/BASELINE-IDENTITY.json" ] || /usr/bin/python3 -I - "$OUT" <<'PY'
import hashlib, json, os, sys
o = sys.argv[1]; p = os.path.join(o, "BASELINE-IDENTITY.json")
d = json.load(open(p))
for name, ent in d.get("paired_kexts", {}).items():
    f = os.path.join(o, "Library/Extensions", name + ".kext", "Contents/MacOS", name)
    if os.path.isfile(f):
        ent["sha256"] = hashlib.sha256(open(f, "rb").read()).hexdigest()
d["nvgfx"] = open(os.path.join(o, "NVGFX-VERSION")).read().strip() if os.path.exists(os.path.join(o, "NVGFX-VERSION")) else "nvgfx"
json.dump(d, open(p, "w"), indent=2)
PY
# The manifest lists "<hash>  <path>" (two spaces, no binary marker), one line per file; keep the path whole even with spaces.
# Rebuilt from the tree: the 2.9 installer refuses a package holding a file SHA256SUMS does not list (sums_complete.sh), and
# our swaps add files (NVGFX-VERSION, firmware, a kext's _CodeSignature) and drop others (the shipped kexts' signatures).
(cd "$OUT" && find . -type f ! -path ./SHA256SUMS ! -path ./SHA256SUMS.new | sed 's|^\./||' | LC_ALL=C sort | while IFS= read -r f; do shasum -a 256 "$f"; done > SHA256SUMS.new && mv SHA256SUMS.new SHA256SUMS)
[ ! -f "$OUT/sums_complete.sh" ] || bash "$OUT/sums_complete.sh" "$OUT" || exit 3
# 2.3.7's installer refuses absolute links, and from 2.3.7 the kexts read firmware from /Library/NullMoth/nvfw: an NVRM
# built for an older base finds none there (no display). Refuse both here instead of at install time.
abs=$(cd "$OUT" && find . -type l -exec sh -c 'case $(readlink "$1") in /*) echo "$1";; esac' _ {} \;)
[ -z "$abs" ] || { echo "FAIL absolute links in the package: $abs"; exit 3; }
fw_new=0; grep -q 'nvfw' "$OUT/install.sh" && grep -q '/Library/NullMoth/nvfw' "$OUT/install.sh" && fw_new=1
nvrm_new=0; [ "$(strings "$OUT/Library/Extensions/NVRM.kext/Contents/MacOS/NVRM" | grep -c '/Library/NullMoth/nvfw' || true)" -gt 0 ] && nvrm_new=1
[ "$fw_new" = "$nvrm_new" ] || { echo "FAIL NVRM firmware path does not match the installer (NVRM new path $nvrm_new, installer $fw_new)"; exit 3; }
(cd "$OUT" && shasum -a 256 --strict -c SHA256SUMS --quiet) && echo "package ok: $OUT"
