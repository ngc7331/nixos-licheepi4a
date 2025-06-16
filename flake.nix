{
  description = "NixOS running on LicheePi 4A";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-25.05";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
    # Ref: https://github.com/riscv-non-isa/riscv-toolchain-conventions/blob/main/src/toolchain-conventions.adoc

    # "Z*"
    standard-extensions = [
      # gcc support @ 13.0.0: https://gcc.gnu.org/gcc-13/changes.html#riscv
      # qemu support @ 7.0: https://wiki.qemu.org/ChangeLog/7.0
      "fh"
    ];

    # "Xthead*"
    # gcc support @ 13.0.0: https://gcc.gnu.org/gcc-13/changes.html#riscv
    # qemu support @ 8.0: https://wiki.qemu.org/ChangeLog/8.0, except Xtheadint
    thead-extensions = [
      "ba"
      "bb"
      "bs"
      "cmo"
      # "condmov" # FIXME: Seem has bug on gcc 13.1.0: https://gcc.gnu.org/bugzilla/show_bug.cgi?id=109760
      "fmemidx"
      "fmv"
      # "int" # FIXME: QEMU 8.2.7 does not support this extension yet.
      "mac"
      "memidx"
      "mempair"
      "sync"
    ];

    # g: general purpose: IMAFD_Zicsr_Zifencei
    # c: compressed instruction
    # v: vector
    # we cannot use v extension, as gcc13 support v0.11, gcc 14 support v1.0, but C910 is v0.7
    gcc-march = "rv64gc" # "v" is not enabled
              + builtins.concatStringsSep "" (map (ext: "_z" + ext) standard-extensions)
              + builtins.concatStringsSep "" (map (ext: "_xthead" + ext) thead-extensions)
              ;
    # lp64d: long, pointers are 64-bit. GPRs, 64-bit FPRs, and the stack are used for parameter passing.
    gcc-mabi = "lp64d";

    qemu-cpu = "rv64,g=true,c=true" # ",v=true" is not enabled
             + builtins.concatStringsSep "" (map (ext: ",z" + ext + "=true") standard-extensions)
             + builtins.concatStringsSep "" (map (ext: ",xthead" + ext + "=true") thead-extensions)
             ;

    crossSystemConfig = {
      config = "riscv64-unknown-linux-gnu";
      gcc.arch = gcc-march;
      gcc.abi = gcc-mabi;
    };

    overlay = self: super: {
      light_aon_fpga = super.callPackage ./pkgs/firmware/light_aon_fpga.nix {};
      light_c906_audio = super.callPackage ./pkgs/firmware/light_c906_audio.nix {};
      thead-opensbi = super.callPackage ./pkgs/opensbi {};
    };

    pkgsHost = import nixpkgs {
      localSystem = "x86_64-linux";
    };

    pkgsKernelCross = import nixpkgs {
      localSystem = "x86_64-linux";
      crossSystem = crossSystemConfig;
      overlays = [ overlay ];
    };

    pkgsKernelNative = import nixpkgs {
      localSystem = crossSystemConfig;
      overlays = [ overlay ];
    };
  in {
    # expose this flake's overlay
    overlays.default = overlay;

    # cross-build an sd-image
    nixosConfigurations.lp4a-cross = nixpkgs.lib.nixosSystem {
      system = "x86_64-linux";

      specialArgs = {
        inherit nixpkgs;
        pkgsKernel = pkgsKernelCross;
      };
      modules = [
        {
          nixpkgs.crossSystem = crossSystemConfig;
          nixpkgs.overlays = [
            # add QEMU arguments to meson cross-config
            (import ./modules/t-head-hack/mesonEmulatorHook/overlay.nix { inherit qemu-cpu; })
            # add QEMU arguments to gobject-inrospection build & generated g-ir-scanner-qemuwrapper
            (import ./modules/t-head-hack/gobject-introspection/overlay.nix { inherit qemu-cpu; })
            # add QEMU arguments to fontconfig fonts cache build
            (import ./modules/t-head-hack/fontconfig/overlay.nix { inherit qemu-cpu; })
          ];
        }

        ./modules/licheepi4a.nix
        ./modules/sd-image/sd-image-lp4a.nix
        ./modules/user-group.nix
      ];
    };

    packages.x86_64-linux = {
      # u-boot & sdImage for boot from sdcard.
      uboot = pkgsKernelCross.callPackage ./pkgs/u-boot {};
      sdImage = self.nixosConfigurations.lp4a-cross.config.system.build.sdImage;

      # the nixpkgs
      pkgsKernelCross = pkgsKernelCross;
      pkgsKernelNative = pkgsKernelNative;
    };

    # use `nix develop .#fhsEnv` to enter the fhs test environment defined here.
    # the code here is mainly copied from:
    #   https://nixos.wiki/wiki/Linux_kernel#Embedded_Linux_Cross-compile_xconfig_and_menuconfig
    devShells.x86_64-linux.fhsEnv = (pkgsHost.buildFHSUserEnv {
        name = "kernel-build-env";
        targetPkgs = pkgs_: (with pkgs_;
          [
            # we need theses packages to run `make menuconfig` successfully.
            pkg-config
            ncurses

            pkgsKernelCross.gcc13Stdenv.cc
            gcc
          ]
          ++ pkgsHost.linux.nativeBuildInputs);
        runScript = pkgsHost.writeScript "init.sh" ''
          # set the cross-compilation environment variables.
          export CROSS_COMPILE=riscv64-unknown-linux-gnu-
          export ARCH=riscv
          export PKG_CONFIG_PATH="${pkgsHost.ncurses.dev}/lib/pkgconfig:"

          # set kernel c(pp)flags to apply gcc-march & gcc-mabi
          # https://github.com/graysky2/kernel_compiler_patch#alternative-way-to-define-a--march-option-without-this-patch
          export KCFLAGS=' -march=${gcc-march} -mabi=${gcc-mabi}'
          export KCPPFLAGS=' -march=${gcc-march} -mabi=${gcc-mabi}'

          exec bash
        '';
      }).env;
  };
}
