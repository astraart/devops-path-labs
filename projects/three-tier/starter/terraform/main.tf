# TODO: опишите машины стенда и инвентарь для Ansible.
#
# 1. locals:
#    - cloud_init — #cloud-config, который создаёт пользователя ansible с вашим ключом
#      (var.ssh_public_key_path, функции file и pathexpand) и sudo без пароля;
#    - machines — имя → роль: lb, db и app1…appN по var.app_count (функции merge и range).
# 2. resource "lxd_instance" "node" с for_each по local.machines:
#    имя "tt-<имя>" (по нему машины находит check.sh), образ var.image, wait_for_network,
#    config: "cloud-init.user-data" и "boot.autostart"; limits: 1 CPU, память 512MiB, базе — 1GiB.
# 3. resource "local_file" "inventory": ../ansible/inventory.ini из шаблона inventory.tftpl
#    (templatefile с адресами lb, db и списком адресов app).
#
# Документация провайдера: https://github.com/terraform-lxd/terraform-provider-lxd/blob/main/docs/resources/instance.md
