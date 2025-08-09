self: super: {
  gnome-user-share =
    if (super.stdenv.buildPlatform != super.stdenv.targetPlatform) then
      super.gnome-user-share.overrideAttrs (old: {
        strictDeps = true;
        depsBuildBuild = [
          self.pkg-config
        ];
      })
    else
      super.gnome-user-share
    ;
}
