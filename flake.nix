{
  description = "A template for Nix based C++ project setup.";

  inputs = {
    # Pointing to the current stable release of nixpkgs. You can
    # customize this to point to an older version or unstable if you
    # like everything shining.
    #
    # E.g.
    #
    # nixpkgs.url = "github:NixOS/nixpkgs/unstable";
    #    rbfx.url = "github:pillowtrucker/rbfx/mine";
    #    nixpkgs-llvm18 = {
    #      type = "github";
    #      owner = "ExpidusOS";
    #      repo = "nixpkgs";
    #      ref = "feat/llvm-18";
    #    };
    godot-mine.url = "github:wonky-honky/godot-slimflake/master";
    nixpkgs.url = "github:NixOS/nixpkgs/master";

    utils.url = "github:numtide/flake-utils";

  };

  outputs = { self, nixpkgs, ... }@inputs:
    inputs.utils.lib.eachSystem [
      # Add the system/architecture you would like to support here. Note that not
      # all packages in the official nixpkgs support all platforms.
      "x86_64-linux"
      "i686-linux"
      "aarch64-linux"
      "x86_64-darwin"
    ] (system:
      let
        pkgs = import nixpkgs {
          inherit system;

          # Add overlays here if you need to override the nixpkgs
          # official packages.
          overlays = [
            (final: prev: {
              #              godot = prev.callPackage ./godot-mine {
              #                stdenv = prev.llvmPackages_18.stdenv;
              #              };
              godot = inputs.godot-mine.packages.${system}.godot;
              fbx2gltf = inputs.godot-mine.packages.${system}.fbx2gltf;
              #              inherit (rec {
              #                llvmPackages_18 = prev.recurseIntoAttrs (prev.callPackage
              #                  "${inputs.nixpkgs-llvm18}/pkgs/development/compilers/llvm/18" ({
              #                    inherit (prev.stdenvAdapters) overrideCC;
              #                    buildLlvmTools = final.buildPackages.llvmPackages_18.tools;
              #                    targetLlvmLibraries =
              #                      final.targetPackages.llvmPackages_18.libraries or llvmPackages_18.libraries;
              #                    targetLlvm =
              #                      final.targetPackages.llvmPackages_18.llvm or llvmPackages_18.llvm;
              #                  }));

              #                clang_18 = llvmPackages_18.clang;
              #                lld_18 = llvmPackages_18.lld;
              #                lldb_18 = llvmPackages_18.lldb;
              #                llvm_18 = llvmPackages_18.llvm;

              #                clang-tools_18 = prev.callPackage
              #                  "${inputs.nixpkgs-llvm18}/pkgs/development/tools/clang-tools" {
              llvmPackages = prev.llvmPackages_18;
              #                  };
              #              })
              #                llvmPackages_18 clang_18 lld_18 lldb_18 llvm_18 clang-tools_18;
              redis = prev.redis.overrideAttrs { doCheck = false; };
              #              pythonPackagesExtensions = prev.pythonPackagesExtensions ++ [
              #                (python-final: python-prev: {
              #                  conan = python-prev.dontCheck python-prev.conan;
              #
              #                })
              #
              #              ];
            })

          ];

          # Uncomment this if you need unfree software (e.g. cuda) for
          # your project.
          #
          config.allowUnfree = true;
        };
      in {
        devShells.default = pkgs.llvmPackages_18.stdenv.mkDerivation rec {
          # Update the name to something that suites your project.
          name = "godot_test_project_shell";
          stdenv = pkgs.llvmPackages_18.stdenv;
          #          stdenv = pkgs.llvmPackages_18.libcxxStdenv;
          packages = with pkgs;
            with xorg;
            [
              # Development Tools
              (clang-tools.override { llvmPackages = llvmPackages_18; })
              llvmPackages_18.bintools
              python3
              git
              boost
              fmt_8
              libxml2
              godot
              gdtoolkit_4
              #              (pkgs.llvmPackages_18.libcxx.override { enableShared = false; })
              pkgs.llvmPackages_18.compiler-rt
              cmake
              #              (godot4.override { inherit stdenv; })
              cmakeCurses
              ninja
              conan
              # Development time dependencies
              #              gtest
              #            rbfx.packages.${system}.default
              vulkan-validation-layers
              # Build time and Run time dependencies
              vulkan-loader
              vulkan-headers
              vulkan-tools
              pkg-config
              xorg.libX11
              libdrm
              libxkbcommon
              libXext
              libXv
              libXrandr
              libxcb
              zlib
              #            gtk3
              #            libuuid
              wayland
              libpulseaudio
              pulseaudio
              dbus
              dbus.lib
              speechd
              fontconfig
              fontconfig.lib
              vulkan-loader
              libGL

              alsa-lib
              #            spdlog
              #            abseil-cpp
            ] ++ [
              libXcursor
              libXinerama
              libXext
              libXrandr
              libXrender
              libXi
              libXfixes
              libxkbcommon
            ];
          buildInputs = packages;
          nativeBuildInputs = packages;

          # Setting up the environment variables you need during
          # development.
          #      shellHook = let
          #        icon = "f121";
          #      in ''
          #        export PS1="$(echo -e '\u${icon}') {\[$(tput sgr0)\]\[\033[38;5;228m\]\w\[$(tput sgr0)\]\[\033[38;5;15m\]} (${name}) \\$ \[$(tput sgr0)\]"
          #      '';
        };

        #        packages.default = pkgs.callPackage ./default.nix {
        #          #          stdenv = pkgs.llvmPackages_18.stdenv;
        #          stdenv = pkgs.llvmPackages_18.stdenv;
        #        };
      });
}
