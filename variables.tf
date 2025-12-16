variable "agent_id" {
  description = "The coder agent id to attach the script to"
  type        = string
}

variable "coder_parameter_order" {
  type        = number
  description = "The order determines the position of a template parameter in the UI/CLI presentation. The lowest order is shown first and parameters with equal order are sorted by name (ascending order)."
  default     = null
}

variable "default_dotfiles_uri" {
  type        = string
  description = "The default dotfiles URI if the workspace user does not provide one"
  default     = ""
}

variable "description" {
  type        = string
  description = "A custom description for the dotfiles parameter. This is shown in the UI - and allows you to customize the instructions you give to your users."
  default     = "Enter a URL for a [dotfiles repository](https://dotfiles.github.io) to personalize your workspace"
}

variable "dotfiles_uri" {
  description = "The URL to a dotfiles repository. (optional, when set, the user isn't prompted for their dotfiles)"
  type        = string
  default     = ""
}

variable "group" {
  type        = string
  description = "The name of a group that this app belongs to."
  default     = null
}

variable "mode" {
  description = "Optional override for dotfiles handling mode. If empty, the module's coder_parameter will control behavior."
  type        = string
  default     = null # When null, the module will create a workspace parameter so end-users can change mode at runtime.
}

variable "order" {
  type        = number
  description = "The order determines the position of app in the UI presentation. The lowest order is shown first and apps with equal order are sorted by name (ascending order)."
  default     = null
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

variable "user" {
  type        = string
  description = "The name of the user to apply the dotfiles to. (optional, applies to the current user by default)"
  default     = null
}
