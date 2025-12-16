#!/usr/bin/env bash
set -euo pipefail

# ------------------------------------------------------------------------------
# 1. Configuration & Variables
# ------------------------------------------------------------------------------

# Terraform variables
DOTFILES_URL="${DOTFILES_URI}"
MODE="${MODE}"
PACKAGES="${PACKAGES}"
DOTFILES_USER="${DOTFILES_USER}"
STOW_PRESERVE="${PRESERVE_STASH}"

# ------------------------------------------------------------------------------
# 2. User Switching Logic
# ------------------------------------------------------------------------------

if [ -n "$DOTFILES_USER" ] && [ "$DOTFILES_USER" != "$(whoami)" ]; then
  echo "Switching to user $DOTFILES_USER to apply dotfiles..."
  SCRIPT_PATH=$(realpath "$0")
  
  export DOTFILES_URI="$DOTFILES_URL"
  export MODE="$MODE"
  export PACKAGES="$PACKAGES"
  export DOTFILES_USER="$DOTFILES_USER"
  export PRESERVE_STASH="$STOW_PRESERVE"

  # We preserve env to pass the vars, but we use sudo to switch users
  sudo -E -u "$DOTFILES_USER" bash "$SCRIPT_PATH"
  exit $?
fi

# ------------------------------------------------------------------------------
# 3. Define Directories
# ------------------------------------------------------------------------------

REPO_DIR="$HOME/.config/coderv2/dotfiles"
LOG_FILE="$HOME/.dotfiles.log"

{
  echo "--- Starting Dotfiles Link ($(date)) ---"

  # ------------------------------------------------------------------------------
  # 4. Pre-Flight: Handle Dirty State
  # ------------------------------------------------------------------------------
  # If the repo is dirty, `coder dotfiles` (which uses git pull) might fail.
  # We clean it up first so the official command succeeds.

  if [ -d "$REPO_DIR/.git" ]; then
    if [ -n "$(cd "$REPO_DIR" && git status --porcelain --untracked-files=all 2>/dev/null || true)" ]; then
      stash_name="pre-update-clean-$(date -u +%Y%m%dT%H%M%SZ)"
      echo "Rescuing dirty repo at $REPO_DIR to unblock coder dotfiles update..."
      echo "Stashing changes to '$stash_name'"
      (cd "$REPO_DIR" && git stash push --include-untracked -m "$stash_name") || true
    fi
  fi

  # ------------------------------------------------------------------------------
  # 5. Core Logic: Run Coder Dotfiles
  # ------------------------------------------------------------------------------
  
  if [ -n "$DOTFILES_URL" ]; then
    echo "Running coder dotfiles logic for $DOTFILES_URL..."
    coder dotfiles "$DOTFILES_URL" -y
  else
    echo "No DOTFILES_URI provided. Skipping coder dotfiles command."
    if [ ! -d "$REPO_DIR" ]; then
        echo "No local repo found at $REPO_DIR. Exiting."
        exit 0
    fi
  fi

  # ------------------------------------------------------------------------------
  # 6. Link/Install Logic (Stow Support)
  # ------------------------------------------------------------------------------

  path="$REPO_DIR"
  name=$(basename "$path")
  dest="$HOME/.dotfiles/$name"

  apply_copy() {
    cp -r "$1" "$2"
    echo "Copied $1 -> $2"
  }

  stow_target_dir=""
  package_list=""

  if [ -n "$PACKAGES" ]; then
    package_list="$PACKAGES"
    stow_target_dir="$path"
  else
    if [ -d "$path/dotfiles" ]; then
      package_list="dotfiles"
      stow_target_dir="$path"
    fi
    if [ -d "$path/home" ]; then
      # ESCAPED: Bash variable expansion
      package_list="$${package_list} home"
      stow_target_dir="$path"
    fi
    if [ -z "$package_list" ]; then
      base_name=$(basename "$path")
      if [ "$base_name" = "dotfiles" ] || [ "$base_name" = "home" ]; then
        package_list="$base_name"
        stow_target_dir=$(dirname "$path")
      fi
    fi
  fi

  if [ -z "$stow_target_dir" ]; then
    stow_target_dir="$path"
  fi

  case "$MODE" in
  symlink)
    if [ -n "$package_list" ] && command -v stow >/dev/null 2>&1; then
      echo "Using GNU stow to link packages ($package_list) from $stow_target_dir"
      for pkg in $package_list; do
        if [[ "$pkg" == *:* ]]; then
          # ESCAPED: Bash string manipulation
          origin="$${pkg%%:*}"
          target_spec="$${pkg#*:}"
          target="$${target_spec:-$HOME}"
        else
          origin="$pkg"
          target="$HOME"
        fi

        echo "Stowing package '$origin' -> '$target' (with --adopt)"
        (cd "$stow_target_dir" && stow -v --adopt -t "$target" "$origin") || true

        if [ "$STOW_PRESERVE" = "true" ] && [ -d "$stow_target_dir/.git" ]; then
          if [ -n "$(cd "$stow_target_dir" && git status --porcelain --untracked-files=all 2>/dev/null || true)" ]; then
            post_stow_stash="stow-adopt-$(date -u +%Y%m%dT%H%M%SZ)"
            echo "Stashing changes created by stow adoption to '$post_stow_stash'"
            (cd "$stow_target_dir" && git stash push --include-untracked -m "$post_stow_stash") || true
          fi
        fi
      done
    else
      echo "Stow not found or no packages detected. Falling back to basic linking."
    fi
    ;;
  copy)
    mkdir -p "$(dirname "$dest")"
    apply_copy "$path" "$dest"
    ;;
  none)
    echo "Mode set to none. Skipping linking."
    ;;
  *)
    echo "Unknown mode: $MODE"
    ;;
  esac

} 2>&1 | tee -a "$LOG_FILE"

exit 0
