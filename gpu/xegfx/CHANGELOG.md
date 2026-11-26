# Changelog

Versions are the kext's `CFBundleVersion`. "Booted" means the version ran on the test laptop (Legion 5 15IAX10, Arrow Lake iGPU `8086:7D67`); "built" means it compiled and has not been run. Prereleases with a binary: v0.0.27, v0.0.35, v0.0.36, v0.0.38, v0.0.45, v0.0.46 and v0.0.47.

## Unreleased (plugin, booted: N-384, 2026-11-26)

- Metal plugin: a texture barrier now refreshes the self-read snapshot. The finding is jxy333967's
  (samwu07/xegfx-thinkbook14plus-mtl issue 2), and a tester's rendering faults on a Core Ultra 5 225H went away with
  the same change. Writing 8192 to `/Library/GPUBundles/nvmtl/xe-live` turns it off for an A/B test. The test laptop
  showed no such fault before, and shows none with it: this boot proves only that it does no harm here.
- First WindowServer run on macOS 26.7.3 beta 25G416, with XeGfx 0.0.48, XeGfxAccel 0.9, XeGfxAGDC 0.1.1 and
  XeGfxIntelFB 0.10: stages 1 to 7, the Vulkan and Metal probes, then 300 s with WindowServer on the Intel GPU
  (12 accelerator clients). The plugin ran against the shader translator of NullMoth's 2.9 package.
- What the accelerated desktop is worth on this laptop at idle, 150 s each within the same half hour: composited in
  software the package averaged 93.5 C at 50.6 W with WindowServer at 70 to 220 % CPU; accelerated it averaged
  56.4 C at 17.0 W with WindowServer near 2 %. The laptop's cooler is weak, so the temperatures are high for this
  model; the power figures carry over better.

## XeGfxIntelFB 0.10 (booted: N-383, 2026-11-26)

XeGfx.kext itself is unchanged (0.0.48). This is the framebuffer kext for the built-in panel.

- The hardware cursor works with the firmware framebuffer at any GGTT base. 0.9 only took a framebuffer at
  `0xFF000000`, where the Legion's firmware puts it. 0.10 reads the base, stride and height of plane 1A, works out
  where the framebuffer ends and keeps the cursor's 64 pages above it; a framebuffer that reaches past `0xFFFA0000`,
  a tiled plane or a busy cursor plane still turns the hardware cursor off. The kernel log says which:
  `XeGfxIntelFB: hw cursor ready: 256x256 ARGB at GGTT fffa0000, firmware framebuffer ff000000-fffa0000`, or a
  "hw cursor off" line with the register values. Tested only on the Legion, where the base is the old fixed one;
  other bases are checked by reading the code, not on hardware.
- Boot guard fix. Every start of the kext counts in the NVRAM variable `xeintelfb-starts` and clears it 120 s later;
  two counted starts turn the kext off so a hanging panel driver cannot loop. Only the first clear of a boot ran, so
  a second start in the same boot stayed counted, and with one more leftover the kext stayed off for good while the
  panel ran on Apple's IONDRVFramebuffer without anything on screen saying so. Each start now arms its own clear.
  If the panel is on IONDRVFramebuffer and `nvram 7C436110-AB2A-4BBB-A880-FE41995C9F82:xeintelfb-starts` reads 2,
  delete the variable and restart.
- 0.9 (2026-10-31, not listed here before): hardware cursor on pipe A's cursor plane, 256x256 ARGB.
- Release `xeintelfb-0.10`: the kext with `install.sh` and `uninstall.sh` (they rebuild the auxiliary kernel
  collection; run them only with XeGfx not loaded).

## 0.0.48 (booted: N-372)

- Stage 4 moves the boot framebuffer out of the GuC area before i915 starts (WTLIntelGfx issue #13). When the GOP's
  GGTT mapping crosses `0xFEE00000`, its entries are copied to a free range below it and PLANE_SURF follows at the
  next vblank; a surface that ends below the top (including one at GGTT 0), or starts at or above it, is left alone. A
  reclaimed target is kept clear of every enabled plane and cursor. If the move is refused and the framebuffer still
  crosses the top, stage 4 stops before i915 starts, so the GuC image is not drawn over the panel. Replaces the
  separate XgFbMove kext for stages run by XeGfx.
  Written and tested by samwu07 on a ThinkBook whose framebuffer crosses the top (PR #16). On the Legion the boot
  surface sits at `0xFF000000`, so N-372 took the "not needed" path: status 0, stages 1 to 7 and the userland checks
  pass. The result is in the kernel log line "stage 4 boot framebuffer move" and in the GPU's `xegfx-fbmove` property.
- First run on macOS 26.7.3 beta (25G416): loads and passes stages 1 to 7 unchanged.
- `tools/link.sh` takes `NO_LINKCHECK=1` to skip the checks that read the kernel collections.
- Tester result (samwu07, ThinkBook 14+ 155H `7D55`, macOS 15.8.1 24H32, the released zip): stage 4 move status 1,
  `0xfe800000` to `0x80000000`, stages reach 7, desktop up
  ([report](https://github.com/watchthelight-labs/WTLIntelGfx/pull/16#issuecomment-6847114272)). The Legion (`7D67`) takes the not-needed path.

## 0.0.47 (booted: N-355)

- The stage 2 probe and the later stages find an Intel GPU whose PCI class is 0380 (display, other) as well as 0300. A MUX in discrete mode leaves the iGPU as 0380, so the probe found nothing on those machines (I-125, reported by two testers).
- Stage 4 no longer panics on GPUs older than Meteor Lake. i915 looks up the PCH's ISA bridge there, LinuxKPI names a kobject after that driverless device, whose name is NULL, and `xg_vsnprintf` read the NULL format string. It now prints "(fmt null)" as FreeBSD's kvprintf does (I-124, Alder Lake-P tester report in #3). Meteor Lake and Arrow Lake skip that lookup, which is why our machines never hit it.

## Unreleased (plugin, booted: N-319, N-320)

- Horizontal bands across the desktop while typing or scrolling are gone (I-119). An app's render pass or IOSurface write
  on ANV could still be running when WindowServer composited the surface, so a half-drawn frame reached the screen.
  On Intel, every process except WindowServer now waits at commit for command buffers that render or write an IOSurface.
  Writing 64 to `/Library/GPUBundles/nvmtl/xe-live` turns this off live for A/B tests. N-320: no bands with it on,
  bands within seconds with it off. mtlbench under load stays at 4.6 to 5.0 ms per frame.
- WindowServer waiting for its own command buffers (N-318) and a GPU barrier at the start of each command buffer
  (N-317) did not help; the barrier is still in, `NVMTL_XE_CB_BARRIER=0` turns it off.

## 0.0.46 (booted: N-300 to N-302)

- A userptr page that is being freed is never wired again (I-121). `vm_page_unwire` dropped the last wiring before `vm_page_free` took the run out of the table, so a new hold on the same page could take the count from 0 to 1 in between and `vm_page_free` panicked with "freeing wired page". It happened at the restart that ended N-299 after 5.6 hours under load. The restart that ended N-300, with the desktop live under the same load, did not panic.

The NvGfx `xe` side of the same runs:

- XeGfxIntelFB 0.6 publishes `VRAM,totalMB` on the GPU (3/4 of RAM above 4 GB, the size ANV gives its heap), so System Information shows "VRAM (Dynamic, Max): 24576 MB" on a 32 GB machine instead of the 15 MB firmware framebuffer (N-301). `xeintelfbvram=<MB>` overrides it.
- XeGfxIntelFB 0.7 reads the panel's EDID over eDP AUX A and measures the refresh rate from the pipe's frame counter. The panel gets its real name, size and 165 Hz, macOS applies the same display override it uses on the NVIDIA GPU, and the HiDPI 1280x800 mode is offered (N-302). Scaled sizes larger than half the panel still need the pipe scaler, which is not done yet.
- XeGfxIntelFB 0.8 names the GPU by generation ("Intel Arrow Lake Xe-LPG" for 7D67), and the Metal device on Intel uses the same name (built, not booted).
- Plugin: `NVMTL_XE_UNIFIED=1` in nvrm610.conf makes the Intel device report unified memory. Off by default; N-302 runs WindowServer with it on.
- Plugin: heap textures keep their swizzle and buffers record their memory type, which fixed the flat yellow Dock symbols (I-120). N-298 ran four hours of desktop under load with it.

## 0.0.45 (booted: N-295, N-296)

N-295 (`gtawake=2`) froze 16 minutes into the Intel desktop with the same rendezvous panic, so forcewake is not the I-116 cause. N-296 ran the same build with `xegfx.nvram_trace=0` and the Intel desktop stayed up for the full hour. The trace's NVRAM writes run in SMM on this firmware, where a CPU cannot answer the rendezvous interrupt, so the trace is now the main suspect. Leave it off for desktop runs.


- `xegfx.gtawake=1` holds every GT's wakeref, `=2` also takes forcewake on all domains, so the GT never enters RC6. Off by default. It mirrors what stopped the whole-Mac freezes on another Xe port (I-116). The implementation of `xg_i915_gtawake` is in the NvGfx fork's `gpu/xkpi` overlay.
- `XeGfxGt` in the registry reports `gtawake-gts`.

## 0.0.44 (built, not booted)

- `xegfx.irqoff_check=0` turns off the interrupts-off checker and its 20 ms wakeup, to A/B it against the I-116 freeze. The checker stays on by default.

## 0.0.43 (booted: N-290)

- The interrupts-off watchdog names the CPU and the caller before macOS hits its rendezvous timeout (I-116). On N-290 the Intel desktop stayed up for the 900 s test, the first run to do so since I-116 appeared.

## 0.0.42 (booted: N-289, crashed at about 15 to 20 s with the I-116 rendezvous panic)

- Reverts the blanket rwlock spin from 0.0.40, which caused rendezvous panics (N-287, N-288).
- `xg_map_mmap` takes the lookup lock before `rcu_read_lock` instead, which fixes the sleeping-lock-in-RCU panic on WindowServer's mmap path.

## 0.0.41

- Interrupt and handler counts in `debug.xegfx_spin`, for the N-287 stall.
- XeGfxIntelFB 0.5 names the iGPU so About This Mac shows "Intel Xe Graphics".

## 0.0.40

- rwlocks spin inside critical sections, after WindowServer's mmap-offset lookup blocked under `rcu_read_lock` and panicked (N-286). Reverted in 0.0.42.

## 0.0.39

- Logs why a userptr hold fails (WindowServer execbuffer EFAULT, N-283).
- XeGfxIntelFB 0.3 clears the guard with a zero count.

## 0.0.38 and earlier

See the git history. 0.0.38 rebases syncobj wait deadlines from Darwin's CLOCK_MONOTONIC onto the shim's ktime; 0.0.37 returns `ETIME` for LinuxKPI's `ETIMEDOUT` so Mesa sees `VK_TIMEOUT`.
