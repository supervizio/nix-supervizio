# supervizio, from the release's static Linux binary.
#
# The binary is the release asset supervizio-linux-<arch>-musl: statically
# linked, so it runs on NixOS as published, with no interpreter or rpath to
# patch. sources.json names it (URL on supervizio.github.io/agent, sha256)
# and is written per release by supervizio/agent's
# setup/packaging/render-channels.py; this file does not change between
# releases.
{
  lib,
  stdenvNoCC,
  fetchurl,
  coreutils,
}:
let
  sources = lib.importJSON ./sources.json;
  inherit (stdenvNoCC.hostPlatform) system;
  binary =
    sources.binaries.${system}
      or (throw "supervizio ${sources.version} publishes no binary for ${system}");
in
stdenvNoCC.mkDerivation {
  pname = "supervizio";
  inherit (sources) version;

  src = fetchurl { inherit (binary) name url hash; };

  dontUnpack = true;
  dontConfigure = true;
  dontBuild = true;
  # The store path holds the bytes the release published and its E2E ran:
  # nothing strips or patches them.
  dontStrip = true;
  dontPatchELF = true;

  # The unit is the one every other supervizio package installs. Only its
  # paths move: the binary is in the store, and NixOS has no /bin/mkdir.
  installPhase = ''
    runHook preInstall
    install -Dm755 "$src" "$out/bin/supervizio"
    install -Dm644 ${./supervizio.service} "$out/lib/systemd/system/supervizio.service"
    substituteInPlace "$out/lib/systemd/system/supervizio.service" \
      --replace-fail /usr/local/bin/supervizio "$out/bin/supervizio" \
      --replace-fail /bin/mkdir ${coreutils}/bin/mkdir \
      --replace-fail /bin/chmod ${coreutils}/bin/chmod
    install -Dm644 ${./config.example.yaml} "$out/share/supervizio/config.example.yaml"
    install -Dm644 ${./LICENSE} "$out/share/licenses/supervizio/LICENSE"
    runHook postInstall
  '';

  meta = {
    description = "PID1-capable process supervisor and OpenTelemetry collector agent";
    homepage = "https://github.com/supervizio/agent";
    license = lib.licenses.mit;
    mainProgram = "supervizio";
    platforms = builtins.attrNames sources.binaries;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
