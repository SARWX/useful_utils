#!/bin/bash

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция для вывода сообщений
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Функция для запроса данных пользователя
get_user_data() {
    echo "========================================="
    echo "Настройка Git и репозиториев"
    echo "========================================="
    
    read -p "Введите логин для доступа к репозиториям (+ для Git user.name и почты): " GIT_NAME
    read -s -p "Введите пароль для доступа к репозиториям: " REPO_PASSWORD
    echo ""
    
    GIT_EMAIL="${GIT_NAME}@astralinux.ru"
    # Проверка, что поля не пустые
    if [ -z "$GIT_NAME" ]; then
        echo "Ошибка: имя обязательно"
        exit 1
    fi
    
    export GIT_NAME GIT_EMAIL REPO_PASSWORD
}

# Функция настройки Git
configure_git() {
    local target_user="$1"
    
    log_info "Настройка Git для пользователя $target_user..."
    
    # Определяем домашнюю директорию пользователя
    local user_home=$(getent passwd "$target_user" | cut -d: -f6)
    
    # Настраиваем глобальный конфиг Git
    sudo -u "$target_user" git config --global user.name "$GIT_NAME"
    sudo -u "$target_user" git config --global user.email "$GIT_EMAIL"
    
    # Дополнительные полезные настройки
    sudo -u "$target_user" git config --global core.editor "vim"
    sudo -u "$target_user" git config --global pull.rebase false
    sudo -u "$target_user" git config --global init.defaultBranch "main"
    
    # Настройка credential helper для сохранения пароля (опционально)
    sudo -u "$target_user" git config --global credential.helper "cache --timeout=3600"
    
    log_info "Git настроен: user.name=$GIT_NAME, user.email=$GIT_EMAIL"
}

# Функция клонирования с авторизацией
clone_repo() {
    local repo_name="$1"
    local repo_url="$2"
    local target_user="$3"
    local target_dir="${PROJECTS_BASE}/${repo_name}_build"
    
    log_info "Клонирование репозитория ${repo_name}..."
    
    # Создаем директорию, если она не существует
    mkdir -p "$target_dir"

    chown -R "${SUDO_USER:-$USER}":"${SUDO_USER:-$USER}" "$PROJECTS_BASE"
    
    # Формируем URL с авторизацией для HTTPS, если есть логин и пароль
    local clone_url="$repo_url"
    if [ -n "$GIT_NAME" ] && [ -n "$REPO_PASSWORD" ]; then
        clone_url=$(echo "$repo_url" | sed "s|https://|https://${GIT_NAME}:${REPO_PASSWORD}@|")
    fi
    
    # Проверяем, не существует ли уже директория с репозиторием
    if [ -d "$target_dir/.git" ]; then
        log_warn "Директория ${target_dir} уже содержит Git репозиторий. Обновляем..."
        if [ -n "$target_user" ]; then
            sudo -u "$target_user" git -C "$target_dir" pull
        else
            cd "$target_dir" || { log_error "Не удалось перейти в ${target_dir}"; return 1; }
            git pull
        fi
    else
        log_info "Клонирование в ${target_dir}..."
        cd "$target_dir" || { log_error "Не удалось перейти в ${target_dir}"; return 1; }
        if [ -n "$target_user" ]; then
            sudo -u "$target_user" git clone "$clone_url"
        else
            git clone "$clone_url"
        fi
    fi
    
    if [ $? -eq 0 ]; then
        log_info "Репозиторий ${repo_name} успешно клонирован в ${target_dir}"
        return 0
    else
        log_error "Ошибка при клонировании ${repo_name}"
        return 1
    fi
}

# Проверка прав суперпользователя
if [ "$EUID" -ne 0 ]; then 
    log_error "Пожалуйста, запустите скрипт с правами root (sudo)"
    exit 1
fi

log_info "Начинаем настройку виртуальной машины для разработки..."

# 1. Настройка sources.list
log_info "Настройка /etc/apt/sources.list..."

# Создаем резервную копию
cp /etc/apt/sources.list /etc/apt/sources.list.backup
log_info "Создана резервная копия: /etc/apt/sources.list.backup"

# Раскомментируем все строки и комментируем строки с cdrom
sed -i 's/^#\s*\(deb\)/\1/' /etc/apt/sources.list
sed -i 's/^deb cdrom:/#deb cdrom:/' /etc/apt/sources.list

log_info "sources.list настроен"

# Обновляем список пакетов
log_info "Выполняем apt update..."
apt update

if [ $? -ne 0 ]; then
    log_error "Ошибка при выполнении apt update"
    exit 1
fi

# 2. Установка пакетов
# Список пакетов для установки
PACKAGES=(
        # Общие пакеты
        "git"
        "build-essential"
        "vim"
        "python3"
        "python3-pip"
        "debhelper" 
        # LAM
        "linux-headers-6.1"
        "linux-headers-6.12"
        # safepolicy
        shc
)

log_info "Установка пакетов..."
for package in "${PACKAGES[@]}"; do
    log_info "Устанавливаем ${package}..."
    apt install -y "$package"
    
    if [ $? -ne 0 ]; then
        log_error "Ошибка при установке ${package}"
        # Продолжаем установку остальных пакетов
    fi
done

log_info "Установка пакетов завершена"

# 3. Клонирование репозиториев
get_user_data
configure_git "${SUDO_USER:-$USER}"

log_info "Клонирование репозиториев..."

# Создаем основную директорию для проектов, если её нет
PROJECTS_BASE="/home/${SUDO_USER:-$USER}"

# Экспортируем функцию для использования в дочерних процессах
export -f clone_repo
export -f log_info log_warn log_error

# Определяем репозитории
# Формат: "имя_проекта|url_репозитория"
REPOSITORIES=(
    "lam|https://git.devos.astralinux.ru/AstraOS/parsec/lam"
    "parsec|https://git.devos.astralinux.ru/AstraOS/parsec/parsec"
    "systemd|https://git.devos.astralinux.ru/AstraOS/parsec/systemd"
    "safepolicy|https://git.devos.astralinux.ru/AstraOS/parsec/astra-safepolicy"
)

# Клонируем каждый репозиторий
for repo in "${REPOSITORIES[@]}"; do
    IFS='|' read -r repo_name repo_url <<< "$repo"
    
    # Временно меняем директорию для функции clone_repo
    cd / || exit
    
    # Вызываем функцию клонирования
    clone_repo "$repo_name" "$repo_url" "${SUDO_USER:-$USER}"
    
    if [ $? -ne 0 ]; then
        log_error "Ошибка при клонировании ${repo_name}"
        # Продолжаем с остальными репозиториями
    fi
done

chown -R "${SUDO_USER:-$USER}":"${SUDO_USER:-$USER}" "$PROJECTS_BASE"

log_info "Настройка виртуальной машины завершена!"
log_info "Установленные пакеты: ${PACKAGES[*]}"
log_info "Репозитории склонированы в ${PROJECTS_BASE}"

exit 0
