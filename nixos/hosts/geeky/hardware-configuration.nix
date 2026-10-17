{
  flake.nixosModules.hostGeeky = {
    config,
    lib,
    modulesPath,
    ...
  }: {
    imports = [
      (modulesPath + "/installer/scan/not-detected.nix")
    ];

    boot.initrd.availableKernelModules = ["xhci_pci" "thunderbolt" "nvme" "usb_storage" "sd_mod"];
    boot.initrd.kernelModules = [];
    boot.kernelModules = ["kvm-intel"];
    boot.extraModulePackages = [];

    boot.initrd.luks.devices."luks-d5607473-66c6-4336-b908-76c88228c592".device = "/dev/disk/by-uuid/d5607473-66c6-4336-b908-76c88228c592";
    boot.initrd.luks.devices."luks-bdfb9b4b-cbce-42df-9d5b-2a283804122e".device = "/dev/disk/by-uuid/bdfb9b4b-cbce-42df-9d5b-2a283804122e";

    fileSystems."/" = {
      device = "/dev/mapper/luks-d5607473-66c6-4336-b908-76c88228c592";
      fsType = "xfs";
    };

    fileSystems."/boot" = {
      device = "/dev/disk/by-uuid/C9AC-0A20";
      fsType = "vfat";
      options = ["fmask=0077" "dmask=0077"];
    };

    swapDevices = [
      {device = "/dev/mapper/luks-bdfb9b4b-cbce-42df-9d5b-2a283804122e";}
    ];

    nixpkgs.hostPlatform = lib.mkDefault "x86_64-linux";
    hardware.cpu.intel.updateMicrocode = lib.mkDefault config.hardware.enableRedistributableFirmware;
  };
}
