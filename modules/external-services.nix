# External Services Configuration
# This file contains services that are NOT managed by NixOS but should appear on the homepage
# Examples: OPNSense firewall, routers, switches, printers, etc.
{
  config,
  lib,
  ...
}: {
  # Define external services in globals.services
  # These services can then be picked up by the homepage dashboard

  globals.services = {
    # Example: OPNSense Firewall
    # opnsense = {
    #   domain = "firewall.czichy.com";
    #   homepage = {
    #     enable = true;
    #     name = "OPNSense";
    #     icon = "sh-opnsense";
    #     description = "Firewall & Router";
    #     category = "Infrastructure";
    #     priority = 1;
    #   };
    # };

    # Example: Router/Switch
    # router = {
    #   domain = "router.local";
    #   homepage = {
    #     enable = true;
    #     name = "Router";
    #     icon = "mdi-router-wireless";
    #     description = "Main Router";
    #     category = "Network & Management";
    #     priority = 5;
    #   };
    # };

    # Example: Network Switch
    # switch = {
    #   domain = "switch.local";
    #   homepage = {
    #     enable = true;
    #     name = "Network Switch";
    #     icon = "mdi-switch";
    #     description = "Main Switch";
    #     category = "Network & Management";
    #     priority = 15;
    #   };
    # };

    # Example: Printer
    # printer = {
    #   domain = "printer.local";
    #   homepage = {
    #     enable = true;
    #     name = "Brother Printer";
    #     icon = "mdi-printer";
    #     description = "Network Printer";
    #     category = "Network & Management";
    #     priority = 20;
    #   };
    # };

    # Example: NAS (wenn nicht über NixOS verwaltet)
    # nas = {
    #   domain = "nas.local";
    #   homepage = {
    #     enable = true;
    #     name = "NAS";
    #     icon = "mdi-nas";
    #     description = "Network Attached Storage";
    #     category = "Storage & Files";
    #     priority = 1;
    #   };
    # };

    # Example: Proxmox Host (wenn vorhanden)
    # proxmox = {
    #   domain = "proxmox.czichy.com";
    #   homepage = {
    #     enable = true;
    #     name = "Proxmox";
    #     icon = "sh-proxmox";
    #     description = "Virtualization Platform";
    #     category = "Infrastructure";
    #     priority = 10;
    #   };
    # };
  };
}
