# Gaming on geeky (Meteor Lake iGPU)

geeky has no discrete GPU — only the Meteor Lake Arc iGPU (128 EU), which
renders to two 4K/60 Hz LG monitors through the dock. Steam games therefore
stutter whenever they render at 4K or in an unoptimized way (e.g. Age of
Empires II HD).

## Set these as Steam launch options per game

Renders at 1080p instead of 4K, syncs frames via its own compositor, enables
GameMode (CPU governor → performance) and shows an FPS/frametime overlay:

```
gamemoderun gamescope --mangoapp -w 1920 -h 1080 -F fsr -- %command%
```

- Remove `-F fsr` if the game will scale by itself.
- Raise to `-w 2560 -h 1440` if 1080p looks too soft; the iGPU struggles at 4K.
- `--mangoapp` shows the MangoHud overlay (frame time graph) inside the game.

## Notes

- Driver: i915 drives the Meteor Lake iGPU (7d55). The xe driver rejects
  that device as "not officially supported" — on kernel 6.18 and on kernel
  7.2.11 alike — and then probes no GPU at all: no render node, no niri
  output, black screen. Blacklisting i915 is therefore off.
- Kernel: currently testing kernel 7.2.11 (`linuxPackages_latest`) with the
  i915 driver. If the session stays black, drop the kernel override in
  `nixos/hosts/geeky/configuration.nix` to go back to the default 6.18.
- If xe supports 7d55 upstream one day, force the probe with the parameters
  the kernel prints itself (`i915.force_probe=!7d55`, `xe.force_probe=7d55`).
- Power profile: switched with the power source via power-profiles-daemon
  (AC → performance, battery → balanced). On Intel HWP the cpufreq governor
  stays `powersave`; the profile acts through EPP.
- VRR is allowed on eDP-1/DP-4/DP-6; the docked LGs report VRR as unsupported.
