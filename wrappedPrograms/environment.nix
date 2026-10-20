{
  lib,
  inputs,
  self,
  ...
}: {
  perSystem = {
    pkgs,
    self',
    ...
  }: lib.mkMerge [
    {
    # My whole desktop in one package, includes kityy terminal
    packages.desktop = inputs.wrapper-modules.wrappers.niri.wrap {
      inherit pkgs;
      imports = [self.wrappersModules.niri];
      terminal = lib.getExe self'.packages.terminal;
      env = {
        EDITOR = lib.getExe self'.packages.neovim;
      };
    };

    # My primary flake terminal
    packages.terminal =
      (inputs.wrappers.wrapperModules.kitty.apply {
        inherit pkgs;
        imports = [self.wrappersModules.kitty];
        shell = lib.getExe self'.packages.environment;
      }).wrapper;

    # My primary flake shell with all of it's packages
    packages.environment = inputs.wrappers.lib.wrapPackage {
      inherit pkgs;
      package = self'.packages.fish;
      runtimeInputs = [
        # nix
        pkgs.nil
        pkgs.nixd
        pkgs.statix
        pkgs.alejandra
        pkgs.manix
        pkgs.nix-inspect
        self'.packages.nh

        # other
        pkgs.file
        pkgs.unzip
        pkgs.zip
        pkgs.p7zip
        pkgs.wget
        pkgs.killall
        pkgs.sshfs
        pkgs.fzf
        pkgs.htop
        pkgs.btop
        pkgs.eza
        pkgs.fd
        pkgs.zoxide
        pkgs.dust
        pkgs.ripgrep
        pkgs.fastfetch
	    pkgs.hyfetch
        pkgs.tree-sitter
        pkgs.imagemagick
        pkgs.imv
        pkgs.ffmpeg-full
        pkgs.yt-dlp
        pkgs.lazygit

        # wrapped
        self'.packages.neovimDynamic
        self'.packages.qalc
        self'.packages.lf
        self'.packages.git
        self'.packages.jujutsu
        self'.packages.jjui
        self'.packages.nix-check-bin
      ];
      env = {
        EDITOR = lib.getExe self'.packages.neovimDynamic;
      };
    };

    packages.nix-check-bin = pkgs.writeShellApplication {
      name = "nix-check-bin";
      text = ''
        $EDITOR "$(nix build "$1" --no-link --print-out-paths)/bin"
      '';
    };
    }
    (lib.mkIf (builtins.elem pkgs.stdenv.hostPlatform.system [
      "x86_64-linux"
      "aarch64-linux"
      "aarch64-darwin"
    ]) {
      packages.opencode2 = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.opencode2;
      packages.mistral-vibe = let
        llmVibe = inputs.llm-agents.packages.${pkgs.stdenv.hostPlatform.system}.mistral-vibe;
        # python3.pkgs.mcp runs integration tests that spawn server
        # subprocesses and bind TCP ports — blocked by the Nix sandbox
        # on Linux. All failures are TimeoutError ("Server on port X
        # did not start within 20.0 seconds"), i.e. environmental, not
        # code bugs. nixpkgs already sets __darwinAllowLocalNetworking
        # for macOS; on Linux there is no per-derivation equivalent, so
        # skip the check phase for mcp.
        mcpDep = builtins.head (builtins.filter (d: (d.pname or "") == "mcp") llmVibe.dependencies);
        fixedMcp = mcpDep.overridePythonAttrs (_: {
          doCheck = false;
        });
      in
        llmVibe.overridePythonAttrs (old: {
          dependencies = map (d: if (d.pname or "") == "mcp" then fixedMcp else d) old.dependencies;
        });
    })
  ];
}
