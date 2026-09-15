{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";
    nixpkgs-unstable.url = "github:NixOS/nixpkgs/nixos-unstable";

    home-manager = {
      url = "github:nix-community/home-manager/release-26.05";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    catppuccin = {
      url = "github:catppuccin/nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    zen-browser = {
      url = "github:youwen5/zen-browser-flake";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    # Noctalia shell (native C++/OpenGL ES, no Qt/GTK). Keeps upstream's own
    # nixpkgs pin: the package needs unstable, and following our stable input
    # would break the build.
    noctalia.url = "github:noctalia-dev/noctalia";

    # Noctalia Greeter for greetd (login screen), built against our existing
    # unstable nixpkgs to avoid a third copy.
    noctalia-greeter = {
      url = "github:noctalia-dev/noctalia-greeter";
      inputs.nixpkgs.follows = "nixpkgs-unstable";
    };
  };

  outputs =
    inputs@{
      nixpkgs,
      home-manager,
      catppuccin,
      ...
    }:
    {
      nixosConfigurations.ideapad = nixpkgs.lib.nixosSystem {
        system = "x86_64-linux";
        specialArgs = { inherit inputs; };
        modules = [
          ./hosts/ideapad/configuration.nix
          home-manager.nixosModules.home-manager
          catppuccin.nixosModules.catppuccin
          inputs.noctalia-greeter.nixosModules.default
        ];
      };
    };
}
