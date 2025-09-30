#!/usr/bin/env bash
set -euo pipefail

# Rendered by Terraform. DOTFILES_URIS will be a space-separated list of URIs.
DOTFILES_URIS="${DOTFILES_URIS}"
MODE="${MODE}"
WAIT_SECONDS="${WAIT_SECONDS}"
# Optional: space-separated list of package specifiers for stow/manual handling.
# Each item may be a simple package name (e.g. "dotfiles") or an origin:target pair
# where `origin` is the directory inside the repo and `target` is an optional
# target path (absolute or relative to the user's home) e.g. "dotfiles" or
# "dotfiles:home" or "dotfiles:/etc/skel". If empty, the script will auto-detect
# conventional package dirs (dotfiles/ or home/).
PACKAGES="${PACKAGES}"

# If DOTFILES_URIS is empty, try a conventional dotfilesurl file which may
# contain a single URI (this exists in some images as ~/.config/coderv2/dotfilesurl).
if [ -z "$DOTFILES_URIS" ]; then
  if [ -f ~/.config/coderv2/dotfilesurl ]; then
    DOTFILES_URIS=$(cat ~/.config/coderv2/dotfilesurl | tr -d '\r\n')
    echo "Using DOTFILES_URIS from ~/.config/coderv2/dotfilesurl: $DOTFILES_URIS"
  elif [ -f ./dotfilesurl ]; then
    DOTFILES_URIS=$(cat ./dotfilesurl | tr -d '\r\n')
    echo "Using DOTFILES_URIS from ./dotfilesurl: $DOTFILES_URIS"
  fi
fi

# Ensure base .dotfiles dir exists so symlink/copy ops don't fail
mkdir -p "$HOME/.dotfiles"

# Wait for coder to populate ~/.config/coderv2/dotfiles or dotfilesurl if not already present.
# This prevents racing where the dotfiles are still being cloned/placed by coder.
if [ -n "$WAIT_SECONDS" ] && [ "$WAIT_SECONDS" -gt 0 ]; then
  echo "Waiting up to $WAIT_SECONDS seconds for coder dotfiles to appear..."
  start=$(date +%s)
  while true; do
    # Check for populated directory
    if [ -d ~/.config/coderv2/dotfiles ] && [ "$(ls -A ~/.config/coderv2/dotfiles 2>/dev/null || true)" != "" ]; then
      echo "Detected ~/.config/coderv2/dotfiles populated"
      break
    fi
    # Check for dotfilesurl file
    if [ -f ~/.config/coderv2/dotfilesurl ] && [ -s ~/.config/coderv2/dotfilesurl ]; then
      echo "Detected ~/.config/coderv2/dotfilesurl"
      break
    fi
    now=$(date +%s)
    elapsed=$((now - start))
    if [ "$elapsed" -ge "$WAIT_SECONDS" ]; then
      echo "Timeout waiting for coder dotfiles after $WAIT_SECONDS seconds; continuing"
      break
    fi
    sleep 1
  done
fi

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

  # For simplicity assume dotfiles are placed under $HOME/.dotfiles/<basename>
  name=$(basename "$path")

  # If the URI is a local path (starts with /, ~, ./, ../ or file://) treat as local.
  # Otherwise assume it's a remote URI (git@, https://, ssh://, etc.). For remote
  # URIs prefer using the local clone that coder places under
  # ~/.config/coderv2/dotfiles/<repo> if present. If no local clone is found,
  # skip to avoid creating a symlink that points to a remote URL string.
  is_local=false
  case "$path" in
    /*|~/*|./*|../*|file://*) is_local=true ;;
  esac

  if [ "$is_local" = false ]; then
    # Derive repo directory name by stripping a trailing .git if present
    repo_name="$name"
  repo_name_no_git="$${repo_name%.git}"
    repo_dir_candidate="$HOME/.config/coderv2/dotfiles/$repo_name_no_git"
    repo_dir_parent="$HOME/.config/coderv2/dotfiles"

    # Prefer a candidate directory matching the repo name, otherwise fall back to
    # the parent .config/coderv2/dotfiles directory which may itself be the repo
    # root (coder often clones the repo directly into ~/.config/coderv2/dotfiles).
    if [ -d "$repo_dir_candidate" ] && [ "$(ls -A "$repo_dir_candidate" 2>/dev/null || true)" != "" ]; then
      path="$repo_dir_candidate"
      name="$repo_name_no_git"
      echo "Detected local clone for remote URI '$uri' at '$path' — using that instead"
    elif [ -d "$repo_dir_parent" ] && [ "$(ls -A "$repo_dir_parent" 2>/dev/null || true)" != "" ]; then
      # If the parent dir contains the expected package (or is itself a repo root), use it.
      if [ -d "$repo_dir_parent/$repo_name_no_git" ] || [ -d "$repo_dir_parent/dotfiles" ] || [ -d "$repo_dir_parent/home" ] || [ -d "$repo_dir_parent/.git" ]; then
        path="$repo_dir_parent"
        name="$repo_name_no_git"
        echo "Detected local clone for remote URI '$uri' at '$path' — using that instead"
      else
        echo "Skipping remote URI '$uri': no suitable local clone found under '$repo_dir_candidate' or '$repo_dir_parent' — not creating symlink to remote URL"
        continue
      fi
    else
      echo "Skipping remote URI '$uri': no local clone found under '$repo_dir_parent' — not creating symlink to remote URL"
      continue
    fi
    src="$path"
    dest="$HOME/.dotfiles/$name"
  else
    src="$path"
  dest="$HOME/.dotfiles/$name"
  fi

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
done

exit 0
