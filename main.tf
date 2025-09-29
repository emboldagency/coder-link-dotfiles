terraform {
  required_providers {
    coder = {
      source = "coder/coder"
    }
  }
}

data "coder_parameter" "dotfiles_mode" {
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

# Create a workspace parameter only if the caller did not pass an explicit mode.
data "coder_parameter" "dotfiles_mode_dynamic" {
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
  script             = templatefile("${path.module}/run.sh", { DOTFILES_URIS = var.dotfiles_uri, MODE = local.resolved_mode })
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
  resolved_mode = coalesce(
    var.mode,
    try(data.coder_parameter.dotfiles_mode_dynamic[0].value, data.coder_parameter.dotfiles_mode.value),
    ""
  )
}

output "uri_accepted" {
  description = "Dotfiles URI passed to module"
  value       = var.dotfiles_uri
}
