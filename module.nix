# NixOS module: supervizio as a system service.
#
#   services.supervizio.enable = true;
#
# runs the package's own supervizio.service -- the unit every other supervizio
# package installs (Type=notify, Delegate=yes, its hardening), paths pointed
# at the store -- under multi-user.target, with /etc/supervizio/config.yaml
# from `settings`, `configFile`, or else the example configuration, which is
# what every other package copies into place on first install.
{
  config,
  lib,
  pkgs,
  ...
}:
let
  cfg = config.services.supervizio;
  yaml = pkgs.formats.yaml { };
  configFile =
    if cfg.configFile != null then
      cfg.configFile
    else if cfg.settings != null then
      yaml.generate "supervizio-config.yaml" cfg.settings
    else
      "${cfg.package}/share/supervizio/config.example.yaml";
in
{
  options.services.supervizio = {
    enable = lib.mkEnableOption "supervizio, the process supervisor and OpenTelemetry collector agent";

    package = lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage ./package.nix { };
      defaultText = lib.literalMD "supervizio, from this flake's `sources.json`";
      description = "The supervizio package the service runs.";
    };

    settings = lib.mkOption {
      type = lib.types.nullOr yaml.type;
      default = null;
      example = lib.literalExpression ''
        {
          version = "1";
          services = [
            {
              name = "web";
              command = "''${pkgs.python3}/bin/python3";
              args = [ "-m" "http.server" "8080" ];
              restart.policy = "always";
            }
          ];
        }
      '';
      description = ''
        The supervizio configuration, written to /etc/supervizio/config.yaml.
        Its schema is supervizio's (examples/config.yaml in supervizio/agent).
        With neither this nor `configFile` set, the package's example
        configuration is used.
      '';
    };

    configFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "A configuration file to use as-is. Takes precedence over `settings`.";
    };
  };

  config = lib.mkIf cfg.enable {
    environment.systemPackages = [ cfg.package ];
    environment.etc."supervizio/config.yaml".source = configFile;

    systemd.packages = [ cfg.package ];
    systemd.services.supervizio = {
      # NixOS ignores a packaged unit's [Install] section: say it here.
      wantedBy = [ "multi-user.target" ];
      restartTriggers = [ configFile ];
      # The inventory finds the host's package managers on PATH and reads the
      # system closure with nix-store. A NixOS unit's PATH holds neither:
      # without this, the service would report a NixOS host with no manager.
      path = lib.optional config.nix.enable config.nix.package;
    };
  };
}
