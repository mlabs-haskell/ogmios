# NixOS module for configuring Ogmios service.
{ config, lib, pkgs, ... }:
let
  cfg = config.services.ogmios;
in
{
  options.services.ogmios = with lib; with types; {
    enable = mkEnableOption "Ogmios lightweight bridge interface for cardano-node";

    package = mkOption {
      description = "Ogmios package";
      type = package;
    };

    user = mkOption {
      description = "User to run Ogmios service as.";
      type = types.str;
      default = "ogmios";
    };

    group = mkOption {
      description = "Group to run Ogmios service as.";
      type = types.str;
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
      default = "127.0.0.1";
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

  config = lib.mkIf cfg.enable {
    # get configuration from cardano-node module if there is one
    services.ogmios = lib.mkIf (config ? services.cardano-node && config.services.cardano-node.enable) {
      nodeSocket = lib.mkDefault config.services.cardano-node.socketPath;
      # hacky way to get cardano-node config path from service
      nodeConfig = lib.mkDefault (builtins.head (
        builtins.match ''.* (/nix/store/[a-zA-Z0-9]+-config-0-0\.json) .*''
          (builtins.readFile (builtins.replaceStrings [ " " ] [ "" ] config.systemd.services.cardano-node.serviceConfig.ExecStart))
      ));
    };

    users.users.ogmios = lib.mkIf (cfg.user == "ogmios") {
      isSystemUser = true;
      group = cfg.group;
      extraGroups = [ "cardano-node" ];
    };
    users.groups.ogmios = lib.mkIf (cfg.group == "ogmios") { };

    systemd.services.ogmios = {
      enable = true;
      after = [ "cardano-node.service" ];
      wantedBy = [ "multi-user.target" ];

      script = toString ([
        "${cfg.package}/bin/ogmios"
        "--node-socket ${cfg.nodeSocket}"
        "--node-config ${cfg.nodeConfig}"
        "--host ${cfg.host}"
        "--port ${toString cfg.port}"
      ] ++ cfg.extraArgs);

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

    assertions = lib.mkIf (config ? services.cardano-node && config.services.cardano-node.enable) [{
      assertion = config.services.cardano-node.systemdSocketActivation;
      message = "The option services.cardano-node.systemdSocketActivation needs to be enabled to use Ogmios with the cardano-node configured by that module.";
    }];
  };
}
