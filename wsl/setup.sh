#!/usr/bin/env bash
# setup.sh — prepare a clean Debian/Ubuntu (WSL) environment for the
# terraform-bootstrap-project-gcp repo.
#
# Usage:
#   ./setup.sh                         # install latest of everything
#   GCLOUD_VERSION=540.0.0 ./setup.sh  # pin gcloud to a specific release
#   TERRAFORM_VERSION=1.13.3 ./setup.sh  # pin terraform to a specific release
#
# Idempotent: safe to re-run; steps that are already done are skipped.

set -euo pipefail

# ----------------------------------------------------------------------------
# Config (override via environment)
# ----------------------------------------------------------------------------
GCLOUD_VERSION="${GCLOUD_VERSION:-}"         # empty = latest
TERRAFORM_VERSION="${TERRAFORM_VERSION:-}"   # empty = latest

GCLOUD_KEYRING=/usr/share/keyrings/cloud.google.gpg
GCLOUD_APT_LIST=/etc/apt/sources.list.d/google-cloud-sdk.list
GCLOUD_REPO_URL=https://packages.cloud.google.com/apt

HASHICORP_KEYRING=/usr/share/keyrings/hashicorp-archive-keyring.gpg
HASHICORP_APT_LIST=/etc/apt/sources.list.d/hashicorp.list
HASHICORP_REPO_URL=https://apt.releases.hashicorp.com

# ----------------------------------------------------------------------------
# Helpers
# ----------------------------------------------------------------------------
log()  { printf '\n==> %s\n' "$*"; }
skip() { printf '    [skip] %s\n' "$*"; }
have() { command -v "$1" >/dev/null 2>&1; }

require_debian_family() {
  if ! have apt-get; then
    echo "This script expects a Debian/Ubuntu system with apt-get." >&2
    exit 1
  fi
}

# ----------------------------------------------------------------------------
# Steps
# ----------------------------------------------------------------------------
install_base_packages() {
  log "Installing base packages"
  sudo apt-get update
  sudo apt-get install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    git \
    gnupg \
    openssh-client \
    python3 \
    python3-venv \
    python3-pip \
    unzip
}

install_gcloud() {
  log "Installing Google Cloud CLI"

  if [[ ! -f "$GCLOUD_KEYRING" ]]; then
    curl -fsSL "$GCLOUD_REPO_URL/doc/apt-key.gpg" \
      | sudo gpg --dearmor -o "$GCLOUD_KEYRING"
  else
    skip "signing key already present"
  fi

  if [[ ! -f "$GCLOUD_APT_LIST" ]]; then
    echo "deb [signed-by=$GCLOUD_KEYRING] $GCLOUD_REPO_URL cloud-sdk main" \
      | sudo tee "$GCLOUD_APT_LIST" >/dev/null
    sudo apt-get update
  else
    skip "apt source already configured"
  fi

  local pkg=google-cloud-cli
  if [[ -n "$GCLOUD_VERSION" ]]; then
    pkg="google-cloud-cli=${GCLOUD_VERSION}-0"
  fi
  sudo apt-get install -y "$pkg"

  gcloud --version | head -n 1
}

install_terraform() {
  log "Installing Terraform"

  # Distro codename (e.g. bookworm, trixie, noble) without needing lsb_release.
  local codename
  codename="$(. /etc/os-release && echo "${VERSION_CODENAME:-}")"
  if [[ -z "$codename" ]]; then
    echo "Could not determine distro codename from /etc/os-release." >&2
    exit 1
  fi

  if [[ ! -f "$HASHICORP_KEYRING" ]]; then
    curl -fsSL "$HASHICORP_REPO_URL/gpg" \
      | sudo gpg --dearmor -o "$HASHICORP_KEYRING"
  else
    skip "signing key already present"
  fi

  if [[ ! -f "$HASHICORP_APT_LIST" ]]; then
    echo "deb [signed-by=$HASHICORP_KEYRING] $HASHICORP_REPO_URL $codename main" \
      | sudo tee "$HASHICORP_APT_LIST" >/dev/null
    sudo apt-get update
  else
    skip "apt source already configured"
  fi

  local pkg=terraform
  if [[ -n "$TERRAFORM_VERSION" ]]; then
    pkg="terraform=${TERRAFORM_VERSION}-*"
  fi
  sudo apt-get install -y "$pkg"

  terraform -version | head -n 1
}

# TODO: setup_python_venv (follow-on/00-identity-seed)

# ----------------------------------------------------------------------------
main() {
  require_debian_family
  install_base_packages
  install_gcloud
  install_terraform

  log "Done. Next: gcloud auth login (see README)."
}

main "$@"
