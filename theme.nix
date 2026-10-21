let
  theme = {
    base00 = "#282828"; # bg
    base01 = "#3c3836"; # dark
    base02 = "#504945";
    base03 = "#665c54";
    base04 = "#bdae93";
    base05 = "#d5c4a1";
    base06 = "#ebdbb2"; # fg
    base07 = "#fbf1c7"; # light fg
    base08 = "#fb4934"; # red
    base09 = "#fe8019"; # orange
    base0A = "#fabd2f"; # yellow
    base0B = "#b8bb26"; # green
    base0C = "#8ec07c"; # cyan
    base0D = "#83a598"; # blue
    base0E = "#d3869b"; # magenta
    base0F = "#d65d0e"; # orange
  };

  stripHash = str:
    if builtins.substring 0 1 str == "#"
    then builtins.substring 1 (builtins.stringLength str - 1) str
    else str;

  themeNoHash = builtins.mapAttrs (_: v: stripHash v) theme;
in {
  flake = {
    inherit theme themeNoHash;
  };
}
