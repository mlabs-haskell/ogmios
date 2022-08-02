# This is a NixOS configuration to test Ogmios with cardano-node. Run it like this:
# nixos-rebuild build-vm --flake '.#test' &&  result/bin/run-vm
{ config, pkgs, ... }:
{
  # for debugging
  services.getty.autologinUser = "root";

  services.cardano-node.enable = true;
  services.cardano-node.systemdSocketActivation = true;

  services.ogmios.enable = true;
}
