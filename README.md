# Link Dotfiles module

Coder module that applies dotfiles that were installed by the community `dotfiles` module.

## Inputs

- `agent_id` (string)
- `count` (number)
- `dotfiles_uris` (list(string)) - each entry is a `dotfiless_uri` output from the `dotfiles` module
- `mode` (string, optional) - one of `symlink`, `copy`, or `none`. If unset, the module will create a `coder_parameter` named `Dotfiles Mode` so end-users can choose the behavior at workspace runtime.

## Usage

Call the module after your `dotfiles` module and pass the `dotfiles_uri` outputs.

```terraform
module "dotfiles" {
  source  = "registry.coder.com/coder/dotfiles/coder"
  count   = data.coder_workspace.me.start_count
  agent_id = coder_agent.example.id
}

module "link_dotfiles" {
  source  = "git::https://github.com/emboldagency/coder-link-dotfiles.git?ref=v1.0.3"
  count    = data.coder_workspace.me.start_count
  agent_id = coder_agent.example.id
  dotfiles_uri = module.dotfiles[0].dotfiles_uri
  # Ensure dotfiles are created before we try to link/copy them
  depends_on = [module.dotfiles]
}
```


## Notes

- The module exposes a `coder_parameter` named `Dotfiles Mode` so end-users can choose the behavior at workspace runtime.
- For idempotence, symlink creation will not overwrite regular files; copy will skip existing destinations.
- The module does not itself depend on the `dotfiles` module; callers should ensure the module runs after dotfiles by using `depends_on` if required.

## Publishing

- Tag releases with SemVer (e.g. `v1.0.0`) and reference them with `?ref=` in the `git::` source string.
