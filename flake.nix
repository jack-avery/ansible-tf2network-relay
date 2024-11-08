{
  inputs = {
    naersk.url = "github:nix-community/naersk";
    nixpkgs.url = "nixpkgs/nixos-24.05";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    naersk,
    nixpkgs,
    fenix,
  }: let
    buildTargets = {
      "x86_64-linux" = {
        crossSystemConfig = "x86_64-unknown-linux-musl";
        rustTarget = "x86_64-unknown-linux-musl";
        imageTag = "x86_64";
      };

      "aarch64-linux" = {
        crossSystemConfig = "aarch64-unknown-linux-musl";
        rustTarget = "aarch64-unknown-linux-musl";
        imageTag = "aarch64";
      };
    };

    # eachSystem [system] (system: ...)
    #
    # Returns an attrset with a key for every system in the given array, with
    # the key's value being the result of calling the callback with that key.
    eachSystem = supportedSystems: callback:
      builtins.foldl'
      (overall: system: overall // {${system} = callback system;})
      {}
      supportedSystems;

    # eachCrossSystem [system] (buildSystem: targetSystem: ...)
    #
    # Returns an attrset with a key "$buildSystem.cross-$targetSystem" for
    # every combination of the elements of the array of system strings. The
    # value of the attrs will be the result of calling the callback with each
    # combination.
    #
    # There will also be keys "$system.default", which are aliases of
    # "$system.cross-$system" for every system.
    #
    eachCrossSystem = supportedSystems: callback:
      eachSystem supportedSystems (
        buildSystem:
          builtins.foldl'
          (inner: targetSystem:
            inner
            // {
              "${targetSystem}" = callback buildSystem targetSystem;
            })
          {default = callback buildSystem buildSystem;}
          supportedSystems
      );

    mkPkgs = buildSystem: targetSystem:
      import nixpkgs ({
          system = buildSystem;
        }
        // (
          if targetSystem == null
          then {}
          else {
            # The nixpkgs cache doesn't have any packages where cross-compiling has
            # been enabled, even if the target platform is actually the same as the
            # build platform (and therefore it's not really cross-compiling). So we
            # only set up the cross-compiling config if the target platform is
            # different.
            crossSystem.config = buildTargets.${targetSystem}.crossSystemConfig;
          }
        ));
  in rec {
    packages =
      eachCrossSystem
      (builtins.attrNames buildTargets)
      (
        buildSystem: targetSystem: let
          pkgs = mkPkgs buildSystem null;
          pkgsCross = mkPkgs buildSystem targetSystem;
          rustTarget = buildTargets.${targetSystem}.rustTarget;
          imageTag = buildTargets.${targetSystem}.imageTag;

          fenixPkgs = fenix.packages.${buildSystem};

          mkToolchain = fenixPkgs:
            fenixPkgs.toolchainOf {
              channel = "stable";
              sha256 = "sha256-yMuSb5eQPO/bHv+Bcf/US8LVMbf/G/0MSfiPwBhiPpk=";
            };

          toolchain = fenixPkgs.combine [
            (mkToolchain fenixPkgs).rustc
            (mkToolchain fenixPkgs).cargo
            (mkToolchain fenixPkgs.targets.${rustTarget}).rust-std
          ];

          naersk-lib = pkgs.callPackage naersk {
            cargo = toolchain;
            rustc = toolchain;
          };
        in {
          image = pkgs.dockerTools.buildImage {
            name = "jackavery/ansible-tf2network-relay";
            tag = "latest-${imageTag}";
            architecture = "${imageTag}";
            created = "now";

            copyToRoot = ["${packages.${buildSystem}.${targetSystem}.binary}/bin"];

            config = {
              Cmd = ["/ansible-tf2network-relay"];
            };
          };

          binary = naersk-lib.buildPackage rec {
            src = ./.;
            strictDeps = true;
            doCheck = false;

            # Required because ring crate is special. This also seems to have
            # fixed some issues with the x86_64-windows cross-compile :shrug:
            TARGET_CC = "${pkgsCross.stdenv.cc}/bin/${pkgsCross.stdenv.cc.targetPrefix}cc";

            CARGO_BUILD_TARGET = rustTarget;
            CARGO_BUILD_RUSTFLAGS = [
              "-C"
              "target-feature=+crt-static"

              "-C"
              "link-args=-static"

              # https://github.com/rust-lang/cargo/issues/4133
              "-C"
              "linker=${TARGET_CC}"
            ];
          };
        }
      );
  };
}
