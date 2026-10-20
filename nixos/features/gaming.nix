{
  flake.nixosModules.gaming = {
    pkgs,
    lib,
    ...
  }: {
    hardware.graphics.enable = lib.mkDefault true;

    # Driver: i915 has to claim the Meteor Lake iGPU (device 7d55).
    # The xe driver rejects the device as "not officially supported" on
    # kernel 6.18 and on kernel 7.2.11. With i915 blacklisted, xe does not
    # probe the GPU at all: there is no render node, niri sees no output
    # and the session stays black. So i915 must not be blacklisted.
    #
    # The host currently runs kernel 7.2.11 with i915 (see host config).
    # If xe ever supports 7d55 upstream, force the probe with the
    # parameters the kernel prints itself:
    #   boot.kernelParams = [
    #     "modprobe.blacklist=i915"
    #     "i915.force_probe=!7d55"
    #     "xe.force_probe=7d55"
    #   ];

    # Match the CPU governor to the power source: full speed on AC (gaming),
    # powersave on battery. power-profiles-daemon stays in charge of the
    # profile; this unit only reacts to plug/unplug events and on boot.
    # On Intel HWP, "performance" lifts the min frequency to the boost range.
    systemd.services.cpu-governor = {
      description = "Set CPU governor based on AC status";
      wantedBy = ["multi-user.target"];
      serviceConfig.Type = "oneshot";
      script = ''
        governor=powersave
        for supply in /sys/class/power_supply/*; do
          [ "$(cat "$supply/type" 2>/dev/null)" = "Mains" ] || continue
          [ "$(cat "$supply/online" 2>/dev/null)" = "1" ] && governor=performance
          break
        done
        for policy in /sys/devices/system/cpu/cpu*/cpufreq/scaling_governor; do
          echo "$governor" > "$policy"
        done
      '';
    };

    services.udev.extraRules = ''
      SUBSYSTEM=="power_supply", ATTR{type}=="Mains", RUN+="${pkgs.systemd}/bin/systemctl start cpu-governor.service"
    '';

    programs = {
      gamemode.enable = true;
      gamescope.enable = true;
      steam = {
        enable = true;
        # extraCompatPackages = with pkgs; [
        #   proton-ge-bin
        # ];
        # extraPackages = with pkgs; [
        #   SDL2
        #   gamescope
        #   er-patcher
        # ];
        protontricks.enable = true;
      };
    };
    # This only provides the driver + tools; per-game launch options live in
    # Steam. For stutter-free gaming on the 4K LGs, use e.g.:
    #
    #   gamemoderun gamescope -w 1920 -h 1080 -r 120 --mangoapp -- %command%
    #
    # In gamescope, the FPS limit / FSR live in its flags (see docs/gaming.md).
    # Rendering at 1080p/1440p instead of 4K is the biggest win on this iGPU.

    environment.systemPackages = with pkgs; [
      lutris
      steam-run
      dxvk
      # parsec-bin

      gamescope

      mangohud

      r2modman

      heroic

      er-patcher
      bottles

      steamtinkerlaunch

      prismlauncher

      lsfg-vk
      lsfg-vk-ui
    ];

    persistance.cache.directories = [
      ".local/share/Hytale"
      ".local/share/hytale-launcher"

      ".local/share/Steam"
      ".local/share/bottles"
      ".local/share/PrismLauncher"
      ".config/r2modmanPlus-local"

      ".local/share/Terraria"

      "Games"

      ".config/heroic"
    ];
  };
}
