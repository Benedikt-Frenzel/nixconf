{
  flake.nixosModules.nitrokey = {pkgs, ...}: let
    fido2Options = [
      "fido2-device=auto"
      # If no token is connected, fall back to the existing passphrase prompt.
      "token-timeout=15s"
    ];
  in {
    environment.systemPackages = [pkgs.libfido2];

    boot.initrd.systemd.fido2.enable = true;
    boot.initrd.luks.devices = {
      "luks-d5607473-66c6-4336-b908-76c88228c592".crypttabExtraOpts = fido2Options;
      "luks-bdfb9b4b-cbce-42df-9d5b-2a283804122e".crypttabExtraOpts = fido2Options;
    };
  };
}
