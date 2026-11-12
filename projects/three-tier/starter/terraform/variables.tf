variable "image" {
  description = "Образ машин: Ubuntu 24.04 с cloud-init из удалённого источника ubuntu:"
  type        = string
  default     = "ubuntu:24.04"
}

variable "app_count" {
  description = "Сколько машин с приложением стоит за балансировщиком"
  type        = number
  default     = 1

  validation {
    condition     = var.app_count >= 1 && var.app_count <= 3
    error_message = "app_count — от 1 до 3."
  }
}

variable "ssh_public_key_path" {
  description = "Открытый ключ, с которым Ansible заходит на машины"
  type        = string
  default     = "~/.ssh/id_ed25519.pub"
}
