
{ lib, buildUBoot, fetchFromGitHub, thead-opensbi }:

(buildUBoot rec {
  version = "2025.04.23";

  src = fetchFromGitHub {
    # https://github.com/revyos/thead-u-boot
    owner = "revyos";
    repo = "thead-u-boot";
    rev = "93ff49d9f5bbe7942f727ab93311346173506d27"; # th1520 on 2025.04.23
    sha256 = "sha256-1eKBuAbLAeyox8NXgTTbAEpDHUqXSqjvb+/OJMcIX3A=";
  };

  defconfig = "light_lpi4a_defconfig";

  extraMeta.platforms = [ "riscv64-linux" ];
  extraMakeFlags = [
    "OPENSBI=${thead-opensbi}/share/opensbi/lp64/generic/firmware/fw_dynamic.bin"
  ];

  filesToInstall = [ "u-boot-with-spl.bin" ];
}).overrideAttrs (oldAttrs: {
  patches = [
    ./patches/0001-feat-use-mmcbootpart-1-for-nixos.patch
  ];
})
