{
  description = "androidtv-wol";
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
  outputs = {
    nixpkgs,
    pyproject-nix,
    uv2nix,
    pyproject-build-systems,
    ...
  }: let
    system = "x86_64-linux";

    pyVerRaw = builtins.replaceStrings ["\n"] [""] (builtins.readFile ./.python-version);
    pyVerAttr = "python" + builtins.replaceStrings ["."] [""] pyVerRaw;

    pkgs = import nixpkgs {inherit system;};
    py = pkgs.${pyVerAttr};

    workspace = uv2nix.lib.workspace.loadWorkspace {workspaceRoot = ./.;};
    projectOverlay = workspace.mkPyprojectOverlay {sourcePreference = "wheel";};
    pythonSet =
      (pkgs.callPackage pyproject-nix.build.packages {
        python = py;
      }).overrideScope (nixpkgs.lib.composeManyExtensions [
        pyproject-build-systems.overlays.wheel
        projectOverlay
      ]);
  in {
    devShells.${system}.default = let
      venv = pythonSet.mkVirtualEnv "androidtv-wol-dev" {};
    in
      pkgs.mkShell {
        name = "androidtv-wol";
        packages = with pkgs; [bashInteractive uv prettier];
        shellHook = ''
          export VIRTUAL_ENV="${venv}"
          export PATH="${venv}/bin:$PATH"
          echo "androidtv-wol dev shell"
          echo "Python: $(${py}/bin/python3 --version)"
        '';
      };
  };
}
