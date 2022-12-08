# NixOS module for configuring Ogmios service.
{ config, lib, pkgs, ... }:
let
  cfg = config.services.ogmios;
in
with lib; {
  options.services.ogmios = with types; {
    enable = mkEnableOption "Ogmios lightweight bridge interface for cardano-node";

    package = mkOption {
      description = "Ogmios package";
      type = package;
      default = pkgs.ogmios;
    };

    user = mkOption {
      description = "User to run Ogmios service as.";
      type = str;
      default = "ogmios";
    };

    group = mkOption {
      description = "Group to run Ogmios service as.";
      type = str;
      default = "ogmios";
    };

    nodeSocket = mkOption {
      description = "Path to cardano-node IPC socket.";
      type = path;
      default = "/run/cardano-node/node.socket";
    };

    nodeConfig = mkOption {
      description = "Path to cardano-node config.json file.";
      type = path;
      default = if (config.services.cardano-node.enable or false) then config.services.cardano-node.nodeConfigFile else null;
    };

    host = mkOption {
      description = "Host address or name to listen on.";
      type = str;
      default = "localhost";
    };

    port = mkOption {
      description = "TCP port to listen on.";
      type = port;
      default = 1337;
    };

    extraArgs = mkOption {
      description = "Extra arguments to ogmios command.";
      type = listOf str;
      default = [ ];
    };
  };

  config = mkIf cfg.enable {
    assertions = [{
      assertion = config.services.cardano-node.enable or false -> config.services.cardano-node.systemdSocketActivation;
      message = "The option services.cardano-node.systemdSocketActivation needs to be enabled to use Ogmios with the cardano-node configured by that module. Otherwise cardano-node socket has wrong permissions.";
    }];

    users.users.ogmios = mkIf (cfg.user == "ogmios") {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = [ "cardano-node" ];
    };
    users.groups.ogmios = mkIf (cfg.group == "ogmios") { };

    systemd.services.ogmios = {
      enable = true;
      after = [ "cardano-node.service" ];
      wantedBy = [ "multi-user.target" ];

      script = escapeShellArgs (concatLists [
        [ "${cfg.package}/bin/ogmios" ]
        [ "--node-socket" cfg.nodeSocket ]
        [ "--node-config" cfg.nodeConfig ]
        [ "--host" cfg.host ]
        [ "--port" cfg.port ]
        cfg.extraArgs
      ]);

      serviceConfig = {
        User = cfg.user;
        Group = cfg.group;
        # Security
        UMask = "0077";
        AmbientCapabilities = [ "CAP_NET_BIND_SERVICE" ];
        CapabilityBoundingSet = [ "CAP_NET_BIND_SERVICE" ];
        ProcSubset = "pid";
        ProtectProc = "invisible";
        NoNewPrivileges = true;
        DevicePolicy = "closed";
        ProtectSystem = "strict";
        ProtectHome = true;
        PrivateTmp = true;
        PrivateDevices = true;
        PrivateUsers = true;
        ProtectHostname = true;
        ProtectClock = true;
        ProtectKernelTunables = true;
        ProtectKernelModules = true;
        ProtectKernelLogs = true;
        ProtectControlGroups = true;
        RestrictAddressFamilies = [ "AF_UNIX" "AF_INET" "AF_INET6" ];
        RestrictNamespaces = true;
        LockPersonality = true;
        RestrictRealtime = true;
        RestrictSUIDSGID = true;
        RemoveIPC = true;
        PrivateMounts = true;
        SystemCallArchitectures = "native";
        SystemCallFilter = [ "~@cpu-emulation @debug @keyring @mount @obsolete @privileged @setuid @resources" ];
        MemoryDenyWriteExecute = true;
      };
    };
  };
}
