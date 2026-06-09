#!/usr/bin/env bash
# shellcheck disable=SC2086
#
# install-packages.sh — update system & install base packages (multi-distro),
# with a grouped checkbox menu to pick exactly which actions/packages to run.
# Package managers: apt, dnf, yum, pacman, zypper, apk.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/wanforge/server-mine/main/script/install-packages.sh | bash
#
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 Sugeng Sulistiyawan
#
set -euo pipefail
TASK="install-packages"

# --- shared library: banner, colors, logging, prompts, checkbox ----------
__LIB="https://raw.githubusercontent.com/wanforge/server-mine/main/script/lib.sh"
__d="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -r "${__d}/lib.sh" ]; then . "${__d}/lib.sh"
else if command -v curl >/dev/null 2>&1; then . <(curl -fsSL "${__LIB}"); else . <(wget -qO- "${__LIB}"); fi; fi

# ---- package manager ----------------------------------------------------
detect_pm() { for pm in apt-get dnf yum pacman zypper apk; do command -v "$pm" >/dev/null 2>&1 && { echo "$pm"; return 0; }; done; return 1; }
PM="$(detect_pm)" || { err "No supported package manager found."; exit 1; }

pm_update()  { case "${PM}" in apt-get) run ${SUDO} apt-get update ;; dnf) run ${SUDO} dnf -y makecache ;; yum) run ${SUDO} yum -y makecache ;; pacman) run ${SUDO} pacman -Sy --noconfirm ;; zypper) run ${SUDO} zypper --non-interactive refresh ;; apk) run ${SUDO} apk update ;; esac; }
pm_upgrade() { case "${PM}" in apt-get) run ${SUDO} apt-get upgrade -y ;; dnf) run ${SUDO} dnf -y upgrade --refresh ;; yum) run ${SUDO} yum -y update ;; pacman) run ${SUDO} pacman -Su --noconfirm ;; zypper) run ${SUDO} zypper --non-interactive update ;; apk) run ${SUDO} apk upgrade ;; esac; }
pm_install() { local pkgs="$*"; [ -z "$pkgs" ] && return 0; case "${PM}" in apt-get) run ${SUDO} apt-get install -y ${pkgs} ;; dnf) run ${SUDO} dnf -y install ${pkgs} ;; yum) run ${SUDO} yum -y install ${pkgs} ;; pacman) run ${SUDO} pacman -S --noconfirm --needed ${pkgs} ;; zypper) run ${SUDO} zypper --non-interactive install ${pkgs} ;; apk) run ${SUDO} apk add ${pkgs} ;; esac; }
pm_cleanup() { case "${PM}" in apt-get) run ${SUDO} apt-get autoremove -y; run ${SUDO} apt-get autoclean ;; dnf) run ${SUDO} dnf -y autoremove; run ${SUDO} dnf clean all ;; yum) run ${SUDO} yum -y autoremove || true; run ${SUDO} yum clean all ;; pacman) run ${SUDO} pacman -Qtdq 2>/dev/null | run ${SUDO} pacman -Rns --noconfirm - 2>/dev/null || true ;; zypper) run ${SUDO} zypper clean --all ;; apk) : ;; esac; }

# resolve a logical package key to the distro package name (empty = skip)
pkg_name() {
  case "$1" in
    micro|curl|wget|git) echo "$1" ;;
    speedtest-cli) case "${PM}" in apk) echo "" ;; *) echo speedtest-cli ;; esac ;;
    python3) case "${PM}" in pacman) echo python ;; *) echo python3 ;; esac ;;
    pip) case "${PM}" in apt-get|dnf|yum|zypper) echo python3-pip ;; pacman) echo python-pip ;; apk) echo py3-pip ;; esac ;;
    dev) case "${PM}" in apt-get|apk) echo python3-dev ;; dnf|yum|zypper) echo python3-devel ;; pacman) echo "" ;; esac ;;
    venv) case "${PM}" in apt-get|dnf|yum|zypper) echo python3-virtualenv ;; pacman) echo python-virtualenv ;; apk) echo py3-virtualenv ;; esac ;;
  esac
}

# ---- menu ---------------------------------------------------------------
MENU=(
  "System|update|Refresh package index"
  "System|upgrade|Upgrade installed packages"
  "System|cleanup|Autoremove + clean cache"
  "Editor|micro|Modern terminal text editor"
  "Network|curl|Transfer data / fetch URLs"
  "Network|wget|Download files over HTTP/FTP"
  "VCS|git|Distributed version control"
  "Diagnostics|speedtest-cli|Internet speed test (CLI)"
  "Python|python3|Python 3 interpreter"
  "Python|pip|Python package manager (pip)"
  "Python|dev|Python headers for building modules"
  "Python|venv|Isolated Python environments (virtualenv)"
)

# ---- run ----------------------------------------------------------------
banner
info "Package manager: ${C_BOLD}${PM}${C_RESET}"
checkbox "Select actions & packages to install:" || { warn "Cancelled."; exit 0; }
[ "${#CHOSEN_KEYS[@]}" -eq 0 ] && { warn "Nothing selected."; exit 0; }

has_key update  && { info "Refreshing package index..."; pm_update; }
has_key upgrade && { info "Upgrading installed packages..."; pm_upgrade; }

# collect selected packages (resolved per distro)
PKGS=""
for key in micro curl wget git speedtest-cli python3 pip dev venv; do
  if has_key "$key"; then p="$(pkg_name "$key")"; [ -n "$p" ] && PKGS="${PKGS} ${p}"; fi
done
if [ -n "${PKGS# }" ]; then info "Installing:${PKGS}"; pm_install ${PKGS}; fi

# speedtest-cli pip fallback where the package is unavailable
if has_key speedtest-cli && ! command -v speedtest-cli >/dev/null 2>&1 && command -v pip3 >/dev/null 2>&1; then
  info "speedtest-cli not in repo; installing via pip3"; pip3 install --user speedtest-cli >/dev/null 2>&1 || true
fi

has_key cleanup && { info "Cleaning up..."; pm_cleanup; }

printf "\n%b✔ Packages ready.%b\n\n" "${C_BOLD}${C_GREEN}" "${C_RESET}" >&2
