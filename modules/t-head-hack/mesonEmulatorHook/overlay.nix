{ qemu-cpu, ... }:

self: super: {
  # override original `nixpkgs/pkgs/top-level/all-packages.nix`.mesonEmulatorHook
  # to add t-head vendor extensions to QEMU arguments.
  mesonEmulatorHook =
    super.makeSetupHook
      {
        name = "mesonEmulatorHook";
        substitutions = {
          crossFile = super.writeText "cross-file.conf" ''
            [binaries]
            exe_wrapper = ['${super.lib.escape [ "'" "\\" ] (super.stdenv.targetPlatform.emulator super.buildPackages)}', '-cpu', '${qemu-cpu}']
          '';
        };
      }
      # The throw is moved into the `makeSetupHook` derivation, so that its
      # outer level, but not its outPath can still be evaluated if the condition
      # doesn't hold. This ensures that splicing still can work correctly.
      (
        if (super.stdenv.buildPlatform != super.stdenv.targetPlatform) then
          ./emulator-hook.sh # FIXME: how to use nixpkgs?
        else
          throw "mesonEmulatorHook may only be added to nativeBuildInputs when the target binaries can't be executed; however you are attempting to use it in a situation where ${super.stdenv.hostPlatform.config} can execute ${super.stdenv.targetPlatform.config}. Consider only adding mesonEmulatorHook according to a conditional based canExecute in your package expression."
      );
}
