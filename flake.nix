{
  inputs = {
    flake-utils.url = "github:numtide/flake-utils";
  };
  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = import nixpkgs { inherit system; };

        python = pkgs.python3.withPackages (p: [p.pyparsing]);

        # API patch version, which must match VK_HEADER_VERSION in vk.xml
        patchVersion = builtins.head (builtins.match
          ".*\nPATCHVERSION = ([0-9]+)\n.*" (builtins.readFile ./Makefile));
      in {
        devShell = pkgs.mkShell {
          buildInputs = with pkgs; [
            python
            asciidoctor
            groff
          ];
        };

        packages.manpages = pkgs.stdenvNoCC.mkDerivation {
          pname = "vulkan-manpages";
          version = "1.4.${patchVersion}";

          src = pkgs.lib.fileset.toSource {
            root = ./.;
            fileset = pkgs.lib.fileset.unions [
              ./ChangeLog.adoc
              ./Makefile
              ./makeSpec
              ./makeManPages
              ./appendices
              ./chapters
              ./config
              ./images
              ./proposals
              ./scripts
              ./xml
            ];
          };

          nativeBuildInputs = [ python pkgs.asciidoctor ];

          postPatch = ''
            patchShebangs makeSpec makeManPages
          '';

          buildPhase = ''
            runHook preBuild
            # Date the man pages with the latest spec update, from the first
            # "Change log for October 2, 2026 Vulkan ..." line
            changeLogDate=$(sed -n \
                's/^Change log for \(.*, [0-9]*\) Vulkan .*/\1/p;T;q' \
                ChangeLog.adoc)
            manDate=$(date -u -d "''${changeLogDate:?not found in ChangeLog.adoc}" +%F)
            ./makeManPages -noclean -genpath "$PWD/genman" \
                -j "$NIX_BUILD_CORES" -- MANDATE="$manDate"
            runHook postBuild
          '';

          installPhase = ''
            runHook preInstall
            mkdir -p "$out/share/man/man3"
            cp genman/out/man/man3/*.3 "$out/share/man/man3"
            runHook postInstall
          '';

          meta = {
            description = "Vulkan API reference pages as man pages";
            homepage = "https://github.com/KhronosGroup/Vulkan-Docs";
            license = pkgs.lib.licenses.cc-by-40;
          };
        };
        packages.default = self.packages.${system}.manpages;
      }
    );
}
