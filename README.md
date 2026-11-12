# WTLNvidiaGfx

Renamed from `NvGfx` on 2026-10-31; the driver is still called NvGfx and the kexts keep their names. Old links redirect here.
<!-- <wtl> fork: nvgfx | author: watchthelight </wtl> -->

NvGfx is my fork of [NullMoth's NVIDIA Metal driver for macOS](https://github.com/nullmoth/nvidia-macos-driver), kept for one machine: a Lenovo Legion 5 15IAX10 with an RTX 5070 Laptop GPU (`10DE:2D18`) driving its 2560x1600 165 Hz panel, running macOS Tahoe 26.7.x through OpenCore. All of the driver is NullMoth's work. The `nvgfx-2.9` branch carries my changes on top of their 2.9 (2.9-nvgfx.1, built and not yet booted); `nvgfx-2.6.2` is the last line that has booted (2.6.2-nvgfx.1 on 26.7.1 on 2026-10-27 and on 26.7.2 on 2026-10-28); `nvgfx` is the older line on 2.1.0, kept as the rollback and for its trace tooling. The upstream README is kept as [README.upstream.md](README.upstream.md), and `main` mirrors upstream unchanged.

Required Notice: Copyright (c) 2026 NullMoth Systems (https://nullmothsystems.com)

This is source-available, not open source: the driver is under the PolyForm Noncommercial License 1.0.0 (`LICENSE`), so you may use, change and share it for noncommercial purposes only. Third-party parts keep their own terms (`NOTICE`).

## Intel Xe (branch `xe-2.6.2`)

Work on Intel graphics happens on the [`xe-2.6.2` branch](https://github.com/watchthelight-labs/WTLNvidiaGfx/tree/xe-2.6.2) (the older [`xe`](https://github.com/watchthelight-labs/WTLNvidiaGfx/tree/xe) branch holds the earlier work): a kernel driver for Intel Xe GPUs ([WTLIntelGfx](https://github.com/watchthelight-labs/WTLIntelGfx), Linux i915 through FreeBSD's [drm-kmod](https://github.com/freebsd/drm-kmod)), Mesa's [ANV](https://gitlab.freedesktop.org/mesa/mesa) Vulkan driver, and this plugin on top. On the Legion, WindowServer now composites the desktop on the Intel GPU (macOS 26.7.1 and 26.7.2); it is still a test driver and drawing bugs are being fixed. The [WTLIntelGfx README](https://github.com/watchthelight-labs/WTLIntelGfx) has the current status and downloads. [docs/XE.md](https://github.com/watchthelight-labs/WTLNvidiaGfx/blob/xe-2.6.2/docs/XE.md) on that branch has the layout and build notes, though its status line dates from 2026-10-21. Collaborators and testers with Intel Xe machines are welcome.

## What the fork changes

NullMoth 2.9 carries most of what this fork used to add, so the 2.9 branch is small. What is still mine:

| Change | Where | State |
|---|---|---|
| `nvrmphysctl=1`: a root-only escape on the NVRM user client that issues one RM control through the GSP, for `nvgfx-smi --phys` and `--ctrl`. Upstream deliberately has no such entry | `kexts/NVRM/nvrm_physctl.c`, `nvrm_physctl_abi.h`, the `NVRM_ESC_PHYS_CTRL` case in `NVRM.cpp` | builds, matches the shipped 2.9 NVRM in every other function |
| `nvgfx-smi`: read-only telemetry (power limit and draw, clocks, pstate, temperature, throttle reasons) through the RM's shared data; `nvgfx-burn`: a Metal load generator; `nvgfx-boost`: a daemon that holds or drops the system-wide boost request | `tools/nvgfx-smi`, `tools/nvgfx-burn`, `tools/nvgfx-boost` | work |
| Build and package scripts that use upstream's own `build/` scripts and check the result against the shipped binaries; `package.sh` swaps the builds into NullMoth's installer package | `build/nvgfx/` | works |
| `build_kms620.sh` drops `-mfunction-return=thunk-extern`: 620's NVKMS adds the Linux return thunk, XNU exports no `__x86_return_thunk`, and a kext built with it would not link at load | `build/build_kms620.sh` | needed for any NVRM built from the published scripts |

What the fork used to carry and NullMoth has now (their `NOTICE` says the power budget, the GPS and NVPCF answers, the panel proxy head and the two A/B switches follow ideas first published here and that the code is theirs; the other items are in their changelog): the notebook power budget (`nvrmtgp=1`, `nvrmgps=1`, `nvrmnvpcf=1`; the sysctls are `debug.nvrm_tgp_*` now), the Intel panel proxy head (`nvfbigpu=1`), the boot hold ceiling (`nvrmholdcap`), the shader cache work (fallback folder, cache I/O queue), the repeated-pipeline skip and the sampler-variant memo with their two A/B switches, the HiDPI flag on scaled modes, the sampler restore, the Dock badge mip fill, the function-table pipeline link, and GeekAudio's translator change. The event-driven present path and the Terminal overdraw fix live only on the `nvgfx` branch (2.1.0).

The notes in `notes/` are the working record. `NVGFX.md` lists the switches and what each package label contains.

## What it can't do

- It is tested on one GPU, one panel and one laptop. Nothing here is a general release.
- It does not ship packages. You need NullMoth's 2.9 package (for the installer and the Mac app) and swap in the builds from this tree with `build/nvgfx/package.sh`. NullMoth no longer ships the GSP firmware, so `package.sh` can carry NVIDIA's firmware over from an older package (`NVGFX_FW_FROM`) instead of letting the installer download it.
- No sleep and wake (the laptop runs with sleep disabled).
- Upstream's `AGENTS.md` and `CONTRIBUTING.md` are NullMoth's rules for their repository and are kept as they wrote them.

## Building

Everything builds on macOS with the Xcode Command Line Tools and a few dependencies kept outside the tree: NVIDIA's open-gpu-kernel-modules at tag `620.70.06`, Vulkan-Headers for the plugin, and rustup stable for the translator. The kexts are built with the 15.5 SDK (`SDKROOT`), the plugin with the macOS 26 SDK and a macOS 15.0 deployment target.

```
build/build_rm620.sh <work> <620.70.06 tree>   # RM core, patch chain applied (upstream's script)
build/build_kms620.sh <work>                   # NVKMS archive (drops the return thunk, see above)
build/build_nvrm.sh kexts/NVRM <work>/ogkm-620.70.06 <out>/nvrm   # builds nvrm_physctl.c in too
build/fb_build.sh kexts <out>/nvrmfb           # NVRMFB.kext
build/accel_build_all.sh kexts/NVRM <out>/nvaccel   # NVAccel.kext for macOS 15 and 26
build/nvgfx/build_plugin.sh                    # NVMTLDriver (RELEASE=1 for the shipped flags)
build/nvgfx/build_xlate.sh                     # libnvmtl_translate
REF=<2.9 pkgroot> NVGFX_NVRM=... build/nvgfx/package.sh 2.9-nvgfx.N   # installer package with the builds swapped in
```

Built from this tree, NVRMFB and both NVAccel kexts are byte for byte the shipped 2.9 ones; NVRM differs from the shipped one in the escape function and the added export only (`build/nvgfx/nvrm/compare_nvrm.py`).

## Installing and rolling back

Install the package `package.sh` produces with NullMoth's own `install.sh`; it backs up what it replaces. Rolling back is NullMoth's `uninstall.sh`, or installing an earlier package again. Boot-args, sysctls and environment switches are in `NVGFX.md`; with none of them set the fork's kexts behave like upstream.

## Credits and licence

NullMoth Systems wrote the driver. Third-party parts, per `NOTICE`: NVIDIA's open GPU kernel modules (MIT / GPL-2.0), Mesa NVK (MIT), metal2vulkan by Anees Iqbal (LGPL-3.0 or later, the base of `translator/`), NVIDIA GSP firmware under NVIDIA's firmware licence. The fork, like upstream, is under the PolyForm Noncommercial License 1.0.0.

Projects we learned from:
- GeekAudio wrote the translator change in [nullmoth PR #385](https://github.com/nullmoth/nvidia-macos-driver/pull/385) (immutable local pointer fields), taken here with their commits as they are; it makes MPSGraph's depthwise convolution translate.
- ccyykk666 found why the Dock blur turns into blocks ([nullmoth #363](https://github.com/nullmoth/nvidia-macos-driver/issues/363)): a shader's own sampler overwrote the app's sampler slot. The fix here follows their description.
- [thanhnndev/nvidia-macos-driver](https://github.com/thanhnndev/nvidia-macos-driver): an AppleGraphicsDeviceControl service for a non-NVIDIA panel (NMXAGDC), the 0x2001 client-set reply CoreDisplay waits for before it sends display-pipe transactions, and why WindowServer must keep the accelerator that owns the main display.
