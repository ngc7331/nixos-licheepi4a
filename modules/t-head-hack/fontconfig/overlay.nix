{ qemu-cpu, ... }:

self: super: {
  makeFontsCache =
    if (super.stdenv.buildPlatform != super.stdenv.targetPlatform) then
      super.callPackage ./make-fonts-cache.nix {
        inherit qemu-cpu;
      }
    else
      super.makeFontsCache
    ;
}
