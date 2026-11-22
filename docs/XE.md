# Intel Xe on the NvGfx stack (branch `xe`)

This branch is where the Intel side of NvGfx comes together: a kernel driver for Intel Xe GPUs, the same Metal-to-Vulkan plugin that runs NVIDIA cards here, and Mesa's ANV Vulkan driver in between. The aim is one driver for every Xe part (Tiger Lake to Arrow Lake and Arc first, then Lunar Lake, Battlemage and Panther Lake) on macOS 11 to 26.

Status on 2026-10-21: the kernel driver builds and links, its first hardware run is queued, and ANV builds for macOS and passes a simulated test on every Intel generation. Nothing has rendered on Intel hardware with this branch yet; [VedCloud's Meteor Lake port](https://github.com/VedCloud/Meteor-Lake-Xe-LPG-Metal-Graphics) has, with a similar stack on macOS 15. Progress is tracked in [XeGfx's issues](https://github.com/watchthelight-labs/XeGfx/issues) and in [issue #12](https://github.com/watchthelight-labs/NvGfx/issues/12) here.

## What lives where

| Path | What it is |
|---|---|
| `gpu/xegfx/` | [XeGfx](https://github.com/watchthelight-labs/XeGfx) as a git subtree (BSD-2): the FreeBSD kernel API on XNU, the build harness, the checks. drm core and i915 come unchanged from FreeBSD's drm-kmod. See its [HOW-IT-WORKS](https://github.com/watchthelight-labs/XeGfx/blob/main/docs/HOW-IT-WORKS.md). |
| `gpu/xkpi/` | The build overlay: replacements for the few drm-kmod files that are GPL-only, so the kext contains no GPL-only code. Provenance in `gpu/xkpi/NOTICE.md`. |
| `gpu/userland/` | How to build Mesa ANV and libdrm for macOS (`BUILD.md`, `scripts/`), the Darwin patches, and the `vkprobe` test. |
| `kexts/NMIntelFB/` | A flip-only framebuffer for the built-in panel that adopts the mode the firmware lit (untested). |
| `kexts/IGPUConsoleRange/` | Lets macOS's own framebuffer driver use a firmware console that sits in stolen memory (tested on Arrow Lake in Hybrid mode). |
| `plugin/`, `kexts/NVRM/accel/` | The Metal plugin and accelerator. The plugin already loads ANV for Intel accelerators; the Intel accelerator build is the next step. |
| `build/nvgfx/build_xegfx.sh` | Builds the Intel kext with the overlay and every check. |

## Building the kernel driver

Sources go in `~/src/xe-src` (`linux`, `freebsd`, `drm-kmod` at `c16de0f`, and `linux-firmware` with `mtl_guc_70.bin` and `LICENSE.i915`), plus [kcabi](https://github.com/watchthelight-labs/kcabi) in `~/src/kcabi`. Then:

```
build/nvgfx/build_xegfx.sh
```

It compiles every source (418 today), refuses GPL-only sources or headers, links against public kernel interfaces only, and fails if the kext redefines a kernel symbol. Installing and testing: `gpu/xegfx/CONTRIBUTING.md`.

## Building ANV

See `gpu/userland/BUILD.md`. In short: libdrm `b97cbde` and Mesa `bffd919` with the two Darwin patches, `-Dvulkan-drivers=intel`, LLVM only at build time. The current futex code needs macOS 14.4 or later; older systems need a fallback (XeGfx issue tracker).

## Built on, and learned from

XeGfx is built on other people's work. Thanks to all of them.

**Code XeGfx builds or ships** (their licences apply to their files):

| Project | What we use |
|---|---|
| [freebsd/drm-kmod](https://github.com/freebsd/drm-kmod) | drm core, TTM, dma-buf and i915 sources, compiled unchanged |
| [FreeBSD LinuxKPI](https://github.com/freebsd/freebsd-src/tree/main/sys/compat/linuxkpi) and [FreeBSD kernel](https://github.com/freebsd/freebsd-src) | the Linux kernel API layer, plus `subr_eventhandler.c` and FreeBSD's headers |
| [Linux](https://github.com/torvalds/linux) i915 and DRM | the driver drm-kmod tracks; the `sync_file` uapi header |
| [linux-firmware](https://gitlab.com/kernel-firmware/linux-firmware) | Intel's GuC firmware (`LICENSE.i915`) |
| [nullmoth/nvidia-macos-driver](https://github.com/nullmoth/nvidia-macos-driver) | the Metal plugin and accelerator NvGfx forks; its old AMD/Intel port (commit `bf2dee3`) supplies the GPL-free dma-buf, sync_file and fence-unwrap replacements and the Mesa/libdrm Darwin patches used in NvGfx's `xe` branch |
| [Mesa](https://gitlab.freedesktop.org/mesa/mesa) ANV and [libdrm](https://gitlab.freedesktop.org/mesa/drm) | the planned Vulkan userspace |
| [steelbrain/metal2vulkan](https://github.com/steelbrain/metal2vulkan) | the Metal-to-SPIR-V translator inside the NvGfx plugin; its coverage table and refusals list, and its Arrow Lake ANV validation profile |
| [watchthelight-labs/kcabi](https://github.com/watchthelight-labs/kcabi) | kernel collection link and ABI checks |

**Projects we studied** (ideas, findings and warnings only; no code copied):

| Project | What we learned |
|---|---|
| [b00t0x/WhateverXe](https://github.com/b00t0x/WhateverXe), [WhateverXe-Graphics](https://github.com/b00t0x/WhateverXe-Graphics), [b00t0x/OpenCore-Legacy-Patcher](https://github.com/b00t0x/OpenCore-Legacy-Patcher) | Xe-LP on Apple's Tiger Lake driver across Big Sur to Tahoe; forcing BAR0 MMIO to strong uncached; stolen-memory decoding; adopting the firmware's pipes without a modeset; since 0.4.0 Tiger Lake laptop panels too, by reading panel facts from the firmware's VBT and keeping the eDP scrambler and framing bits in step with the panel during link training; shipping the graphics stack as a signed /Library package instead of System patches; 0.6.0 (October 2026) adds Alder Lake and Raptor Lake laptops, defers framebuffer opens until AGDC registration, and states Xe-LPG is not planned; Graphics 0.3.0 converts shaders to AIR with the system compiler; 0.8.3 (November 2026) adds brightness over the eDP AUX channel from the panel's DPCD backlight registers, not yet validated on a panel |
| [sgiammori/NootedGreen](https://github.com/sgiammori/NootedGreen) | how far the Apple TGL donor approach reaches on Alder Lake and Raptor Lake |
| [JulioNectar/Hackintosh-XPS13Plus-IrisXe-Tahoe](https://github.com/JulioNectar/Hackintosh-XPS13Plus-IrisXe-Tahoe) | keeping the firmware's eDP mode, the boot-programmable mode trap in WindowServer, the GGTT[0] machine-check hazard, Tahoe IOSurface offsets; holding the boot plane dark until WindowServer owns the display, a scheduler fix for a context-status event that was being dropped, and blit paths that fail on wide or oddly pitched IOSurface planes; later, render-engine workarounds applied after every engine start, power rerouting so hybrid P-cores get correct HWP units, a per-command-buffer leak that grew WindowServer past 10 GB, and eDP backlight over DPCD AUX |
| [m4j2rpf766-crypto/IntelIGPU-Tahoe](https://github.com/m4j2rpf766-crypto/IntelIGPU-Tahoe) | handing the panel over from IONDRVFramebuffer on Tahoe; isolating the iGPU at boot |
| [VedCloud/Meteor-Lake-Xe-LPG-Metal-Graphics](https://github.com/VedCloud/Meteor-Lake-Xe-LPG-Metal-Graphics) (earlier: [VedCloud2/CoreUltraGraphics](https://github.com/VedCloud2/CoreUltraGraphics)) | the first i915-on-XNU port to drive real Intel hardware: an i915-derived kernel driver on LinuxKPI, Mesa ANV and a NullMoth-derived Metal plugin, with Metal and Vulkan working on a Meteor Lake Dell Latitude 5350 under macOS 15; GuC submission with Linux's own MTL firmware, a GPU-composited desktop, and two lessons for our LinuxKPI: a lost wake-up that looked like GuC timeouts, and starting the stolen-memory allocator after the firmware's console image; on 2026-10-23 they confirmed that ANV's sync_file probe can be passed from userspace with stand-in descriptors, the route XeGfx 0.0.12 takes |
| [kitsuneislife/nmx-intel](https://github.com/kitsuneislife/nmx-intel) | i915 through NullMoth's port lighting a Raptor Lake laptop panel on macOS, and a framebuffer that copies frames composited on another GPU to the Intel panel; its pitfalls notes taught us to reserve the boot framebuffer's stolen pages and GGTT range before i915 allocates, and to give the framebuffer an `IOFBDependentID` |
| [IT-EXPRESS-Bayern/LunarBridge-Hackintosh](https://github.com/IT-EXPRESS-Bayern/LunarBridge-Hackintosh) | Lunar Lake (Xe2) groundwork on Tahoe |
| [wallali77666-cyber/iris-xe-macos-driver](https://github.com/wallali77666-cyber/iris-xe-macos-driver) | a NullMoth-style stack aimed at Tiger Lake |
| [zep245/IrisXe-macos-driver](https://github.com/zep245/IrisXe-macos-driver) | i915 and Mesa ANV running on Tiger Lake under Sequoia through NullMoth's Intel path; sandboxed apps see no GPU because the sandbox refuses `opendir(/dev/dri)`, and the in-kernel LinuxKPI panics it ran into (thread_call limits, `cond_resched` inside `ggtt_pin`, TLB flush timeouts); in 1.0.0 (October 2026) scaled desktops through i915's panel fitter by giving a modeset the panel's timing with a smaller source, the hardware cursor plane, page flips instead of copies, NVRAM breadcrumbs that made each flip take about 700 ms, and the plugin's one-time copy of small no-copy textures that hid typed letters; in 1.0.1 (October 2026) Tahoe icons back on the GPU after finding that buffer textures were refused on ANV's memory types (the same cause as our I-120, found independently), and per-function constant spaces for linked visible functions; in 1.2.5 (November 2026) scaled HiDPI sizes: the framebuffer has to publish `IOFBScalerInfo` and a timing range and accept programmed timings, the scan-out buffer is larger than the panel and a plane scaler shrinks it, and the modes need the hi-res flag (display overrides alone add no sizes) |
| [CENSEDAXIS20025/ASUS-FX608LP-Hackintosh-Multiboot](https://github.com/CENSEDAXIS20025/ASUS-FX608LP-Hackintosh-Multiboot) | the same Core Ultra 9 275HX, 7D67 iGPU and RTX 5070 Laptop running macOS on the RTX with the iGPU blocked and the MUX set to discrete only |
| [samranahmad09/WhateverXe-RaptorLakeP](https://github.com/samranahmad09/WhateverXe-RaptorLakeP) | checking a bring-up by capturing i915's registers on Linux next to a macOS readout, and a blitter ring self-test |
| [lutzbichler/drm-kmod](https://github.com/lutzbichler/drm-kmod) (xe patches) and [drm-kmod #316](https://github.com/freebsd/drm-kmod/issues/316) | the state of the xe driver outside Linux |
| [drm-kmod #315](https://github.com/freebsd/drm-kmod/issues/315), [#418](https://github.com/freebsd/drm-kmod/pull/418), [#468](https://github.com/freebsd/drm-kmod/pull/468) | LinuxKPI bugs FreeBSD already fixed for Meteor Lake and Arc, to carry over; #418 is merged, #468 was replaced by a scatterlist fix in freebsd-src and by [#534](https://github.com/freebsd/drm-kmod/pull/534) |
| [openbsd/src](https://github.com/openbsd/src) inteldrm | attaching i915 in stages and deferring the heavy probe |
| [Mountainatic/ArrowWhatever](https://github.com/Mountainatic/ArrowWhatever) | the same Core Ultra 9 275HX and 7D67 iGPU with an RTX 5080 Laptop on XeGfx 0.0.44, with ten patches of their own: a pin versus last-unwire race in userptr buffers, GGTT zero-copy scanout with a flip deferred until the GPU is idle (about 60 fps at 2560x1600, up from about 15), and the panel timing read from BAR0. Their userptr panic and fix (patch 0001) is the same bug we hit as I-121 and fixed in 0.0.46, found independently. Patch 0009 lets WindowServer submit without waiting and flips only once the engines are idle, which took the desktop to about 60 fps. Patches 0008 and 0009 are ported to the `xe-zerocopy-flip` branch, adapted to a per-surface wait (built, not booted or released yet). Patches 0010 to 0037 (November 2026) go further: i915 takes over the eDP pipe with a hardware cursor plane and plane-scaler HiDPI sizes, brightness through i915's backlight code, AGDC colour stages that save one full-screen copy per frame, a GPU clock floor on late frames, and a watchdog that names an MMIO read that never returned. Not ported yet |
| [victorwitkamp/NootedGreen](https://github.com/victorwitkamp/NootedGreen) (branch `raptor-lake-hx`) | a NootedGreen fork for Raptor Lake-HX that ports i915 forcewake, pipe VDSC and the render engine workarounds; its owner reports Metal on a ROG Strix G814JI |
| [samwu07/xegfx-thinkbook14plus-mtl](https://github.com/samwu07/xegfx-thinkbook14plus-mtl) | Meteor Lake on 0.0.47: a boot framebuffer that starts below the GuC's GGTT top makes `reserve_bootfb` refuse it (-28 on a 3072x1920 panel), and moving its GGTT mapping before XeGfx loads gets WindowServer and Metal up; also a zero-copy flip on that machine |
| [ericek111/vibe-nullmoth-xe3-qemu](https://github.com/ericek111/vibe-nullmoth-xe3-qemu) | NullMoth's xe port running Panther Lake (Xe3) as an SR-IOV function in QEMU, and the port bugs it fixed on the way: runtime PM stubs that dropped every GuC reply, kernel maps of non-contiguous buffers, MSI on the function (no licence yet, so notes only) |
| [InSnh-Gd/WTLIntelGfx](https://github.com/InSnh-Gd/WTLIntelGfx) (PR #1) | a plan for a bare-metal Panther Lake xe port on this tree, with a triage of the 115 patches above into bare-metal, VF-only and not needed |
| [lems-hardware/lhl-hackintosh-docs](https://github.com/lems-hardware/lhl-hackintosh-docs) | an attempt-by-attempt log of Panther Lake (`B082`) on a core from this tree's lineage, to GuC running and a user-space submit read back; and the finding that an SRCU treated as plain RCU panics when `drm_dev_enter` sleeps under it, which we have yet to check in our shim |
| [yangyishuo1124/Mubai-s-Hackintosh-Logs](https://github.com/yangyishuo1124/Mubai-s-Hackintosh-Logs) | Panther Lake (`B0A0`) work on a copy of this tree, with a clear list of what is verified and what is not, and an NVRAM step trace for a stage that freezes the machine (GPL-3.0, so notes only) |
| [cuadra8998/MeowXE3](https://github.com/cuadra8998/MeowXE3) | the Linux xe driver on NullMoth's LinuxKPI with a desktop reported on one Wildcat Lake laptop (`FD80`); on an Arrow Lake-H `7D51` it froze the machine for another user, so xe is not a drop-in there (PolyForm Noncommercial, so notes only) |
| [yusufklncc/intel-gpu-macos-driver](https://github.com/yusufklncc/intel-gpu-macos-driver) | the same architecture on an Arc B580; in 0.1.7 (November 2026) an ANV descriptor-buffer bug that drops a layer from app icons, found with a test, a shutdown panic from a DMA mapping kept without a wire, and what skipping the per-frame composite readback gains (notes only until its licence is read) |
| [hepengfei00/XeMac](https://github.com/hepengfei00/XeMac) | this tree and ArrowWhatever's patches on another 7D67 machine with an external DisplayPort screen, plus nine patches of its own: DisplayPort and AUX mapping, the framebuffer fetch WindowServer does, and the native timing published to AGDC |
| [taqieallah/ThinkPad-E16-ArrowLake-macOS](https://github.com/taqieallah/ThinkPad-E16-ArrowLake-macOS) | 0.0.47 on a ThinkPad E16 (`7D51`) with a zero-copy flip, and a CPU that stays near 550 MHz as the open problem there |
| [change-48/XEGFX-MIGRATE](https://github.com/change-48/XEGFX-MIGRATE) | a bring-up log on `7D51`: when `reserve_bootfb` fails the accelerator can overwrite the boot framebuffer, plane geometry only latches on a `PLANE_SURF` write, and where a 24.8 ms frame spends its time |
| [acidanthera/WhateverGreen](https://github.com/acidanthera/WhateverGreen) and [OpenCorePkg](https://github.com/acidanthera/OpenCorePkg) | the Intel framebuffer background every Hackintosh graphics project builds on |

