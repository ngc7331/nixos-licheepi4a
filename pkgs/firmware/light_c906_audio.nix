{
  stdenv,
  fetchFromGitHub,
}:
stdenv.mkDerivation {
  pname = "light_c906_audio-firmware";
  version = "2025.04.23";

  src = fetchFromGitHub {
    owner = "revyos";
    repo = "th1520-boot-firmware";
    rev = "44ec4e1cc82141963842ec45db0d1617f9f07e75"; # master on 2025.04.23
    sha256 = "sha256-MjiSpdySqCr4j9i3RPJ08mBHCQAy1fA9m787hKEIwUA=";
  };

  buildCommand = ''
    install -Dm444 $src/addons/boot/light_c906_audio.bin $out/lib/firmware/light_c906_audio.bin
  '';
}
