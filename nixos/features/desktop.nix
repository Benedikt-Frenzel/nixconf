{self, ...}: {
  flake.nixosModules.desktop = {
    pkgs,
    config,
    lib,
    ...
  }: let
    selfpkgs = self.packages.${pkgs.stdenv.hostPlatform.system};
    user = config.preferences.user.name;
    pcmanfm = pkgs.pcmanfm.overrideAttrs (old: {
      postInstall = (old.postInstall or "") + ''
        rm -f $out/share/applications/pcmanfm-desktop-pref.desktop
      '';
    });
    # References only: op resolves the credentials at runtime, never during a build.
    opencodeEnv = pkgs.writeText "opencode.env" ''
      MINIMAX_API_KEY=op://AI/xnuzyj7llnouc2bovppuzm7fvu/credential
      MISTRAL_API_KEY=op://AI/iwxpx2iqryutxvecb6hast2a2u/credential
      VENICE_API_KEY=op://AI/3atx3ri74ptberjmegdvyugaee/credential
      MOONSHOT_API_KEY=op://AI/ram3g3tncmmphiwgum4une7kx4/credential
      OPENROUTER_API_KEY=op://AI/rwjrvaso4xknpwt5yuih3rd6me/credential
      ZHIPU_API_KEY=op://AI/cz2zm72n2c6kdpm56trhl6cpsa/credential
      DEEPSEEK_API_KEY=op://AI/bbyctjsymt4vxhfyp5n4rfltaa/credential
    '';
    opencode = pkgs.writeShellApplication {
      name = "opencode";
      text = ''
        envFile="''${XDG_CONFIG_HOME:-$HOME/.config}/opencode/1password.env"
        if [[ -e "$envFile" && ! -p "$envFile" ]]; then
          echo "Expected a 1Password FIFO at $envFile, not a plaintext file." >&2
          exit 1
        fi
        if [[ ! -p "$envFile" ]]; then
          envFile=${opencodeEnv}
        fi
        # Use the privileged CLI wrapper for desktop-app integration on NixOS.
        # A private server cannot accidentally reuse a service without these keys.
        # Masking pipes stdout/stderr, breaking the TUI's terminal size detection.
        exec /run/wrappers/bin/op run --no-masking --env-file="$envFile" -- ${lib.getExe selfpkgs.opencode2} --standalone "$@"
      '';
    };
    vibeEnv = pkgs.writeText "vibe.env" ''
      MISTRAL_API_KEY=op://AI/ug36otigk3ndflbgntgzzujmbm/credential
    '';
    vibe = pkgs.writeShellApplication {
      name = "vibe";
      text = ''
        envFile="''${XDG_CONFIG_HOME:-$HOME/.config}/vibe/1password.env"
        if [[ -e "$envFile" && ! -p "$envFile" ]]; then
          echo "Expected a 1Password FIFO at $envFile, not a plaintext file." >&2
          exit 1
        fi
        if [[ ! -p "$envFile" ]]; then
          envFile=${vibeEnv}
        fi
        # The Pro-plan key is separate from opencode's Mistral platform key,
        # so vibe reads its own FIFO instead of the OpenCode environment.
        # Masking pipes stdout/stderr, breaking the TUI's terminal size detection.
        exec /run/wrappers/bin/op run --no-masking --env-file="$envFile" -- ${lib.getExe selfpkgs.mistral-vibe} "$@"
      '';
    };
    veniceMcp = pkgs.writeShellApplication {
      name = "venice-mcp";
      runtimeInputs = [pkgs.nodejs];
      text = ''
        exec npx --yes @veniceai/mcp-server@0.3.0
      '';
    };
  in {
    imports = [
      self.nixosModules.pipewire
      self.nixosModules.firefox
      self.nixosModules.chromium
    ];

    programs.niri.enable = true;
    programs.niri.package = selfpkgs.niri;

    # preferences.autostart = [selfpkgs.quickshellWrapped];
    preferences.autostart = [selfpkgs.noctalia-shell];

    environment.systemPackages = [
      selfpkgs.terminal
      pcmanfm
      selfpkgs.noctalia-shell
      opencode
      vibe
      pkgs.cliphist
      pkgs.wl-clipboard
      pkgs.wl-clip-persist
    ];

    fonts.packages = with pkgs; [
      nerd-fonts.jetbrains-mono
      ubuntu-sans
      cm_unicode
      corefonts
      unifont
    ];

    fonts.fontconfig.defaultFonts = {
      serif = ["Ubuntu Sans"];
      sansSerif = ["Ubuntu Sans"];
      monospace = ["JetBrainsMono Nerd Font"];
    };

    time.timeZone = "Europe/Berlin";
    i18n.defaultLocale = "en_US.UTF-8";
    i18n.extraLocaleSettings = {
      LC_ADDRESS = "de_DE.UTF-8";
      LC_IDENTIFICATION = "de_DE.UTF-8";
      LC_MEASUREMENT = "de_DE.UTF-8";
      LC_MONETARY = "de_DE.UTF-8";
      LC_NAME = "de_DE.UTF-8";
      LC_NUMERIC = "de_DE.UTF-8";
      LC_PAPER = "de_DE.UTF-8";
      LC_TELEPHONE = "de_DE.UTF-8";
      LC_TIME = "de_DE.UTF-8";
    };

    services.upower.enable = true;
    services.power-profiles-daemon.enable = true;

    # USB, trash and phone mounts for pcmanfm. Also pulls in udisks2.
    services.gvfs.enable = true;

    services.greetd = {
      enable = true;
      useTextGreeter = true;
      settings.default_session.command = lib.escapeShellArgs [
        (lib.getExe pkgs.tuigreet)
        "--time"
        "--asterisks"
        "--remember"
        "--user-menu"
        "--greeting"
        "geeky"
        "--cmd"
        (lib.getExe' config.programs.niri.package "niri-session")
        "--sessions"
        "${config.services.displayManager.sessionData.desktops}/share/wayland-sessions"
        "--theme"
        "border=${self.theme.base0B};text=${self.theme.base06};prompt=${self.theme.base0B};time=${self.theme.base0A};action=${self.theme.base09};button=${self.theme.base0B};container=${self.theme.base00};input=${self.theme.base07}"
      ];
    };

    # tuigreet's power menu runs systemctl as the greeter user.
    security.polkit.extraConfig = ''
      polkit.addRule(function(action, subject) {
        if (subject.user == "greeter" && (
          action.id == "org.freedesktop.login1.reboot" ||
          action.id == "org.freedesktop.login1.reboot-multiple-sessions" ||
          action.id == "org.freedesktop.login1.power-off" ||
          action.id == "org.freedesktop.login1.power-off-multiple-sessions"
        )) {
          return polkit.Result.YES;
        }
      });
    '';

    security.polkit.enable = true;

    programs._1password.enable = true;
    programs._1password-gui = {
      enable = true;
      polkitPolicyOwners = [user];
    };

    environment.sessionVariables.SSH_AUTH_SOCK = "/home/${user}/.1password/agent.sock";

    hjem.users.${user}.files = {
      ".config/opencode/opencode.json".text = builtins.toJSON {
        "$schema" = "https://opencode.ai/config.json";
        providers = lib.mapAttrs (_: env: {inherit env;}) {
          minimax = ["MINIMAX_API_KEY"];
          mistral = ["MISTRAL_API_KEY"];
          venice = ["VENICE_API_KEY"];
          moonshotai = ["MOONSHOT_API_KEY"];
          openrouter = ["OPENROUTER_API_KEY"];
          zai = ["ZHIPU_API_KEY"];
          deepseek = ["DEEPSEEK_API_KEY"];
        };
        mcp.servers.venice = {
          type = "local";
          command = ["${veniceMcp}/bin/venice-mcp"];
          environment.VENICE_API_KEY = "{env:VENICE_API_KEY}";
          timeout.startup = 120000;
        };
      };

      # 1Password ignores a symlinked agent.toml, so this has to be a real file.
      # Vault is $HOSTNAME#$USER, for example geeky#ben.
      ".config/1Password/ssh/agent.toml" = {
        type = "copy";
        text = ''
          [[ssh-keys]]
          vault = "${config.networking.hostName}#${user}"
        '';
      };
    };

    persistance.data.directories = [
      ".config/1Password"
      ".local/share/1Password"
      # mistral-vibe config.toml and caches; credentials live in the keyring.
      ".vibe"
    ];

    persistance.cache.directories = [
      ".cache/cliphist"
    ];

    hardware = {
      enableAllFirmware = true;

      bluetooth.enable = true;
      bluetooth.powerOnBoot = true;

      graphics = {
        enable = true;
        enable32Bit = true;
      };
    };
  };
}
