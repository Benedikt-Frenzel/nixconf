{
  flake.nixosModules.gtk = {
    pkgs,
    lib,
    ...
  }: let
    theme-name = "Gruvbox-Green-Dark-Medium";
    theme-package = pkgs.gruvbox-gtk-theme.override {
      colorVariants = ["dark"];
      sizeVariants = ["standard"];
      themeVariants = ["green"];
      tweakVariants = ["medium" "macos"];
    };

    icon-theme-package = pkgs.gruvbox-plus-icons;
    icon-theme-name = "Gruvbox-Plus-Dark";

    cursor-theme-name = "Afterglow-Recolored-Gruvbox-Green";
    cursor-size = 24;
    cursor-theme-package = pkgs.afterglow-cursors-recolored.override {
      themeVariants = ["Gruvbox"];
      gruvboxColorVariants = ["Green"];
    };

    # qt6's GTK platform theme is gone in this nixpkgs. Kvantum is the match.
    kvantum-theme = "Gruvbox-Dark-Green";
    kvantum-package = pkgs.gruvbox-kvantum.override {
      variant = kvantum-theme;
    };

    gtksettings = ''
      [Settings]
      gtk-icon-theme-name = ${icon-theme-name}
      gtk-theme-name = ${theme-name}
      gtk-cursor-theme-name = ${cursor-theme-name}
      gtk-cursor-theme-size = ${toString cursor-size}
    '';

    qtct = ''
      [Appearance]
      icon_theme=${icon-theme-name}
      style=kvantum
      standard_dialogs=default
      custom_palette=false
    '';
  in {
    qt = {
      enable = true;
      platformTheme = "qt5ct";
      style = "kvantum";
    };

    environment = {
      etc = {
        "xdg/gtk-3.0/settings.ini".text = gtksettings;
        "xdg/gtk-4.0/settings.ini".text = gtksettings;
        "xdg/Kvantum/kvantum.kvconfig".text = ''
          [General]
          theme=${kvantum-theme}
        '';
        "xdg/qt5ct/qt5ct.conf".text = qtct;
        "xdg/qt6ct/qt6ct.conf".text = qtct;
      };
    };

    environment.variables = {
      GTK_THEME = theme-name;
      XCURSOR_THEME = cursor-theme-name;
      XCURSOR_SIZE = toString cursor-size;
      # qt5ct installs the Qt 6 plugin, but Qt 6 looks up the theme name qt6ct.
      QT_QPA_PLATFORMTHEME = lib.mkForce "qt6ct";
    };

    programs = {
      dconf = {
        enable = lib.mkDefault true;
        profiles = {
          user = {
            databases = [
              {
                lockAll = false;
                settings = {
                  "org/gnome/desktop/interface" = {
                    gtk-theme = theme-name;
                    icon-theme = icon-theme-name;
                    color-scheme = "prefer-dark";
                    cursor-theme = cursor-theme-name;
                    cursor-size = lib.gvariant.mkInt32 cursor-size;
                  };
                };
              }
            ];
          };
        };
      };
    };

    environment.systemPackages = [
      theme-package
      icon-theme-package
      cursor-theme-package
      kvantum-package

      pkgs.gtk3
      pkgs.gtk4
    ];
  };
}
