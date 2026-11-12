terraform {
  required_version = ">= 1.6"

  required_providers {
    # TODO: закрепите версии провайдеров (например, "~> 2.7"), чтобы сборка через год была той же.
    lxd = {
      source = "terraform-lxd/lxd"
    }
    local = {
      source = "hashicorp/local"
    }
  }
}

# Провайдер берёт адрес и сертификаты из настроек клиента lxc на этой машине.
provider "lxd" {}
