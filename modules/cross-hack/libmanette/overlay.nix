# partially picked from https://github.com/NixOS/nixpkgs/pull/407662
self: super: {
  libmanette =
    if (super.stdenv.buildPlatform != super.stdenv.targetPlatform) then
      super.libmanette.overrideAttrs (old: {
        strictDeps = true;
        depsBuildBuild = [
          self.pkg-config
          self.glib
        ];
      })
    else
      super.libmanette
    ;
}
