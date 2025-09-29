#!/usr/bin/env bash
set -euo pipefail

# Rendered by Terraform. DOTFILES_URIS will be a space-separated list of URIs.
DOTFILES_URIS="$${DOTFILES_URIS}"
MODE="$${MODE}"

if [ -z "$DOTFILES_URIS" ]; then
  echo "No dotfiles URIs provided; nothing to do"
  exit 0
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

for uri in $DOTFILES_URIS; do
  # Expect URIs as local paths or file:// paths. Normalize local paths.
  if [[ "$uri" =~ ^file:// ]]; then
    # Remove file:// prefix using sed. Avoid shell parameter expansion
    # in text which can collide with Terraform template interpolation.
    path=$(echo "$uri" | sed -e 's#^file://##')
  else
    path="$uri"
  fi

  # For simplicity assume dotfiles are placed under /home/embold/.dotfiles/<basename>
  name=$(basename "$path")
  src="$path"
  dest="/home/embold/.dotfiles/$name"

  case "$MODE" in
    symlink)
      apply_symlink "$src" "$dest" || true
      ;;
    copy)
      apply_copy "$src" "$dest" || true
      ;;
    none|"")
      echo "Dotfiles mode set to 'none' or empty; skipping $name"
      ;;
    *)
      echo "Unknown mode: $MODE; skipping $name"
      ;;
  esac
done

exit 0
