# Local packages, exposed as pkgs.<name> through nixpkgs.overlays.
final: prev: {
  openchamber = final.callPackage ./openchamber.nix { };
}
