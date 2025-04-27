{ qemu-cpu, ... }:

self: super: {
  # override original `nixpkgs/pkgs/top-level/all-packages.nix`.mesonEmulatorHook
  # to add t-head vendor extensions to QEMU arguments.
  mesonEmulatorHook =
    if (super.stdenv.buildPlatform != super.stdenv.targetPlatform) then
      super.makeSetupHook
        {
          name = "mesonEmulatorHook";
          substitutions = {
            crossFile = super.writeText "cross-file.conf" ''
              [binaries]
              exe_wrapper = [${super.lib.escapeShellArg (super.stdenv.targetPlatform.emulator super.buildPackages)}, '-cpu', '${qemu-cpu}']
            '';
          };
        } ./emulator-hook.sh # FIXME: how to use nixpkgs?
    else
      throw "mesonEmulatorHook has to be in a cross conditional i.e. (stdenv.buildPlatform != stdenv.hostPlatform)"
    ;
}
