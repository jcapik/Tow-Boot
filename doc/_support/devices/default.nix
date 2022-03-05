{ pkgs
, glibcLocales
, runCommandNoCC
, symlinkJoin
, ruby
}:

let
  release-tools = import ../../../support/nix/release-tools.nix { inherit pkgs; };
  devicesDir = ../../../boards;
  devicesInfo = symlinkJoin {
    name = "Tow-Boot-devices-metadata";
    paths = (map (device: device.config.build.device-metadata) release-tools.releasedDevicesEvaluations);
  };
in

runCommandNoCC "Tow-Boot-docs-devices" {
  nativeBuildInputs = [
    ruby
    glibcLocales
  ];
  inherit devicesDir devicesInfo;
}
''
  mkdir -vp $out/devices
  export LC_CTYPE=en_US.UTF-8
  ruby ${./generate-devices-listing.rb}
''
