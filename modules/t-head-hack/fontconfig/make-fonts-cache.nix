/* nixos-licheepi4a:
 * modified from https://github.com/NixOS/nixpkgs/blob/7d66df760c0d524479a6f946e34963fb055211e0/pkgs/development/libraries/fontconfig/make-fonts-cache.nix
 * added args to qemu to enable xthead vendor extension
*/

{
  buildPackages,
  fontconfig,
  lib,
  runCommand,
  stdenv,
  qemu-cpu, # added
}:
let
  fontconfig' = fontconfig;
in
{
  fontconfig ? fontconfig',
  fontDirectories,
}:

runCommand "fc-cache"
  {
    preferLocalBuild = true;
    allowSubstitutes = false;
    passAsFile = [ "fontDirs" ];
    fontDirs = ''
      <!-- Font directories -->
      ${lib.concatStringsSep "\n" (map (font: "<dir>${font}</dir>") fontDirectories)}
    '';
  }
  ''
    export FONTCONFIG_FILE=$(pwd)/fonts.conf

    # added to enable xthead vendor extension
    echo "setting QEMU_CPU=${qemu-cpu}"
    export QEMU_CPU=${qemu-cpu}

    cat > fonts.conf << EOF
    <?xml version='1.0'?>
    <!DOCTYPE fontconfig SYSTEM 'urn:fontconfig:fonts.dtd'>
    <fontconfig>
      <include>${fontconfig.out}/etc/fonts/fonts.conf</include>
      <cachedir>$out</cachedir>
    EOF
    cat "$fontDirsPath" >> fonts.conf
    echo "</fontconfig>" >> fonts.conf

    # N.B.: fc-cache keys its cache entries by architecture.
    # We must invoke the host `fc-cache` (not the build fontconfig) if we want
    # the cache to be usable by the host.
    mkdir -p $out
    ${stdenv.hostPlatform.emulator buildPackages} ${lib.getExe' fontconfig "fc-cache"} -sv

    # This is not a cache dir in the normal sense -- it won't be automatically
    # recreated.
    rm -f "$out/CACHEDIR.TAG"
  ''
