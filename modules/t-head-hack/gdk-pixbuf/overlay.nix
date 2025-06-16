{ qemu-cpu, ... }:

self: super: {
  # override postInstall script of gdk-pixbuf to make it build
  # FIXME: is there a general way to do this?
  gdk-pixbuf =
    if (super.stdenv.buildPlatform != super.stdenv.targetPlatform) then
      super.gdk-pixbuf.overrideAttrs (old: {
        postInstall = ''
          echo "setting QEMU_CPU=${qemu-cpu}"
          export QEMU_CPU=${qemu-cpu}
        '' + old.postInstall;
      })
    else
      super.gdk-pixbuf
    ;
}
