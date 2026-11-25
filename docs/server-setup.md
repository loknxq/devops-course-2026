# Настройка учебного сервера

## 10. Ansible

Проект расположен в каталоге `ansible/`. Управляющий узел запускает Ansible и
хранит SSH-ключ локально. Управляемый узел — Ubuntu Server 24.04, подключённый
к сети Host-only. Адрес в inventory должен совпадать с фактическим адресом VM.

- `inventory/bootstrap.ini` — первичное подключение от имени `student`.
- `inventory/prod.ini` — дальнейшее подключение от имени `devops` с ключом
  `~/.ssh/devops_vm` и проверкой ключа хоста.
- `base` устанавливает системные зависимости и Docker Engine.
- `ssh` устанавливает открытый ключ, настраивает sudo, SSH и UFW.
- `nginx` подключает reverse proxy на порту 80.
- `app` скачивает зафиксированный образ и запускает контейнер на loopback.

Реестр: `ghcr.io/loknxq/devops-ci-app`. Опубликованный тег образа из успешного запуска ПР № 10: `de32845cef47f837f6018b3a6b4411f096735ed4`. Перед запуском проверьте доступность тега в GHCR. Порт контейнера 5000 опубликован только на `127.0.0.1:5000`;
внешняя проверка проходит по `http://<адрес VM>/health` через Nginx.

Из каталога `ansible/`:

```bash
ansible-galaxy collection install -r requirements.yml
ansible-playbook -i inventory/bootstrap.ini site.yml --ask-pass --ask-become-pass
ansible-playbook site.yml
ansible-playbook verify.yml
```
