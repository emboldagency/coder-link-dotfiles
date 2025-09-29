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
