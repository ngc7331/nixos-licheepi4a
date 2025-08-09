self: super: {
  gnome-keyring =
    if (super.stdenv.buildPlatform != super.stdenv.targetPlatform) then
      super.gnome-keyring.overrideAttrs (old: {
        strictDeps = true;
        depsBuildBuild = [
          self.pkg-config
          self.glib
        ];
      })
    else
      super.gnome-keyring
    ;
}
