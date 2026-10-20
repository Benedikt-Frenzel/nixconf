{
  flake.nixosModules.powersave = {
    pkgs,
    lib,
    ...
  }: {
    services.power-profiles-daemon.enable = true;
    services.thermald.enable = true;
    powerManagement.powertop.enable = true;

    # OEM AMD GPU overdrive and LACT had no effect on geeky (Intel iGPU only);
    # the equivalent governor tweaks live in the gaming module.
  };
}
