{
  flake.nixosModules.scanner = {
    pkgs,
    config,
    ...
  }: let
    user = config.preferences.user.name;
  in {
    # Brother ADS-1300 (04f9:0706) over USB. The scanner needs the current
    # brscan5 release; nixpkgs still ships 1.3.1-0, which predates the
    # model, so overlay it with the vendored 1.7.0-0 driver from Brother.
    nixpkgs.overlays = [
      (_: prev: {
        brscan5 = prev.callPackage ./_brscan5-1.7.nix {};
      })
    ];

    hardware.sane = {
      enable = true;
      brscan5.enable = true;
    };

    # Brother's udev rule tags the device libsane_matched, the sane module
    # then grants the scanner group read/write access to the USB node.
    users.users.${user}.extraGroups = ["scanner"];

    environment.systemPackages = [pkgs.simple-scan];
  };
}
