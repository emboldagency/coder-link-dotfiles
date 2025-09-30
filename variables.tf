variable "agent_id" {
  description = "The coder agent id to attach the script to"
  type        = string
}

variable "dotfiles_uri" {
  description = "Dotfiles URI (from the dotfiles module) to apply"
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
