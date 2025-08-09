self: super: {
  power-profiles-daemon =
    if (super.stdenv.buildPlatform != super.stdenv.targetPlatform) then
      super.power-profiles-daemon.overrideAttrs (old: {
        # strictDeps = true;
        depsBuildBuild = [
          (self.python3.withPackages (ps: [
            ps.pygobject3
            ps.dbus-python
            ps.python-dbusmock
            ps.argparse-manpage
            ps.shtab
          ]))
        ];
      })
    else
      super.power-profiles-daemon
    ;
}
