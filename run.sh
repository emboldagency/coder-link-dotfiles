#!/usr/bin/env bash
set -euo pipefail

# DOTFILES_URL is supplied by the Coder dotfiles module.
# Safely read values passed into the template from Terraform. The template
# provides DOTFILES_URIS, MODE, PACKAGES, PRESERVE_STASH, and WAIT_SECONDS.
# These are substituted by Terraform at template render time.
# Prefer DOTFILES_URI (used by Coder's dotfiles module). If DOTFILES_URI is
# empty at template render time, allow the runtime environment to supply
# DOTFILES_URI (for example when the script is executed directly) or fall
# back to the local ~/.config/coderv2/dotfilesurl file / local clone.
DOTFILES_URL="${DOTFILES_URI}"
MODE="${MODE}"
WAIT_SECONDS="${WAIT_SECONDS}"
# Optional: space-separated list of package specifiers for stow/manual handling.
# Each item may be a simple package name (e.g. "dotfiles") or an origin:target pair
# where `origin` is the directory inside the repo and `target` is an optional
# target path (absolute or relative to the user's home) e.g. "dotfiles" or
# "dotfiles:home" or "dotfiles:/etc/skel". If empty, the script will auto-detect
# conventional package dirs (dotfiles/ or home/).
PACKAGES="${PACKAGES}"

# Require DOTFILES_URI from the Coder module. If it's not provided the module
# didn't supply a dotfiles repo and there's nothing for this script to do.
if [ -z "$DOTFILES_URL" ]; then
  echo "No DOTFILES_URI provided by module; nothing to do"
  exit 0
fi

# Wait for coder to clone the dotfiles repo into ~/.config/coderv2/dotfiles
# Prefer the local clone when present; if it doesn't appear within WAIT_SECONDS
# we'll exit because there's nothing to work on.
if [ -n "$WAIT_SECONDS" ] && [ "$WAIT_SECONDS" -gt 0 ]; then
  echo "Waiting up to $WAIT_SECONDS seconds for coder to populate ~/.config/coderv2/dotfiles..."
  start=$(date +%s)
  while true; do
    if [ -d "$HOME/.config/coderv2/dotfiles" ] && [ "$(ls -A "$HOME/.config/coderv2/dotfiles" 2>/dev/null || true)" != "" ]; then
      echo "Detected local coder clone at ~/.config/coderv2/dotfiles; using that"
      DOTFILES_URL="$HOME/.config/coderv2/dotfiles"
      break
    fi
    now=$(date +%s)
    elapsed=$((now - start))
    if [ "$elapsed" -ge "$WAIT_SECONDS" ]; then
      echo "Timeout waiting for local clone after $WAIT_SECONDS seconds; nothing to do"
      exit 0
    fi
    sleep 1
  done
else
  # No wait requested: prefer local clone if present, otherwise exit
  if [ -d "$HOME/.config/coderv2/dotfiles" ] && [ "$(ls -A "$HOME/.config/coderv2/dotfiles" 2>/dev/null || true)" != "" ]; then
    DOTFILES_URL="$HOME/.config/coderv2/dotfiles"
  else
    echo "No local coder clone present and WAIT_SECONDS=0; nothing to do"
    exit 0
  fi
fi

apply_symlink() {
  src="$1"
  dest="$2"
  if [ -e "$dest" ] && [ ! -L "$dest" ]; then
    echo "Skipping $dest: exists and is not a symlink"
    return
  fi
  if [ -L "$dest" ]; then
    if [ "$(readlink "$dest")" = "$src" ]; then
      echo "Symlink $dest already points to $src"
      return
    else
      echo "Replacing symlink $dest -> $(readlink "$dest") with -> $src"
      rm -f "$dest"
    fi
  fi
  ln -s "$src" "$dest"
  echo "Created symlink $dest -> $src"
}

apply_copy() {
  src="$1"
  dest="$2"
  if [ -e "$dest" ]; then
    echo "Skipping copy to $dest: destination exists"
    return
  fi
  cp -a "$src" "$dest"
  echo "Copied $src -> $dest"
}

# Normalize file:// prefix and expand ~ in local paths
if [[ "$DOTFILES_URL" =~ ^file:// ]]; then
  path=$(echo "$DOTFILES_URL" | sed -e 's#^file://##')
else
  path="$DOTFILES_URL"
fi

# Expand leading ~ to $HOME (safe replacement) without using bash's
# `$${var/pattern/replacement}` form which interferes with Terraform's
# templatefile interpolation. Use a simple test + substring instead.
if [[ "$path" = ~* ]]; then
  # remove leading ~ and prepend $HOME (avoid bash $${var:offset} which Terraform may
  # try to interpret during template rendering). Use command substitution instead.
  path="$HOME$(printf '%s' "$path" | cut -c2-)"
fi

# For simplicity assume coder clones repo into $HOME/.config/coderv2/dotfiles.
# If DOTFILES_URL is a remote URI, prefer the local clone at that location.
is_local=false
case "$path" in
  /*|$HOME/*|./*|../*) is_local=true ;;
esac

if [ "$is_local" = false ]; then
  # Remote URI: prefer local clone location (repo root or parent directory)
  candidate="$HOME/.config/coderv2/dotfiles"
  if [ -d "$candidate" ] && [ "$(ls -A "$candidate" 2>/dev/null || true)" != "" ]; then
    path="$candidate"
    echo "Using local coder clone at '$path' for remote URI '$DOTFILES_URL'"
  else
    echo "No local clone found for remote URI '$DOTFILES_URL'; nothing to do"
    exit 0
  fi
fi

# Determine a name for the repo/package and set src/dest
name=$(basename "$path")
src="$path"
dest="$HOME/.dotfiles/$name"

# Build a package_list value. If PACKAGES is provided use it,
# otherwise autodetect common package dirs (dotfiles/ or home/).
stow_target_dir=""
package_list=""
if [ -n "$PACKAGES" ]; then
  package_list="$PACKAGES"
  stow_target_dir="$path"
else
  # Common layout: repo root contains a `dotfiles/` or `home/` package.
  # If $path itself is the inner package (e.g. .../dotfiles), prefer using
  # the parent dir as the stow target and set the package to the basename.
  base_name=$(basename "$path")
  if [ "$base_name" = "dotfiles" ]; then
    package_list="dotfiles"
    stow_target_dir=$(dirname "$path")
  elif [ "$base_name" = "home" ]; then
    package_list="home"
    stow_target_dir=$(dirname "$path")
  else
    if [ -d "$path/dotfiles" ]; then
      package_list="dotfiles"
      stow_target_dir="$path"
    fi
    if [ -d "$path/home" ]; then
      if [ -n "$package_list" ]; then
        package_list="$package_list home"
      else
        package_list="home"
      fi
      stow_target_dir="$path"
    fi
  fi
fi

case "$MODE" in
  symlink)
    if [ -n "$package_list" ] && command -v stow >/dev/null 2>&1; then
      echo "Using GNU stow to link packages ($package_list) from $stow_target_dir"
      for pkg in $package_list; do
            if [[ "$pkg" == *:* ]]; then
              origin="$${pkg%%:*}"
              target_spec="$${pkg#*:}"
        else
          origin="$pkg"
          target_spec=""
        fi
        if [ -n "$target_spec" ]; then
          if [[ "$target_spec" = /* ]]; then
            target="$target_spec"
          else
            target="$HOME/$target_spec"
          fi
        else
          target="$HOME"
        fi
        echo "Stowing package '$origin' -> target '$target' (using --adopt to convert existing files)"
        (cd "$stow_target_dir" && stow -v --adopt -t "$target" "$origin") || true
        if [ -d "$stow_target_dir/.git" ]; then
          changed=$(cd "$stow_target_dir" && git status --porcelain --untracked-files=all 2>/dev/null || true)
          if [ -n "$changed" ]; then
            if [ "${PRESERVE_STASH}" = "true" ]; then
              stash_name="stow-adopt-$(date -u +%Y%m%dT%H%M%SZ)"
              echo "Detected git repo in $stow_target_dir — stashing changes to '$stash_name' to preserve local edits"
              (cd "$stow_target_dir" && git stash push --include-untracked -m "$stash_name") || true
            else
              echo "Detected changes in $stow_target_dir but PRESERVE_STASH is false; not stashing"
            fi
          else
            echo "No working-tree changes detected in $stow_target_dir"
          fi
        fi
      done
  elif [ -n "$package_list" ]; then
mkdir -p "$HOME/.dotfiles/$name"
      for origin in $package_list; do
        if [[ "$origin" == *:* ]]; then
          origin_dir="$${origin%%:*}"
        else
          origin_dir="$origin"
        fi
        src_pkg="$path/$origin_dir"
        dest_pkg="$HOME/.dotfiles/$name/$origin_dir"
        apply_symlink "$src_pkg" "$dest_pkg" || true
      done
    else
      apply_symlink "$src" "$dest" || true
    fi
    ;;
  copy)
    # For copy mode we still copy the whole repo into .dotfiles/<name>
    apply_copy "$src" "$dest" || true
    ;;
  none|"")
    echo "Dotfiles mode set to 'none' or empty; skipping $name"
    ;;
  *)
    echo "Unknown mode: $MODE; skipping $name"
    ;;
esac

exit 0
