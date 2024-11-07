{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
    naersk.url = "github:nix-community/naersk";
    nixpkgs.url = "nixpkgs/nixos-24.05";
    fenix = {
      url = "github:nix-community/fenix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = {
    self,
    flake-utils,
    naersk,
    nixpkgs,
    fenix,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = (import nixpkgs) {inherit system;};
        toolchain = with fenix.packages.${system};
          combine [
            minimal.rustc
            minimal.cargo
            targets.x86_64-unknown-linux-musl.latest.rust-std
          ];
        naersk-lib = naersk.lib.${system}.override {
          cargo = toolchain;
          rustc = toolchain;
        };
        targets = ["x86_64" "aarch64"];
        forAllTargets = nixpkgs.lib.genAttrs targets;
      in forAllTargets (target: rec
        {
          defaultPackage = packages.image.${system};

          packages.image.${system} = pkgs.dockerTools.buildImage {
            name = "ansible-tf2network-relay";
            tag = "latest";
            copyToRoot = ["${packages.binary.${system}}/bin"];
            config = {
              Cmd = ["/ansible-tf2network-relay"];
            };
          };

          packages.binary.${system} = naersk-lib.buildPackage {
            src = ./.;

            nativeBuildInputs = with pkgs; [pkgsStatic.stdenv.cc];
            CARGO_BUILD_TARGET = "x86_64-unknown-linux-musl";
            CARGO_BUILD_RUSTFLAGS = "-C target-feature=+crt-static";
            doCheck = true;
          };
      }
    );
}
