variable "hosts" {
  type        = any
  description = "Hosts to configure: a map of names to addresses, or to host objects with an address and optional host_key, user, port, private_key_file or jump_hosts."
}

variable "ssh_user" {
  type        = string
  default     = "root"
  description = "User to log in as."
}

variable "ssh_port" {
  type        = number
  default     = 22
  description = "SSH port."
}

variable "ssh_private_key_file" {
  type        = string
  default     = null
  description = "Path to a private key. When null, Conn3x uses the SSH agent."
}

variable "ssh_known_hosts_file" {
  type        = string
  default     = null
  description = "known_hosts file to check host keys against. When null, ~/.ssh/known_hosts."
}

variable "ssh_become" {
  type        = bool
  default     = false
  description = "Run commands as root through sudo."
}

variable "sdk_version" {
  type        = string
  default     = "10.0.403"
  description = "The .NET SDK release to install, such as \"10.0.403\". Change checksums with it."

  validation {
    condition     = can(regex("^[0-9]+\\.[0-9]+\\.[0-9]+$", var.sdk_version))
    error_message = "sdk_version must look like \"10.0.403\"."
  }
}

variable "checksums" {
  type        = map(string)
  description = "SHA-256 of the linux-x64 and linux-arm64 SDK tarballs. Microsoft publishes SHA-512, so check that first; the README shows how. Change these with sdk_version."
  default = {
    x64   = "cd7224fe8e8ba57c15f1601439ff8785a1a72b54ae5c89dd5302a32dcfbddf18"
    arm64 = "21fe1a0963984206bfaeb19968da07e7a61d30c9bc4621b7372a762a30c88679"
  }

  validation {
    condition     = alltrue([for c in values(var.checksums) : can(regex("^[0-9a-f]{64}$", c))])
    error_message = "Each of checksums must be a SHA-256 in lowercase hex."
  }
}

variable "telemetry" {
  type        = bool
  default     = false
  description = "Let the .NET CLI send Microsoft its usage telemetry. Off by default: the dotnet command sets DOTNET_CLI_TELEMETRY_OPTOUT=1."
}
