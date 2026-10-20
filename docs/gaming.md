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

- Driver: the config blacklists `i915` so the newer `xe` driver drives the
  iGPU. Roll back to an earlier generation if the display misbehaves.
- Governor: on AC the CPU governor is forced to `performance`; on battery it
  goes back to `powersave`. Manage with `powerprofilesctl` if needed.
- VRR is allowed on eDP-1/DP-4/DP-6; the docked LGs report VRR as unsupported.