# This is a NixOS configuration to test Ogmios with cardano-node. Run it like this:
# nix run '.#vm'
{ config, modulesPath, pkgs, ... }:
{
  imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];

  virtualisation = {
    memorySize = 8192;
    diskSize = 100000;
    forwardPorts = [
      { from = "host"; host.port = 2222; guest.port = 22; }
      { from = "host"; host.port = 1337; guest.port = 1337; }
    ];
  };

  # WARNING: root access with empty password for debugging via console and ssh
  networking.firewall.enable = false;
  services.getty.autologinUser = "root";
  services.openssh.enable = true;
  services.openssh.permitRootLogin = "yes";
  users.extraUsers.root.password = "";
  users.mutableUsers = false;

  # cardano-node and ogmios configuration
  services.cardano-node.enable = true;
  services.cardano-node.systemdSocketActivation = true;
  services.ogmios.enable = true;
  services.ogmios.host = "0.0.0.0";
}
