self: super: {
  libphonenumber =
    if (super.stdenv.buildPlatform != super.stdenv.targetPlatform) then
      super.libphonenumber.overrideAttrs (old: {
        # disable -Werror=array-bounds since it seems to have false positives on riscv64
        cmakeFlags = old.cmakeFlags ++ [
          (super.lib.cmakeFeature "CMAKE_CXX_FLAGS" "-Wno-error=array-bounds")
        ];
      })
    else
      super.libphonenumber
    ;
}
