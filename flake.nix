{
  description = "NixOS running on LicheePi 4A";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-24.11";
  };

  outputs = {
    self,
    nixpkgs,
    ...
  }: let
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
      # "mempair" # FIXME: Seem has bug on gcc 13.2.0: https://gcc.gnu.org/bugzilla/show_bug.cgi?id=114160
      "sync"
    ];

    # https://nixos.wiki/wiki/Build_flags
    # this option equals to add `-march=rv64gc` into CFLAGS.
    # CFLAGS will be used as the command line arguments for the gcc/clang.
    #
    # Note: CFLAGS is not used by the kernel build system! so this would not work for the kernel build.
    #
    # A little more detail;
    # RISC-V is a modular ISA, meaning that it only has a mandatory base,
    # and everything else is an extension.
    # RV64GC is basically "RISC-V 64-bit, extensions G and C":
    #
    #  G: Shorthand for the IMAFDZicsr_Zifencei base and extensions
    #  C: Standard Extension for Compressed Instructions
    #
    # for more details about the shorthand of RISC-V's extension, see:
    #   https://en.wikipedia.org/wiki/RISC-V#Design
    #
    # LicheePi 4A is a high-performance development board which supports extension G and C.
    # we need to enable them to get revyos's kernel built.
    gcc-march = "rv64gc"
    # We cannot use V extension, as gcc13 support v0.11, gcc 14 support v1.0, but C910 is v0.7
    #      + "v"
    # And gcc13 supported standard extensions: https://gcc.gnu.org/gcc-13/changes.html#riscv
          + "_zfh"
    # And gcc13 supported t-head vendor extensions: https://gcc.gnu.org/gcc-13/changes.html#riscv
          + builtins.concatStringsSep "" (map (ext: "_xthead" + ext) thead-extensions)
          ;

    # the same as `-mabi=lp64d` in CFLAGS.
    #
    # Note: CFLAGS is not used by the kernel build system! so this would not work for the kernel build.
    #
    # lp64d: long, pointers are 64-bit. GPRs, 64-bit FPRs, and the stack are used for parameter passing.
    #
    # related docs:
    #  https://github.com/riscv-non-isa/riscv-toolchain-conventions/blob/master/README.mkd#specifying-the-target-abi-with--mabi
    gcc-mabi = "lp64d";

    qemu-cpu = "rv64"
             + builtins.concatStringsSep "" (map (ext: ",xthead" + ext + "=true") thead-extensions)
             ;

    crossSystemConfig = {
      config = "riscv64-unknown-linux-gnu";
      gcc.arch = gcc-march;
      gcc.abi = gcc-mabi;
    };

    overlay = self: super: {
      linuxPackages_thead = super.linuxPackagesFor (super.callPackage ./pkgs/kernel {
        stdenv = super.gcc13Stdenv;
        kernelPatches = with super.kernelPatches; [
          bridge_stp_helper
          request_key_helper
        ];
      });

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

          # set the CFLAGS and CPPFLAGS to enable the rv64gc and lp64d.
          # as described here:
          #   https://github.com/graysky2/kernel_compiler_patch#alternative-way-to-define-a--march-option-without-this-patch
          export KCFLAGS=' -march=${gcc-march} -mabi=${gcc-mabi}'
          export KCPPFLAGS=' -march=${gcc-march} -mabi=${gcc-mabi}'

          exec bash
        '';
      }).env;
  };
}
