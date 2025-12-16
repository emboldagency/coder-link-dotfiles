# Link Dotfiles module

A comprehensive Coder module that clones a dotfiles repository and applies them using GNU Stow or custom symlinking strategies.

**Note:** This module replaces the standard Coder dotfiles module. It handles the full lifecycle (Clone -> Clean -> Link) to prevent race conditions common when using separate clone and link steps.

## Inputs

- `agent_id` (string) - The ID of the Coder agent.
- `dotfiles_uri` (string) - The URL of the dotfiles repository.
- `user` (string, optional) - The user to apply dotfiles to. Defaults to the current user. If set to a different user, `sudo` will be used.
- `mode` (string, optional) - One of `symlink`, `copy`, or `none`.
  - If unset, the module will create a workspace parameter named `Dotfiles Mode` so end-users can choose behavior at runtime.
- `packages` (string, optional) - Space-separated list of package specifiers for `stow` or manual handling.
  - Each item may be `origin` (e.g. `dotfiles`) or `origin:target` (e.g. `home:dotfiles` or `dotfiles:/etc/skel`).
  - If omitted, the module will auto-detect `dotfiles/` and/or `home/` subdirs in the repo.
  - If omitted, the module also exposes a workspace parameter named `Dotfiles Packages`.
- `stow_preserve_changes` (bool, optional) - If `true` (default), changes created by `stow --adopt` are stashed to preserve local edits.

## Usage

Do **not** use the standard `coder/dotfiles` module. Use this module directly.

```terraform
module "link_dotfiles" {
  source       = "git::[https://github.com/emboldagency/coder-link-dotfiles.git?ref=v1.0.1](https://github.com/emboldagency/coder-link-dotfiles.git?ref=v1.0.1)"
  agent_id     = coder_agent.main.id
  dotfiles_uri = data.coder_parameter.dotfiles_url.value

  # Optional overrides
  # user                  = "root"
  # packages              = "dotfiles home:dotfiles"
  # stow_preserve_changes = true
}
```

## Behavior & Notes

- **Lifecycle**:
  1. **Clean**: Checks the local repo for "dirty" states (modified files). If found, it stashes them to ensure `git pull` does not fail.
  2. **Clone/Update**: Clones the repo if missing, or pulls/rebases if it exists.
  3. **Link**: Applies the files using the selected `mode`.
- **User Context**: If the `user` input is provided (and differs from the current user), the script utilizes `sudo` to execute the entire clone and link process as that target user.
- **Stow Strategy**:
  - When `MODE=symlink` and GNU `stow` is available, it uses `stow --adopt` to claim existing files.
  - It then immediately stashes the changes created by adoption (if `stow_preserve_changes` is true), effectively "peeling" the local file version off into a stash while leaving the symlink to the repo version in place.
- **Auto-Detection**: When `packages` is not provided, the module prefers `dotfiles/` or `home/` subdirectories inside the repo before falling back to the repo root.

## Publishing

Tag releases with SemVer (e.g. `v1.0.1`) and reference them with `?ref=` in the `git::` source string.
