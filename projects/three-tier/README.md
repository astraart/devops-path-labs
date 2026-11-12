# Проект 3. Инфраструктура из трёх машин

Проект после модулей Terraform и Ansible. Результат — ваш репозиторий `three-tier`: Terraform создаёт три машины (балансировщик, приложение, база), Ansible настраивает их, и `terraform apply` с `ansible-playbook` поднимают весь стенд с нуля.

Машины — контейнеры LXD на вашей учебной ВМ: бесплатно, без облака и без счёта. Приложение — `notes-api` из `apps/notes-api` с хранением в PostgreSQL.

Рубрика самооценки и типовые замечания ревьюера — в приложении DevOps Path, на экране проекта.

## Что должно работать

1. Terraform с провайдером `terraform-lxd/lxd` создаёт машины `tt-lb`, `tt-db` и `tt-app1`…`tt-appN` (`app_count`) из `ubuntu:24.04`, а cloud-init создаёт на них пользователя `ansible` с вашим ключом.
2. Terraform сам пишет инвентарь `ansible/inventory.ini` по шаблону `inventory.tftpl`. Версии провайдеров закреплены, `.terraform.lock.hcl` в git, состояние — нет.
3. Ansible: роль `common` (ufw: SSH открыт, остальное закрыто), `postgres` (база слушает внутренний адрес и пускает только машины приложения), `app` (сервис под systemd от отдельного пользователя), `lb` (nginx распределяет запросы по всем машинам приложения).
4. Порт базы открыт только машинам приложения, порт приложения — только балансировщику. Снаружи доступен только HTTP балансировщика.
5. Пароль базы — только в `group_vars/all/vault.yml`, зашифрованном `ansible-vault`.
6. Повторный `ansible-playbook` ничего не меняет (`changed=0`).
7. README: схема, как поднять и удалить стенд, где секреты, что делать при сбоях.

## Как начать

На учебной ВМ с Ubuntu 24.04 (4 ГБ памяти, 20 ГБ диска):

```bash
sudo snap install lxd && sudo lxd init --auto && sudo usermod -aG lxd "$USER"
```

Перезайдите в систему, чтобы группа `lxd` применилась. Terraform ставится по [инструкции HashiCorp](https://developer.hashicorp.com/terraform/install), Ansible — из пакетов Ubuntu:

```bash
sudo apt install -y ansible
```

Ключ для Ansible, если его ещё нет:

```bash
ssh-keygen -t ed25519 -f ~/.ssh/id_ed25519 -N ""
```

Заготовка:

```bash
cp -r ~/devops-path-labs/projects/three-tier/starter ~/three-tier
```

```bash
cd ~/three-tier && git init -b main && git add . && git commit -m "Заготовка проекта"
```

Бинарник приложения собирается в Docker (Go ставить не нужно):

```bash
./build-app.sh
```

Поднять стенд:

```bash
cd ~/three-tier/terraform && terraform init && terraform apply
```

```bash
cd ~/three-tier/ansible && ansible-playbook site.yml --ask-vault-pass
```

## Договорённости

`check.sh` находит стенд по ним: машины LXD `tt-lb`, `tt-db`, `tt-app1`…; выходное значение Terraform `lb_ip`; приложение на порту 8080, база на 5432, балансировщик на 80.

## Проверка

```bash
~/devops-path-labs/projects/three-tier/check.sh ЧИСЛО ~/three-tier
```

ЧИСЛО — четыре цифры с экрана проекта в приложении. Скрипт только читает: репозиторий, `lxc list`, `terraform output` и ответы машин стенда по их адресам в мосте LXD. Если вы не в группе `lxd`, запустите через `sudo`.

## Как удалить стенд

```bash
cd ~/three-tier/terraform && terraform destroy
```
