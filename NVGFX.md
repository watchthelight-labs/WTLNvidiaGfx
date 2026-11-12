# NvGfx fork notes
<!-- <wtl> fork: nvgfx | author: watchthelight </wtl> -->

The `nvgfx-2.9` branch is NullMoth's 2.9 plus the few changes in the README table. This file is the index of what the fork adds, what NullMoth carries now, and the switches worth knowing. The reasoning behind each change is in `notes/`.

## Branches and versions

- `nvgfx-2.9` (rebase onto upstream 2.9, labels `2.9-nvgfx.N`; 2.9-nvgfx.1 compiles, NVRM matches the shipped 2.9 NVRM except the escape function, not booted): see the changelog. NullMoth 2.9 is the last 2.x, on NVIDIA 620.70.06.
- `nvgfx-2.8.1` (rebase onto 2.8.1, never booted, superseded by `nvgfx-2.9`).
- `nvgfx-2.6.2` (default until 2.9 has booted, booted 2026-10-27 as 2.6.2-nvgfx.1): the fork's changes on top of upstream 2.6.2,
  packages labelled `2.6.2-nvgfx.N`. Carries everything from `nvgfx-2.5.3`, adds the HiDPI flag on scaled modes (#354), the sampler restore (#363)
  and GeekAudio's translator PR #385 (MPS depthwise convolution).
- Older: `nvgfx-2.5.3`, `nvgfx-2.4.3`, `nvgfx-2.4.1`, `nvgfx-2.3.7`, `nvgfx-2.3.5` (each labelled `<base>-nvgfx.N`).
- `nvgfx`: our changes on top of the upstream 2.1.0 tag (`2.1.0-nvgfx.N`, last tested `2.1.0-nvgfx.20`). Kept for the
  trace tooling on `dock-trace`, the event-driven present path and the rollback.
- `main`: upstream as pulled.

## What 2.9 carries now, and what it still takes from the fork

Carried on `nvgfx-2.9`:

| Patch | Why it stays |
|---|---|
| `nvrmphysctl=1` escape (`nvrm_physctl.c`, `nvrm_physctl_abi.h`, the `NVRM_ESC_PHYS_CTRL` case in `NVRM.cpp`) | upstream has no generic "issue any RM control" entry on purpose; `nvgfx-smi --phys` and `--ctrl` need it for power and clock experiments |
| `nvgfx-smi`, `nvgfx-burn`, `nvgfx-boost` | our telemetry, load and boost tools; upstream's `nvmtl-smi` and `nvmtl-boost` are separate programs |
| `build/nvgfx/` (`build_plugin.sh`, `build_xlate.sh`, `package.sh`, `kextcmp/`, `nvrm/compare_nvrm.py`, `nvrm/codediff.py`) | repo-relative builds with the Command Line Tools and the checks against the shipped binaries; `package.sh` carries firmware over and lists every file in SHA256SUMS now |
| `-mfunction-return=thunk-extern` dropped in `build/build_kms620.sh` | the published script leaves it in; the resulting NVRM imports `___x86_return_thunk`, which XNU does not export |
| `nvrm_physctl.c` added to `build/build_nvrm.sh` | links the escape into NVRM, only where the source exists |

Dropped because NullMoth 2.9 has it (their `NOTICE` and changelog name the idea or the thanks):

| Fork patch | In 2.9 |
|---|---|
| NVRM power glue: `nvrmtgp`, `nvrmgps`, `nvrmnvpcf`, the notebook and battery answers | `nvrm_power.cpp`, `nvrm_pmgr.c`, `nvrm_dsm_route.h` (same boot-args; sysctls `debug.nvrm_tgp_*`, which replace `debug.nvgfx_tgp_*`; it also pauses across suspend) |
| Intel panel proxy head in NVRMFB (`nvfbigpu`, `nvfbigpucache`) | `kexts/NVRMFB/nvrm_igpu_proxy.h` and the same boot-args |
| boot hold ceiling (`nvrmholdcap`) | in NVRM since 2.5.2 (our PR 317) |
| sampler-variant memo, repeated-pipeline skip, `NVMTL_NO_SV_MEMO`, `NVMTL_NO_PSO_SKIP` | `plugin/nvmtl_repeat_bind.h`, same switches |
| shader cache I/O queue (`NVMTL_CACHE_SYNC_IO`), WindowServer cache fallback folder | in the plugin already in 2.8.1 (commit 67a21ef, 2026-10-27); 2.9 keeps the queue and adds a whole-file check (footer with length and hash) |
| `615-viewport-scaling.patch` in the completion archive script | in upstream's patch chain (`kexts/NVRM/patches`) |
| NVK build and `nvk/nvgfx/01-nv_push-opencl.patch`, the older NVRM, NVRMFB and NVAccel build scripts (`build_nvrm.sh`, `build_nvrmfb.sh`, `build_nvaccel.sh`, `kext_flags.sh`, `darwin.mk`, `linecc.py`) | upstream publishes its own scripts for all of them since 2.9, and the fork's package keeps the shipped NVK |

Dropped on purpose, pending a measurement: nothing. The async shader cache write in the 2.9 plan turned out to be upstream's own (commit 67a21ef, 2026-10-27, in 2.8.1 and 2.9): the fork never had a separate copy on 2.8.1, and the queue is still in 2.9's `NVMTLLibraryLoad.m`. What 2.9 adds that can slow the first minutes after login is the warm-up of recorded Core Animation variants on two background threads (`NVMTL_FCWARM_OFF=1` turns it off) and the flush before each cache rename.

## Boot-args added by the fork

All default off. With none set the kexts behave as upstream.

| Boot-arg | Kext | Effect |
|---|---|---|
| `nvrmphysctl=1` | NVRM | root-only control escape (0xE4) used by `nvgfx-smi --phys` and `--ctrl` |

Upstream's own boot-args are unchanged for us, including the ones that used to be the fork's: `nvrmtgp`, `nvrmgps`, `nvrmnvpcf`, `nvfbigpu`, `nvrmholdcap`.

## New upstream switches in 2.9 worth knowing

All of these are off by default or harmless, and none is set on the Legion.

| Switch | What it does | For this machine |
|---|---|---|
| `nmhybrid=1..4` | render on NVIDIA, present on the integrated GPU's panel through `NMIntelFB` (copy, import on Intel display 12 and 13, owned, copy engine). Upstream says it has not run on a hybrid laptop; issue 555 is a panic from `IOFBDependentID` set after `IOFramebuffer::start` | clashes with our own Intel stack (XeGfx and the `nvfbigpu` proxy); keep off |
| `nvfbhdr=1`, `nvfb10bit=1`, `nvfbbpc`, `nvfbvrr=1` | HDR10, 30-bit output, VRR | untested; the 8 bpc rule for NVDA class names from our #341 probably still applies |
| `nvrtd3=1`, `nvrmaspm=1` | D3cold for idle GPUs, idle PCIe link power saving | sleep is off here; no use |
| `nvrmshutdown=full`, `nvoffbar=1` | full RM shutdown at power-off, driver off on a Resizable BAR card with the firmware screen kept | worth a look only if a Discrete boot leaves the board unable to POST |
| `nvfbrotscale=1`, `nvfbsurround`, `nvfbhotplugpoll`, `nvfbkeepfront=1`, `nvrmfbddc=1`, `nvmultigpu=1` | rotation modes, surround, hot-plug polling, keep the frame across mode changes, DDC/CI, one card per process | not needed |
| `nmhdavol=1`, `nmkbl=1` | HDMI and DisplayPort volume, laptop keyboard backlight (ASUS, Lenovo, Dell, MSI) | the keyboard backlight might matter on the Legion later |
| `NVMTL_FCWARM_OFF=1` | no warm-up of recorded Core Animation variants after login | first thing to try if drags are slow after login |
| `NVMTL_FPS_LIMIT` | frame-rate limiter per application | optional |
| `NVMTL_FC_SPEC=1`, `NVMTL_ASYNC_TEX_UPLOAD=1`, `NVMTL_NO_POOL_REUSE=1` | opt-in function-constant path, asynchronous texture uploads, per-commit command pools | `NVMTL_NO_POOL_REUSE=1` is the workaround for the Terminal hang below |

Installer change: 2.9 no longer ships the GSP firmware; its installer reads it from NVIDIA's driver package (550 MB download) unless the package carries `Users/Shared/nvfw` or `/Library/NullMoth/nvfw` already holds the 620.70.06 files. `package.sh` with `NVGFX_FW_FROM=<older pkgroot>` carries them.

## Sysctls

- `debug.nvrm_tgp_{enable,state,ac,last_status,applies}` (upstream): TGP mode state; `debug.nvrm_tgp_enable=0` holds the VBIOS limit.
- The fork's own `debug.nvgfx_tgp_*`, `debug.nvgfx_present_*`, `debug.nvgfx_fb_*` and `debug.nvgfx_dirty_*` are gone from 2.9: the first set is replaced by the line above; the others were the 2.1.0 branch's present path and dirty-mark accounting, which the 2.8.1 branch did not carry either.

## Environment switches (plugin)

Read from `/Library/GPUBundles/nvmtl/nvrm610.conf` in release builds, since the plugin unsets `NVMTL_*` variables at load. All of these are upstream's now.

| Switch | Effect |
|---|---|
| `NVMTL_NO_SAMPLER_RESTORE=1` | a shader's own sampler stays in the app's sampler slot after the draw |
| `NVMTL_NO_PSO_SKIP=1` | a repeated setRenderPipelineState inside a pass is applied again |
| `NVMTL_NO_SV_MEMO=1` | the render encoder looks its sampler variant up on every draw |
| `NVMTL_CACHE_SYNC_IO=1` | shader cache writes go back on the calling thread |
| `NVMTL_NO_POOL_REUSE=1` | command pools and address pages are created and destroyed per commit instead of being kept behind the completion witness; set on the test machine since 2026-10-20 as the workaround for the per-process backend shutdown below |
| `NVMTL_FCWARM_OFF=1` | no warm-up of recorded Core Animation variants (new in 2.9) |

## Where things are

| Path | What |
|---|---|
| `kexts/NVRM/nvrm_physctl.c`, `nvrm_physctl_abi.h`, `NVRM.cpp` | the control escape |
| `tools/nvgfx-smi`, `tools/nvgfx-burn`, `tools/nvgfx-boost` | telemetry, load and boost tools |
| `build/nvgfx/` | `build_plugin.sh`, `build_xlate.sh`, `package.sh`, comparison tools |
| `build/build_kms620.sh`, `build/build_nvrm.sh` | upstream's scripts with the fork's two hunks |
| `notes/` | the working notes behind each change |

## Measured on the test machine

RTX 5070 Laptop (`10DE:2D18`), 2560x1600 at 165 Hz, macOS 26.7.1 (25G241), OpenCore 1.0.8, package 2.1.0-nvgfx.20:

- Metal 3 device, accelerated desktop, Liquid Glass renders.
- Present path: flips latched at the panel rate (165/s), window drags about 148 fps; shipped 2.1.0 on the same machine did about 54.
- Power: 115 W enforced with `nvrmtgp=1` (VBIOS default 50 W; Windows runs the same GPU at 115 W with Dynamic Boost).
- Terminal overdraw from 2.1.0: gone since nvgfx.1.
- Geekbench 6.7.1 Metal: 103094 on 2.4.3-nvgfx.1 (2026-10-20, https://browser.geekbench.com/v6/compute/6944564);
  Background Blur completes here (upstream #292 reports a hang at that subtest on other machines).
- WindowServer CPU after boot: normal since nvgfx.20 (before: about 150 % while it re-translated every shader).
- Still wrong (I-085, 2026-10-20): Terminal.app and iTerm2 froze for good three times in two hours under heavy text output.
  The plugin logged "vk: completion witness missing; disabling backend and retaining all in-flight resources" in the
  process (upstream `nvmtl_vk_submit_finish`, unchanged here), every later command buffer was nil and CoreAnimation's
  CG glyph queue waited forever. Workaround: `NVMTL_NO_POOL_REUSE=1` in nvrm610.conf (not yet proven). Upstream issue
  to be written by hand; record in project-legion `evidence/native/I-085-completion-witness-hang/`.
- Still wrong: the Dock's blur draws as blocks (a WindowServer framebuffer-fetch problem, under investigation with the trace switches).

## Credit

All of the driver is NullMoth's work unless a commit on the `nvgfx` branch says otherwise. The full upstream history is kept here unchanged. Bug reports and fixes that apply to everyone go to NullMoth first.

Required Notice: Copyright (c) 2026 NullMoth Systems (https://nullmothsystems.com)

Distributed under the PolyForm Noncommercial License 1.0.0 (`LICENSE`, https://polyformproject.org/licenses/noncommercial/1.0.0): noncommercial use only. Third-party parts keep their own terms, listed in `NOTICE`.
