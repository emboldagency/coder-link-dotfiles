terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
  }
}

data "coder_parameter" "dotfiles_mode" {
  count       = var.mode == null ? 1 : 0
  name        = "Dotfiles Mode"
  description = "How should embedded dotfiles be applied?"
  type        = "string"
  default     = "symlink"
  mutable     = true
  option {
    name  = "Symlink"
    value = "symlink"
  }
  option {
    name  = "Copy"
    value = "copy"
  }
  option {
    name  = "None"
    value = "none"
  }
}


resource "coder_script" "link_dotfiles" {
  agent_id           = var.agent_id
  script             = templatefile("${path.module}/run.sh", { DOTFILES_URIS = var.dotfiles_uri, MODE = local.resolved_mode, PACKAGES = local.resolved_packages, PRESERVE_STASH = var.stow_preserve_changes })
  display_name       = "Link Dotfiles"
  icon               = "/icon/link.svg"
  run_on_start       = true
  start_blocks_login = false
}

output "mode" {
  description = "Resolved mode for applying dotfiles"
  value       = local.resolved_mode
}

locals {
  # Prefer the first non-empty value among the explicit var, the workspace
  # parameter (if present), or empty string. Use trimspace checks because
  # coalesce() treats empty string as a valid value which is undesirable here.
  resolved_mode = (
    trimspace(coalesce(var.mode, "")) != "" ? trimspace(var.mode) : (
      trimspace(try(data.coder_parameter.dotfiles_mode[0].value, "")) != "" ? trimspace(try(data.coder_parameter.dotfiles_mode[0].value, "")) : ""
    )
  )
}

data "coder_parameter" "dotfiles_packages" {
  count       = var.packages == null ? 1 : 0
  name        = "Dotfiles Packages"
  description = "Space-separated list of package specifiers for stow/manual linking"
  type        = "string"
  default     = ""
  mutable     = true
}

locals {
  # coalesce() treats empty string as a value; we need to prefer non-empty
  # strings. Use trimspace() and conditional checks to return the first
  # non-empty value or empty string when none provided.
  resolved_packages = (
    trimspace(coalesce(var.packages, "")) != "" ? trimspace(var.packages) : (
      trimspace(try(data.coder_parameter.dotfiles_packages[0].value, "")) != "" ? trimspace(try(data.coder_parameter.dotfiles_packages[0].value, "")) : ""
    )
  )
}

output "packages" {
  description = "Resolved PACKAGES value used by the module"
  value       = local.resolved_packages
}

output "stow_preserve_changes" {
  description = "Whether the module will stash repo changes after stow adoption"
  value       = var.stow_preserve_changes
}

output "uri_accepted" {
  description = "Dotfiles URI passed to module"
  value       = var.dotfiles_uri
}
