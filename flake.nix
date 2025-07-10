{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs";
    flake-utils.url = "github:numtide/flake-utils";
    flake-compat = {
      url = "github:edolstra/flake-compat";
      flake = false;
    };
  };
  outputs = {
    self,
    nixpkgs,
    flake-utils,
    flake-compat,
  }:
    flake-utils.lib.eachDefaultSystem (
      system: let
        pkgs = nixpkgs.legacyPackages.${system};
      in rec {
        formatter = pkgs.alejandra;
        nixosModules.piv-agent = {
          lib,
          config,
          ...
        }:
          with lib; let
            cfg = config.services.piv-agent;
          in {
            options.services.piv-agent = {
              enable = mkEnableOption "Enables the piv-agent service";
            };
            config = mkIf cfg.enable {
              systemd.user.services.piv-agent = {
                description = "piv-agent service";
                serviceConfig.ExecStart = "${self.packages.${system}.piv-agent}/bin/piv-agent serve --agent-types=ssh=0;gpg=1";
              };
              systemd.user.sockets.piv-agent = {
                description = "piv-agent socket activation";
                listenStreams = [
                  "%t/piv-agent/ssh.socket"
                  "%t/gnupg/S.gpg-agent"
                ];
                wantedBy = ["sockets.target"];
              };
              environment.extraInit = ''
                if [ -z "$SSH_AUTH_SOCK" -a -n "$XDG_RUNTIME_DIR" ]; then
                  export SSH_AUTH_SOCK="$XDG_RUNTIME_DIR/piv-agent/ssh.socket"
                fi
              '';
            };
          };
        packages = flake-utils.lib.flattenTree {
          piv-agent = pkgs.buildGoModule rec {
            name = "piv-agent";
            version = "0.23.0";
            src = pkgs.fetchFromGitHub {
              owner = "smlx";
              repo = name;
              rev = "v${version}";
              hash = "sha256-4oyIUE7Yy0KUw5pC64MRKeUziy+tqvl/zFVySffxfBs=";
            };
            vendorHash = "sha256-4yfQQxMf00263OKEXTWD34YifK7oDclvPk8JDz5N1I0=";
            nativeBuildInputs = [pkgs.pkg-config pkgs.makeWrapper];
            buildInputs = [pkgs.pcsclite pkgs.pinentry-gtk2];
            postFixup = ''
              wrapProgram $out/bin/piv-agent \
                --suffix-each PATH : ${pkgs.lib.makeBinPath [
                pkgs.pinentry-gtk2
              ]}
            '';
            meta = {
              description = "piv-agent";
              homepage = "https://github.com/smlx/piv-agent";
            };
          };
        };
        defaultPackage = packages.piv-agent;
        apps.piv-agent = flake-utils.lib.mkApp {drv = packages.piv-agent;};
        defaultApp = apps.piv-agent;

        devShell = pkgs.mkShell {
          buildInputs = [
            pkgs.go_1_25
            pkgs.mockgen
            (pkgs.buildGoModule rec {
              name = "enumer";
              version = "1.5.11";
              src = pkgs.fetchFromGitHub {
                owner = "dmarkham";
                repo = name;
                rev = "v${version}";
                hash = "sha256-zFx4Djar2nC/kanoEkmHTumon2MwKMsoZU6/heUPW2I=";
              };
              vendorHash = "sha256-w9T9PWMJjBJP2MmhGC7e78zbszgCwtVrfO5AQlu/ugQ=";
              doCheck = false;
              meta = {
                description = "enumer";
                homepage = "https://github.com/dmarkham/enumer";
              };
            })
          ];
        };
      }
    );
}
