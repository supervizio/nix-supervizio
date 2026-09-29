# supervizio — Nix flake

> Mirrored from https://supervizio.github.io/agent/channels/ by `.github/workflows/sync.yml`.
> It holds no flake until supervizio publishes a release validated for this
> channel; the steps below work from then on.

The [supervizio](https://supervizio.github.io/agent/) process supervisor and
OpenTelemetry collector agent for Nix and NixOS: a package built from the
statically linked binary each release publishes (`x86_64-linux`,
`aarch64-linux`), and a NixOS module that runs it as a service.

## Run it

```sh
nix run github:supervizio/nix-supervizio -- --version
nix profile install github:supervizio/nix-supervizio
```

## NixOS

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    supervizio = {
      url = "github:supervizio/nix-supervizio";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { nixpkgs, supervizio, ... }: {
    nixosConfigurations.host = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";
      modules = [
        supervizio.nixosModules.default
        {
          services.supervizio.enable = true;
          # services.supervizio.settings = { version = "1"; services = [ ... ]; };
        }
      ];
    };
  };
}
```

| Option | Default | What |
|--------|---------|------|
| `services.supervizio.enable` | `false` | run `supervizio.service` under `multi-user.target` |
| `services.supervizio.package` | this flake's package | the package the service runs |
| `services.supervizio.settings` | `null` | the configuration, written as YAML to `/etc/supervizio/config.yaml` |
| `services.supervizio.configFile` | `null` | a configuration file used as-is; wins over `settings` |

With neither `settings` nor `configFile`, the service runs the example
configuration, as every other supervizio package does on its first install.

The service is the unit every supervizio package installs (`Type=notify`,
`Delegate=yes`, its hardening), with its paths pointed at the store. An
`overlays.default` adds `pkgs.supervizio` for configurations that prefer it.

## Updating

`nix flake update supervizio`. `sources.json` names the release's binaries at
`https://supervizio.github.io/agent/dist/<tag>/`, which keeps the binaries of
the three newest releases: a lock file older than that no longer builds on a
machine whose store does not already hold the binary.

## Where this comes from

Nothing here is edited by hand. supervizio's release pipeline writes
`sources.json` (version, URLs, hashes) and the files beside it when it
publishes a release, and a release is published only after its end-to-end
validation has built this flake's package and module against that release's
own binary and run it on NixOS under systemd — probed, supervised, and removed
by switching to a configuration without it. Report problems in this
repository's issues.
