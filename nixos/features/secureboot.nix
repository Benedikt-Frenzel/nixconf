{inputs, ...}: {
  # Enrollment in the firmware is a separate, manual step after a test boot.
  flake.nixosModules.secureboot = {
    pkgs,
    lib,
    ...
  }: {
    imports = [inputs.lanzaboote.nixosModules.lanzaboote];

    environment.systemPackages = [pkgs.sbctl];

    boot.loader.systemd-boot.enable = lib.mkForce false;
    boot.lanzaboote = {
      enable = true;
      pkiBundle = "/var/lib/sbctl";
    };

    persistance.directories = ["/var/lib/sbctl"];
  };
}
