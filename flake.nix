{
  description = "Bitwise-deterministic reproducible release archives for lgc1-webos-wol";

  inputs = {
    nixpkgs.url = "https://flakehub.com/f/DeterminateSystems/nixpkgs-26.05-chilled/0.1";
    pyproject-nix = {
      url = "github:pyproject-nix/pyproject.nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    uv2nix = {
      url = "github:pyproject-nix/uv2nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    pyproject-build-systems = {
      url = "github:pyproject-nix/build-system-pkgs";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      pyproject-nix,
      uv2nix,
      pyproject-build-systems,
    }:
    let
      # Read version from pyproject.toml as source of truth
      version =
        let
          content = builtins.readFile ./pyproject.toml;
          lines = builtins.split "\n" content;
          filtered = builtins.filter (
            line: builtins.isString line && (builtins.substring 0 9 line) == "version ="
          ) lines;
          match = builtins.match ".*version = \"([^\"]+)\".*" (builtins.head filtered);
        in
        if match != null then builtins.head match else throw "Version not found in pyproject.toml";

      # Use epoch 1 for maximum determinism (Jan 1, 1970)
      epoch = 1;

      # Read Python version from .python-version
      pyVerRaw = builtins.replaceStrings [ "\n" ] [ "" ] (builtins.readFile ./.python-version);
      pyVerAttr = "python" + builtins.replaceStrings [ "." ] [ "" ] pyVerRaw;

      system = "x86_64-linux";

      pkgs = import nixpkgs { inherit system; };
      py = pkgs.${pyVerAttr};

      # Load workspace from uv.lock and create overlay for reproducible Python packages
      workspace = uv2nix.lib.workspace.loadWorkspace {
        workspaceRoot = ./.;
      };
      projectOverlay = workspace.mkPyprojectOverlay {
        sourcePreference = "wheel";
      };

      pythonSet =
        (pkgs.callPackage pyproject-nix.build.packages {
          python = py;
        }).overrideScope
          (
            nixpkgs.lib.composeManyExtensions [
              pyproject-build-systems.overlays.wheel
              projectOverlay
            ]
          );

      # Bitwise-deterministic release archive:
      #   lgc1-wol*.py, install.sh, LICENSE, README.md -> single zip file
      mkArchive = pkgs.stdenvNoCC.mkDerivation {
        name = "lgc1-webos-wol-${version}.zip";

        nativeBuildInputs = with pkgs; [
          coreutils
          findutils
          zip
        ];

        buildPhase = ''
          mkdir -m 755 staging

          install -m 644 ${./lgc1-wol.py}   staging/lgc1-wol.py
          install -m 644 ${./lgc1-wold.py}  staging/lgc1-wold.py
          install -m 755 ${./install.sh}    staging/install.sh
          install -m 644 ${./LICENSE}       staging/LICENSE
          install -m 644 ${./README.md}     staging/README.md

          find staging -exec touch -d "@${builtins.toString epoch}" {} +
          (cd staging && find . \( -type d -o -type f \) | LC_ALL=C sort | zip -X -q -@ $out)
        '';

        dontUnpack = true;
        dontInstall = true;
      };
    in
    {
      packages.${system}.default = mkArchive;

      devShells.${system}.default =
        let
          venv = pythonSet.mkVirtualEnv "androidtv-wol-dev" { };
        in
        pkgs.mkShell {
          name = "lgc1-webos-wol";

          packages = with pkgs; [
            bashInteractive
            coreutils
            findutils
            prettier
            uv
            zip
          ];

          shellHook = ''
            export VIRTUAL_ENV="${venv}"
            export PATH="${venv}/bin:$PATH"

            echo "lgc1-webos-wol development environment loaded"
            echo "Python: $(${py}/bin/python3 --version)"
            echo ""
            echo "Build with: make build    (local, uses this shell)"
            echo "Nix build: make build-nix (reproducible)"
          '';
        };
    };
}
