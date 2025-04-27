
# nixos-licheepi4a:
# copied from https://github.com/NixOS/nixpkgs/blob/fa42801050c1d56f70c783cf5f43fd79f3ab542a/pkgs/by-name/me/meson/emulator-hook.sh

add_meson_exe_wrapper_cross_flag() {
  mesonFlagsArray+=(--cross-file=@crossFile@)
}

preConfigureHooks+=(add_meson_exe_wrapper_cross_flag)
