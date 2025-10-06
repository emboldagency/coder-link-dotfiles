variable "agent_id" {
  description = "The coder agent id to attach the script to"
  type        = string
}

variable "dotfiles_uri" {
  description = <<-EOT
Dotfiles URI to apply. This module expects the caller to pass the
`dotfiles_uri` output from the Coder dotfiles module (for example:
`module.dotfiles.dotfiles_uri`). If you don't have a value to pass,
leave the default empty string and the script will no-op at runtime.
EOT
  type        = string
  default     = ""
}

variable "mode" {
  description = "Optional override for dotfiles handling mode. If empty, the module's coder_parameter will control behavior."
  type        = string
  default     = null # When null, the module will create a workspace parameter so end-users can change mode at runtime.
}

variable "packages" {
  description = "Optional space-separated list of package specifiers for stow/manual linking. If null, the module will attempt to auto-detect 'dotfiles' or 'shell' subdirs or fall back to empty."
  type        = string
  default     = null
}

variable "stow_preserve_changes" {
  description = "When true, stash working-tree changes after running 'stow --adopt' to preserve local edits. Set to false to skip creating a stash." 
  type        = bool
  default     = true
}

variable "wait_seconds" {
  description = "How many seconds to wait for coder to populate ~/.config/coderv2/dotfiles or dotfilesurl before running link logic. Set to 0 to skip waiting." 
  type        = number
  default     = 30
}
