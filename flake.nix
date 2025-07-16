{
  description = "OpenCode - AI coding agent for the terminal";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      # Overlay for integration with other flakes
      overlay = final: prev: {
        opencode = final.callPackage ./package.nix { };
      };
    in
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          overlays = [ overlay ];
        };
      in
      {
        packages = {
          default = pkgs.opencode;
          opencode = pkgs.opencode;
        };
        
        # App definition for `nix run`
        apps = {
          default = {
            type = "app";
            program = "${pkgs.opencode}/bin/opencode";
          };
        };

        # Development shell with minimal required tools
        devShells.default = pkgs.mkShell {
          buildInputs = with pkgs; [
            nixpkgs-fmt    # Nix code formatting
            nix-prefetch-git # For updating dependencies
            cachix         # For binary caching
            gh             # GitHub CLI for automation
          ];
        };
      }) // {
        # Export overlay for use in other flakes
        overlays.default = overlay;
      };
}