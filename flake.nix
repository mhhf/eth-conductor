{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-21.11";
    flake-utils = {
      url = "github:numtide/flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flake-utils }: 
    (flake-utils.lib.eachDefaultSystem (system:
      let 
        pkgs = import nixpkgs {
          inherit system;
        };
      in {
        devShell = pkgs.mkShell {
          packages = [
            pkgs.go-ethereum
          ];
        };
        nixosModule = import ./eth-conductor.nix;
      })) // {
        nixosConfigurations.container = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules =
            [ ({ pkgs, ... }: {
                boot.isContainer = true;

                # Let 'nixos-version --json' know about the Git revision
                # of this flake.
                system.configurationRevision = nixpkgs.lib.mkIf (self ? rev) self.rev;

                # Network configuration.
                networking.useDHCP = false;
                networking.firewall.allowedTCPPorts = [ 30311 30303 8501 ];
                networking.firewall.allowedUDPPorts = [ 30311 30303 8501 ];

                users.users = {
                  mhhf = {
                    isNormalUser = true;
                    home = "/home/mhhf";
                    description = "mhhf";
                    uid = 1000;
                  };
                };

                services.ethConductor.enable = true;
              })
              ./eth-conductor.nix
            ];
        };
      };
}
