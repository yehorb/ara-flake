{
  inputs = {
    pulpissimo.url = "github:yehorb/pulpissimo-flake";
    nixpkgs.follows = "pulpissimo/nixpkgs";
    systems.url = "github:nix-systems/default";
  };

  outputs =
    {
      self,
      nixpkgs,
      systems,
      ...
    }@inputs:
    let
      forEachSystem = nixpkgs.lib.genAttrs (import systems);
    in
    {
      packages = forEachSystem (system: { });

      devShells = forEachSystem (
        system:
        let
          pkgs = import nixpkgs {
            inherit system;
            config = { };
          };
        in
        {
          default = { };
        }
      );
    };
}
