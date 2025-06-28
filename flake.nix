{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs";
    flake-parts.url = "github:hercules-ci/flake-parts";
    systems.url = "github:nix-systems/default";
  };

  outputs = {
    self,
    nixpkgs,
    flake-parts,
    systems,
    ...
  }@inputs: flake-parts.lib.mkFlake { inherit inputs; } {
    systems = import inputs.systems;
    perSystem = { lib, pkgs, ... }: {
      packages.default = pkgs.callPackage ({
        stdenv,
        zig
      }: stdenv.mkDerivation (finalAttrs: {
        pname = "pipelet-workflow-runner";
        version = "0.1.0-git+${self.shortRev or "dirty"}";

        src = lib.cleanSource ./.;

        nativeBuildInputs = [
          zig
          zig.hook
        ];

        zigDeps = zig.fetchDeps {
          inherit (finalAttrs)
            src
            pname
            version
            ;
          hash = "sha256-VbVHoyCHxLFlETbvMo+rSL8INI0e27BOQuyv2Zq4CkA=";
        };

        postUnpack = ''
          ln -s ${finalAttrs.zigDeps} $ZIG_GLOBAL_CACHE_DIR/p
        '';

        meta = {
          description = "Workflow runner for pipelet.io";
          licenses = with lib.licenses; [ lgpl21Only ];
          maintainers = with lib.maintainers; [ RossComputerGuy ];
          homepage = "https://pipelet.io";
        };
      })) {};
    };
  };
}
