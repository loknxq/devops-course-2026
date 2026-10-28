#!/usr/bin/env bash
set -uo pipefail

PASS=0; FAIL=0

check() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        echo "  [OK]   $desc"; ((PASS++))
    else
        echo "  [FAIL] $desc (ожидалось: '$expected', получено: '$actual')"; ((FAIL++))
    fi
}

echo "Аудит конфигурации: $(hostname -f), $(date '+%Y-%m-%d %H:%M')"

echo "[1] Служба SSH"
check "Вход от имени root запрещён" "no" "$(sudo sshd -T | awk '/^permitrootlogin/{print $2}')"
check "Парольная аутентификация отключена" "no" "$(sudo sshd -T | awk '/^passwordauthentication/{print $2}')"

# TODO 1: проверка, что порт отличен от 22
CURRENT_PORT=$(sudo sshd -T | awk '/^port/{print $2}')
if [[ "$CURRENT_PORT" != "22" ]]; then
    echo "  [OK]   Порт SSH отличен от 22 (текущий: $CURRENT_PORT)"; ((PASS++))
else
    echo "  [FAIL] Порт SSH равен 22"; ((FAIL++))
fi

# TODO 2: проверка, что MaxAuthTries равен 3
check "MaxAuthTries равен 3" "3" "$(sudo sshd -T | awk '/^maxauthtries/{print $2}')"

echo "[2] Межсетевой экран"
check "Межсетевой экран активен" "active" "$(sudo ufw status | awk '/^Status:/{print $2}')"

# TODO 3: проверка политики по умолчанию для входящего трафика
check "Политика по умолчанию для входящих: deny" "deny" "$(sudo ufw status verbose | grep 'Default:' | awk '{print $2}')"

echo "[3] Учётные записи"
awk -F: '$3>=1000 && $3<65534 {printf "    %s (uid=%s)\n",$1,$3}' /etc/passwd

echo "[4] Веб-сервер"
# а) Служба nginx активна
check "Служба nginx активна" "active" "$(systemctl is-active nginx)"

# б) Конфигурация nginx синтаксически корректна
if sudo nginx -t > /dev/null 2>&1; then
    echo "  [OK]   Конфигурация nginx корректна"; ((PASS++))
else
    echo "  [FAIL] Ошибка в конфигурации nginx"; ((FAIL++))
fi

# в) Сертификат истекает не ранее чем через 30 дней
if sudo openssl x509 -checkend 2592000 -noout -in /etc/ssl/certs/devops.crt > /dev/null 2>&1; then
    echo "  [OK]   Сертификат действителен более 30 дней"; ((PASS++))
else
    echo "  [FAIL] Сертификат истекает менее чем через 30 дней"; ((FAIL++))
fi

# г) Нет файлов с правами o+w и права ключа 600
WRITABLE_FILES=$(sudo find /var/www/devops-site -perm -o+w 2>/dev/null)
KEY_PERMS=$(sudo stat -c '%a' /etc/ssl/private/devops.key 2>/dev/null)

if [[ -z "$WRITABLE_FILES" && "$KEY_PERMS" == "600" ]]; then
    echo "  [OK]   Права файлов ресурса и ключа безопасны"; ((PASS++))
else
    echo "  [FAIL] Небезопасные права (файлы o+w или ключ не 600)"; ((FAIL++))
fi

echo "Пройдено: $PASS, не пройдено: $FAIL"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1