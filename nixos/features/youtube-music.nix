{
  flake.nixosModules.youtube-music = {pkgs, ...}: {
    environment.systemPackages = [
      pkgs.pear-desktop
    ];

    persistance.cache.directories = [
      ".config/YouTube Music"
    ];
  };
}
