# This is a NixOS configuration to test Ogmios with cardano-node. Run it like this:
# nix run '.#vm'
{ config, modulesPath, pkgs, ... }:
{
  # Virtual Machine configuration

  imports = [ "${modulesPath}/virtualisation/qemu-vm.nix" ];

  virtualisation = {
    memorySize = 8192;
    diskSize = 100000;
    forwardPorts = [
      { from = "host"; host.port = 2222; guest.port = 22; }
      { from = "host"; host.port = 1337; guest.port = 1337; }
    ];
  };

  # Easy debugging via console and ssh
  # WARNING: root access with empty password

  networking.firewall.enable = false;
  services.getty.autologinUser = "root";
  services.openssh.enable = true;
  services.openssh.permitRootLogin = "yes";
  users.extraUsers.root.password = "";
  users.mutableUsers = false;

  # Example cardano-node and ogmios configuration

  services.cardano-node = {
    enable = true;
    systemdSocketActivation = true;
    nodeConfigFile = "${pkgs.cardano-configurations}/network/preview/cardano-node/config.json";
    topology = "${pkgs.cardano-configurations}/network/preview/cardano-node/topology.json";
  };
  services.ogmios = {
    enable = true;
    host = "0.0.0.0";
  };
}
