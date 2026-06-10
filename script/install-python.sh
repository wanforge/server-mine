#!/usr/bin/env bash
# shellcheck disable=SC2086
#
# install-python.sh — install Python 3 + pip, venv/virtualenv, dev headers,
# and optionally pipx. Multi-distro: apt, dnf, yum, pacman, zypper, apk.
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/wanforge/scripts/main/script/install-python.sh | bash
#
# SPDX-License-Identifier: GPL-3.0-or-later
# Copyright (c) 2026 Sugeng Sulistiyawan
#
set -euo pipefail
TASK="install-python"

# --- shared library ------------------------------------------------------
__LIB="https://scripts.wanforge.asia/script/lib.sh"
__d="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -r "${__d}/lib.sh" ]; then . "${__d}/lib.sh"
else if command -v curl >/dev/null 2>&1; then . <(curl -fsSL "${__LIB}"); else . <(wget -qO- "${__LIB}"); fi; fi

detect_pm() { for pm in apt-get dnf yum pacman zypper apk; do command -v "$pm" >/dev/null 2>&1 && { echo "$pm"; return 0; }; done; return 1; }
PM="$(detect_pm)" || { err "No supported package manager found."; exit 1; }
pm_install() { local pkgs="$*"; [ -z "$pkgs" ] && return 0; case "${PM}" in
  apt-get) run ${SUDO} apt-get install -y ${pkgs} ;; dnf) run ${SUDO} dnf -y install ${pkgs} ;; yum) run ${SUDO} yum -y install ${pkgs} ;;
  pacman) run ${SUDO} pacman -S --noconfirm --needed ${pkgs} ;; zypper) run ${SUDO} zypper --non-interactive install ${pkgs} ;; apk) run ${SUDO} apk add ${pkgs} ;;
esac; }

# resolve logical key -> distro package (empty = handled another way)
pkg_name() {
  case "$1" in
    python3) case "${PM}" in pacman) echo python ;; *) echo python3 ;; esac ;;
    pip)     case "${PM}" in apt-get|dnf|yum|zypper) echo python3-pip ;; pacman) echo python-pip ;; apk) echo py3-pip ;; esac ;;
    venv)    case "${PM}" in apt-get) echo python3-venv ;; dnf|yum|zypper) echo python3-virtualenv ;; pacman) echo python-virtualenv ;; apk) echo py3-virtualenv ;; esac ;;
    dev)     case "${PM}" in apt-get|apk) echo python3-dev ;; dnf|yum|zypper) echo python3-devel ;; pacman) echo "" ;; esac ;;
    pipx)    case "${PM}" in apt-get|dnf|yum) echo pipx ;; pacman) echo python-pipx ;; zypper) echo python3-pipx ;; apk) echo "" ;; esac ;;
  esac
}

# ---- menu ---------------------------------------------------------------
MENU=(
  "Python|python3|Python 3 interpreter"
  "Python|pip|pip — package manager"
  "Python|venv|venv / virtualenv — isolated environments"
  "Python|dev|Dev headers (build C extensions)"
  "Python|pipx|pipx — install Python CLI apps in isolation"
)

# ---- run ----------------------------------------------------------------
banner
info "Package manager: ${C_BOLD}${PM}${C_RESET}"
checkbox "Select Python components:" || { warn "Cancelled."; exit 0; }
[ "${#CHOSEN_KEYS[@]}" -eq 0 ] && { warn "Nothing selected."; exit 0; }

[ "${PM}" = "apt-get" ] && run ${SUDO} apt-get update

PKGS=""
for key in python3 pip venv dev pipx; do
  if has_key "$key"; then p="$(pkg_name "$key")"; [ -n "$p" ] && PKGS="${PKGS} ${p}"; fi
done
[ -n "${PKGS# }" ] && { info "Installing:${PKGS}"; pm_install ${PKGS}; }

# pipx fallback via pip where no package exists; ensure PATH
if has_key pipx && ! command -v pipx >/dev/null 2>&1 && command -v pip3 >/dev/null 2>&1; then
  info "Installing pipx via pip (user)"; pip3 install --user pipx >/dev/null 2>&1 || true
  command -v pipx >/dev/null 2>&1 && run pipx ensurepath || true
fi

printf "\n%b✔ Python ready.%b\n" "${C_BOLD}${C_GREEN}" "${C_RESET}" >&2
command -v python3 >/dev/null 2>&1 && printf "%b  %s%b\n" "${C_DIM}" "$(python3 --version 2>&1)" "${C_RESET}" >&2
command -v pip3    >/dev/null 2>&1 && printf "%b  %s%b\n" "${C_DIM}" "$(pip3 --version 2>&1 | cut -d' ' -f1-2)" "${C_RESET}" >&2
printf "%b  New project venv:  python3 -m venv .venv && source .venv/bin/activate%b\n\n" "${C_DIM}" "${C_RESET}" >&2
