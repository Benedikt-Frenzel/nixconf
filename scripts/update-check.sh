#!/usr/bin/env bash
# update-check.sh — show what a NixOS update would change before applying it.
#
# Workflow:
#   1. Show age of the current system generation
#   2. Update flake inputs (nix flake update)
#   3. Build the new system (nh os build)
#   4. Diff old vs new closure, flag security-relevant packages
#   5. Prompt: proceed with `nh os boot` (geeky uses niri, so boot — not switch)
#
# Usage: update-check.sh [--yes] [--flake PATH] [--host NAME]
#   --yes       Skip the confirmation prompt (for scripting)
#   --flake     Flake path (default: $NH_FLAKE or /home/ben/Projects/nixconf)
#   --host      NixOS configuration name (default: geeky)

set -euo pipefail

FLAKE="${NH_FLAKE:-/home/ben/Projects/nixconf}"
HOST="${NH_HOSTNAME:-geeky}"
AUTO_YES=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --yes) AUTO_YES=1; shift ;;
    --flake) FLAKE="$2"; shift 2 ;;
    --host) HOST="$2"; shift 2 ;;
    *) echo "Unknown option: $1" >&2; exit 2 ;;
  esac
done

# Packages whose updates are security-relevant. Matched against the
# package name (pname) in the diff output.
declare -A SECURITY_CRITICAL=(
  ["linux"]="Kernel — reboot required, lanzaboote re-signs the boot path"
  ["systemd"]="Init system — core attack surface"
  ["sudo"]="Privilege escalation"
  ["openssh"]="Remote access"
  ["cryptsetup"]="Disk encryption (LUKS)"
  ["lanzaboote"]="Bootloader — Secure Boot signing"
  ["sbctl"]="Secure Boot key management"
  ["firefox"]="Browser — usually contains security fixes"
  ["chromium"]="Browser — usually contains security fixes"
  ["fwupd"]="Firmware updates"
  ["glibc"]="Base C library — everything depends on it"
  ["networkmanager"]="Network stack"
  ["pipewire"]="Audio server — runs as user session"
  ["openssl"]="TLS library"
  ["gnupg"]="GPG — signing and encryption"
  ["polkit"]="Privilege escalation framework"
)

hr() { printf '\n\033[1m=== %s ===\033[0m\n' "$1"; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$1"; }
crit() { printf '\033[1;31m!! %s\033[0m\n' "$1"; }

# --- 1. Current system age ---------------------------------------------------
hr "Current system"
CURRENT="/run/current-system"
if [[ -e "$CURRENT" ]]; then
  gen_path=$(readlink -f "$CURRENT")
  gen_date=$(stat -c %y "$gen_path" 2>/dev/null || echo "unknown")
  gen_epoch=$(stat -c %Y "$gen_path" 2>/dev/null || echo 0)
  now=$(date +%s)
  days_old=$(( (now - gen_epoch) / 86400 ))
  echo "Generation : $gen_path"
  echo "Built      : $gen_date"
  echo "Age        : ${days_old} day(s)"
  if (( days_old >= 14 )); then
    warn "System is ${days_old} days old — consider updating soon."
  fi
else
  warn "No /run/current-system found — are you on NixOS?"
fi

# --- 2. Update flake inputs --------------------------------------------------
hr "Updating flake inputs"
cd "$FLAKE"
if ! git diff --quiet flake.lock 2>/dev/null; then
  warn "flake.lock has uncommitted changes — stash or commit first."
  exit 1
fi
nix flake update
if git diff --quiet flake.lock; then
  echo "No input changes — flake.lock is up to date."
  echo "Nothing to do."
  exit 0
fi
echo "flake.lock updated:"
git diff --stat flake.lock

# --- 3. Build new system -----------------------------------------------------
hr "Building new system"
if ! nh os build "$FLAKE#$HOST" 2>&1 | tail -20; then
  crit "Build failed. Fix errors and re-run."
  git checkout flake.lock
  exit 1
fi

NEW_SYSTEM=$(readlink -f "$FLAKE/result" 2>/dev/null || true)
if [[ -z "$NEW_SYSTEM" || ! -d "$NEW_SYSTEM" ]]; then
  crit "Build succeeded but no result symlink found at $FLAKE/result"
  git checkout flake.lock
  exit 1
fi
echo "New system: $NEW_SYSTEM"

# --- 4. Diff old vs new ------------------------------------------------------
hr "Package changes"
# nix store diff-closures output format (after stripping ANSI colors):
#   "pkg: ∅ → 1.0, 1.2 MiB"     — new package
#   "pkg: 1.0 → ∅, 1.2 MiB"     — removed package
#   "pkg: 1.0 → 2.0, 1.2 MiB"   — changed version
DIFF_OUTPUT=$(nix store diff-closures "$CURRENT" "$NEW_SYSTEM" 2>/dev/null \
  | sed 's/\x1b\[[0-9;]*m//g' || true)
if [[ -z "$DIFF_OUTPUT" ]]; then
  echo "No package differences found."
else
  echo "$DIFF_OUTPUT"
fi

# --- 5. Security flags -------------------------------------------------------
hr "Security-relevant changes"
SECURITY_HITS=0
declare -A flagged=()

while IFS= read -r line; do
  # Package name is everything before the first colon.
  pkg="${line%%:*}"
  # Trim leading/trailing whitespace.
  pkg="${pkg#"${pkg%%[![:space:]]*}"}"
  pkg="${pkg%"${pkg##*[![:space:]]}"}"
  [[ -z "$pkg" ]] && continue
  # Match against known critical packages (substring match on pname)
  for critical in "${!SECURITY_CRITICAL[@]}"; do
    if [[ "$pkg" == *"$critical"* ]]; then
      if [[ -z "${flagged[$critical]:-}" ]]; then
        crit "${critical}: ${SECURITY_CRITICAL[$critical]}"
        echo "     ${line}"
        flagged[$critical]=1
        SECURITY_HITS=$((SECURITY_HITS + 1))
      fi
      break
    fi
  done
done <<< "$DIFF_OUTPUT"

if (( SECURITY_HITS == 0 )); then
  echo "No security-critical packages in this update."
else
  warn "${SECURITY_HITS} security-relevant package(s) would be updated."
  warn "Delaying exposes the system to known vulnerabilities fixed in these versions."
fi

# --- 6. Summary + prompt -----------------------------------------------------
hr "Summary"
echo "Host       : $HOST"
echo "Flake      : $FLAKE"
if [[ -n "${DIFF_OUTPUT:-}" ]]; then
  # ∅ → version = added, version → ∅ = removed, old → new = changed
  added=$(echo "$DIFF_OUTPUT" | grep -c '∅ →' || true)
  removed=$(echo "$DIFF_OUTPUT" | grep -c '→ ∅' || true)
  changed=$(echo "$DIFF_OUTPUT" | grep -c '→' || true)
  changed=$((changed - added - removed))
  echo "Changes    : +${added} -${removed} ~${changed}"
fi
echo "Security   : ${SECURITY_HITS} critical package(s)"
echo "Action     : nh os boot (build + set as boot default, reboot to activate)"

if (( AUTO_YES )); then
  echo ""
  echo "Auto-confirmed (--yes)."
else
  echo ""
  read -rp "Proceed with 'nh os boot'? [y/N] " answer
  if [[ "$answer" != "y" && "$answer" != "Y" ]]; then
    echo "Aborted. Reverting flake.lock."
    git checkout flake.lock
    rm -f "$FLAKE/result"
    exit 0
  fi
fi

# --- 7. Apply ----------------------------------------------------------------
hr "Applying"
nh os boot "$FLAKE#$HOST"
echo ""
echo "Done. The new generation is set as boot default."
echo "Reboot to activate: sudo reboot"
echo ""
echo "After reboot, commit the updated flake.lock:"
echo "  cd $FLAKE && git add flake.lock && git commit -m 'flake: update inputs'"
