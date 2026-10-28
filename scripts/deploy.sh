#!/usr/bin/env bash
# Доставка статического ресурса на devops-vm
# Использование: scripts/deploy.sh [--dry-run]

set -euo pipefail

REMOTE="devops"
REMOTE_DIR="/var/www/devops-site"
SITE_URL="https://devops.local"
CA_CERT="${HOME}/devops.crt"
LOCAL_DIR="$(git rev-parse --show-toplevel)/site/"

# 1. Разбор аргумента --dry-run
DRY_RUN=""
if [[ "${1:-}" == "--dry-run" ]]; then
    DRY_RUN="--dry-run"
elif [[ -n "${1:-}" ]]; then
    echo "Неизвестный аргумент: $1" >&2
    exit 1
fi

# 2. Проверки по требованиям 4 и 5
# Проверка наличия главной страницы (требование 4)
if [[ ! -f "${LOCAL_DIR}/index.html" ]]; then
    echo "Ошибка: файл site/index.html отсутствует. Доставка отменена." >&2
    exit 1
fi

# Проверка на незафиксированные изменения (требование 5)
# --porcelain выводит пустую строку, если изменений нет (включая добавленные в индекс)
if [[ -n "$(git status --porcelain)" ]]; then
    echo "Ошибка: в репозитории есть незафиксированные изменения. Сначала сделайте коммит." >&2
    exit 1
fi

# 3. Синхронизация каталога
# Используем -e для запрета интерактивного ввода пароля (требование 9)
RSYNC_SSH="ssh -o BatchMode=yes -o ConnectTimeout=5"
RSYNC_OPTS=(-avz --delete --chmod=D755,F644 -e "${RSYNC_SSH}")

if [[ -n "${DRY_RUN}" ]]; then
    echo "=== План операций (--dry-run) ==="
    rsync "${RSYNC_OPTS[@]}" --dry-run "${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}/"
    # 4. При --dry-run — завершение с кодом 0
    exit 0
fi

echo "=== Синхронизация файлов ==="
rsync "${RSYNC_OPTS[@]}" "${LOCAL_DIR}" "${REMOTE}:${REMOTE_DIR}/"

# 5. Проверка доступности ресурса
echo "=== Проверка доступности ${SITE_URL} ==="
# curl -f возвращает ошибку при HTTP-кодах >= 400
# Проверка сертификата выполняется через --cacert
if curl -f --cacert "${CA_CERT}" -s -o /dev/null "${SITE_URL}"; then
    COMMIT_HASH=$(git rev-parse --short HEAD)
    echo "Успех: ресурс доступен. Доставлен коммит: ${COMMIT_HASH}"
    exit 0
else
    echo "Ошибка: ресурс ${SITE_URL} недоступен или сертификат не прошел проверку." >&2
    exit 1
fi
