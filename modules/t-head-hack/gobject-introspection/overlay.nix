{ qemu-cpu, ... }:

self: super: {
  # override postConfigure script of gobject-introspection to make it build
  # FIXME: is there a general way to do this?
  gobject-introspection-unwrapped =
    if (super.stdenv.buildPlatform != super.stdenv.targetPlatform) then
      super.gobject-introspection-unwrapped.overrideAttrs (old: {
        postConfigure = old.postConfigure + ''
          echo "setting QEMU_CPU=${qemu-cpu}"
          export QEMU_CPU=${qemu-cpu}
        '';
      })
    else
      super.gobject-introspection-unwrapped
    ;
  # also override the built qemuwrapper
  gobject-introspection =
    if (super.stdenv.buildPlatform != super.stdenv.targetPlatform) then
      super.gobject-introspection.overrideAttrs (old: {
        buildCommand = old.buildCommand + ''
          (
            echo "patching qemuwrapper with emulator-args=${qemu-cpu}"
            export bash="${super.buildPackages.bash}" # copied from https://github.com/NixOS/nixpkgs/blob/fa42801050c1d56f70c783cf5f43fd79f3ab542a/pkgs/development/libraries/gobject-introspection/wrapper.nix
            export emulator=${super.lib.escapeShellArg (super.stdenv.targetPlatform.emulator super.buildPackages)} # copied from https://github.com/NixOS/nixpkgs/blob/fa42801050c1d56f70c783cf5f43fd79f3ab542a/pkgs/development/libraries/gobject-introspection/wrapper.nix
            export emulatorargs="-cpu ${qemu-cpu}"
            substituteAll "${./g-ir-scanner-qemuwrapper.sh}" "$dev/bin/g-ir-scanner-qemuwrapper" # copied from https://github.com/NixOS/nixpkgs/blob/fa42801050c1d56f70c783cf5f43fd79f3ab542a/pkgs/development/libraries/gobject-introspection/wrapper.nix
            chmod +x "$dev/bin/g-ir-scanner-qemuwrapper"
          )
        '';
      })
    else
      super.gobject-introspection
    ;
}
