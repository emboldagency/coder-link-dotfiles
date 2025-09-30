# Link Dotfiles module

Coder module that applies dotfiles that were installed by the community `dotfiles` module.

## Inputs

- `agent_id` (string)
- `count` (number)
- `dotfiles_uris` (list(string)) - each entry is a `dotfiless_uri` output from the `dotfiles` module
- `mode` (string, optional) - one of `symlink`, `copy`, or `none`. If unset, the module will create a `coder_parameter` named `Dotfiles Mode` so end-users can choose the behavior at workspace runtime.
- `packages` (string, optional) - optional space-separated list of package specifiers for `stow` or manual handling. Each item may be:
  - `origin` (e.g. `dotfiles`) — a directory inside the dotfiles repo
  - `origin:target` (e.g. `home:dotfiles` or `dotfiles:/etc/skel`) where `target` is absolute or relative to `/home/embold`
  If `packages` is omitted the module will auto-detect `dotfiles/` and/or `home/` subdirs in the repo. When omitted the module also exposes a workspace parameter named `Dotfiles Packages` so admins can set packages at runtime.

## Usage

Call the module after your `dotfiles` module and pass the `dotfiles_uri` outputs.

```terraform
module "dotfiles" {
  source  = "registry.coder.com/coder/dotfiles/coder"
  count   = data.coder_workspace.me.start_count
  agent_id = coder_agent.example.id
}

module "link_dotfiles" {
  source  = "git::https://github.com/emboldagency/coder-link-dotfiles.git?ref=v1.0.4"
  count    = data.coder_workspace.me.start_count
  agent_id = coder_agent.example.id
  dotfiles_uri = module.dotfiles[0].dotfiles_uri
  # Optional: pass packages directly
  # packages = "dotfiles home:dotfiles"
  # Ensure dotfiles are created before we try to link/copy them
  depends_on = [module.dotfiles]
}
```


## Notes

- The module exposes a `coder_parameter` named `Dotfiles Mode` so end-users can choose the behavior at workspace runtime.
- For idempotence, symlink creation will not overwrite regular files; copy will skip existing destinations.
- The module does not itself depend on the `dotfiles` module; callers should ensure the module runs after dotfiles by using `depends_on` if required.
- Stow behavior:
  - When `MODE=symlink` and GNU `stow` is available in the image, the module will use `stow --adopt` to adopt existing files into the package and create symlinks.
  - After `stow --adopt`, the module will stash any uncommitted changes created by adoption into a named stash (e.g. `stow-adopt-20250929T153045Z`). This preserves local edits instead of discarding them. To inspect or restore changes run `git stash list` and `git stash apply` in the dotfiles repo.
  - If `stow` is missing the module falls back to creating per-package symlinks under `/home/embold/.dotfiles/<repo-name>/<package>` so layout is preserved.

## Publishing

- Tag releases with SemVer (e.g. `v1.0.0`) and reference them with `?ref=` in the `git::` source string.
