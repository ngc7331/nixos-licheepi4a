# picked from https://github.com/NixOS/nixpkgs/pull/424930
self: super: {
  thin-provisioning-tools =
    if (super.stdenv.buildPlatform != super.stdenv.targetPlatform) then
      super.thin-provisioning-tools.overrideAttrs (old: {
        strictDeps = true;
        depsBuildBuild = [
          self.pkg-config
          self.lvm2
          self.udev
        ];
        nativeBuildInputs = old.nativeBuildInputs ++ [
          self.rustPlatform.bindgenHook
        ];
        buildInputs = old.buildInputs ++ [
          self.lvm2
          self.udev
        ];
      })
    else
      super.thin-provisioning-tools
    ;
}
