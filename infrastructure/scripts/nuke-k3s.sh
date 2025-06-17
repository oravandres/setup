#!/bin/bash
set -euo pipefail

# nuke-k3s.sh: Completely remove k3s and related data from a remote host.
# Usage: ./nuke-k3s.sh <hostname> [--yes|--no-reboot]

if [[ $# -lt 1 || "${1:0:1}" == "-" ]]; then
  echo "[ERROR] Usage: ./nuke-k3s.sh <hostname> [--yes|--no-reboot]" >&2
  exit 1
fi

HOSTNAME_ARG="$1"
shift

REBOOT_PROMPT=1
if [[ "${1:-}" == "--yes" ]]; then
  REBOOT_PROMPT=0
elif [[ "${1:-}" == "--no-reboot" ]]; then
  REBOOT_PROMPT=2
fi

echo "[INFO] Target hostname: $HOSTNAME_ARG"

# Test SSH connectivity
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$HOSTNAME_ARG" "echo 'SSH connection successful'" 2>/dev/null; then
  echo "[ERROR] Cannot establish SSH connection to $HOSTNAME_ARG" >&2
  echo "[ERROR] Please ensure:"
  echo "  - The hostname is reachable"
  echo "  - SSH key authentication is set up"
  echo "  - The target host allows SSH connections"
  exit 1
fi

echo "[INFO] SSH connection to $HOSTNAME_ARG established successfully"

echo "[INFO] Uninstalling k3s server on $HOSTNAME_ARG (if present)..."
ssh "$HOSTNAME_ARG" "sudo /usr/local/bin/k3s-uninstall.sh || echo '[WARN] k3s-uninstall.sh not found or already removed.'"

echo "[INFO] Uninstalling k3s agent on $HOSTNAME_ARG (if present)..."
ssh "$HOSTNAME_ARG" "sudo /usr/local/bin/k3s-agent-uninstall.sh || echo '[WARN] k3s-agent-uninstall.sh not found or already removed.'"

echo "[INFO] Killing all k3s-related processes and cleaning up CNI/iptables on $HOSTNAME_ARG..."
ssh "$HOSTNAME_ARG" "sudo /usr/local/bin/k3s-killall.sh || echo '[WARN] k3s-killall.sh not found or already removed.'"

echo "[INFO] Removing Rancher/k3s/kubelet data directories on $HOSTNAME_ARG..."
ssh "$HOSTNAME_ARG" "sudo rm -rf /etc/rancher /var/lib/rancher /var/lib/kubelet"

echo "[INFO] k3s and related data have been removed from $HOSTNAME_ARG."

if [[ $REBOOT_PROMPT -eq 2 ]]; then
  echo "[INFO] Skipping reboot as per --no-reboot flag."
  exit 0
fi

if [[ $REBOOT_PROMPT -eq 0 ]]; then
  echo "[INFO] Rebooting $HOSTNAME_ARG now (auto-confirmed)."
  ssh "$HOSTNAME_ARG" "sudo reboot" || echo "[INFO] Reboot command sent to $HOSTNAME_ARG"
  exit 0
fi

read -p "Do you want to reboot $HOSTNAME_ARG now? [y/N]: " answer
if [[ "$answer" =~ ^[Yy]$ ]]; then
  echo "[INFO] Rebooting $HOSTNAME_ARG..."
  ssh "$HOSTNAME_ARG" "sudo reboot" || echo "[INFO] Reboot command sent to $HOSTNAME_ARG"
else
  echo "[INFO] Reboot skipped. Please reboot $HOSTNAME_ARG manually if needed."
fi 