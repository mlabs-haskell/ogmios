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
      type = str;
    };

    nodeConfig = mkOption {
      description = "Path to cardano-node config.json file.";
      type = str;
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
    assertions = mkIf (config ? services.cardano-node && config.services.cardano-node.enable) [{
      assertion = config.services.cardano-node.systemdSocketActivation;
      message = "The option services.cardano-node.systemdSocketActivation needs to be enabled to use Ogmios with the cardano-node configured by that module.";
    }];

    # get configuration from cardano-node module if there is one
    services.ogmios = mkIf (config ? services.cardano-node && config.services.cardano-node.enable) {
      nodeSocket = mkDefault config.services.cardano-node.socketPath;
      # hacky way to get cardano-node config path from service
      nodeConfig = mkDefault (builtins.head (
        builtins.match ''.* (/nix/store/[a-zA-Z0-9]+-config-0-0\.json) .*''
          (builtins.readFile (builtins.replaceStrings [ " " ] [ "" ] config.systemd.services.cardano-node.serviceConfig.ExecStart))
      ));
    };

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
