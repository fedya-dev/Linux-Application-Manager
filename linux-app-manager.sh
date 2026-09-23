#!/usr/bin/env bash

set -o pipefail

# ============================================================
# Linux Application Manager
# За Debian, Ubuntu и Linux Mint
# ============================================================

APP_NAME="linux-app-manager"

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/${APP_NAME}"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/${APP_NAME}"
CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/${APP_NAME}"

LOG_DIR="${STATE_DIR}/logs"
LOG_FILE="${LOG_DIR}/install.log"
TEMP_DIR="${CACHE_DIR}/downloads"
APP_DIR="${HOME}/Applications"

if ! mkdir -p \
    "$LOG_DIR" \
    "$TEMP_DIR" \
    "$APP_DIR"; then

    echo "Грешка: Не могат да бъдат създадени нужните директории." >&2
    exit 1
fi

# ------------------------------------------------------------
# Цветове
# ------------------------------------------------------------

if [[ -t 1 ]]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    BLUE='\033[0;34m'
    CYAN='\033[0;36m'
    WHITE='\033[1;37m'
    GRAY='\033[0;90m'
    BOLD='\033[1m'
    RESET='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    BLUE=''
    CYAN=''
    WHITE=''
    GRAY=''
    BOLD=''
    RESET=''
fi

# ------------------------------------------------------------
# Помощни функции
# ------------------------------------------------------------

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" >> "$LOG_FILE"
}

info() {
    echo -e "${CYAN}➜${RESET} $*"
    log "$*"
}

success() {
    echo -e "${GREEN}✔${RESET} $*"
    log "$*"
}

warning() {
    echo -e "${YELLOW}⚠${RESET} $*"
    log "WARNING: $*"
}

error() {
    echo -e "${RED}✖${RESET} $*" >&2
    log "ERROR: $*"
}

separator() {
    echo -e "${GRAY}────────────────────────────────────────────────────────${RESET}"
}

pause_screen() {
    echo
    read -rp "Натиснете Enter за продължаване..." _
}

command_exists() {
    command -v "$1" >/dev/null 2>&1
}

is_installed() {
    dpkg-query -W -f='${Status}' "$1" 2>/dev/null |
        grep -q "install ok installed"
}

run_command() {
    log "Команда: $*"

    if "$@"; then
        return 0
    else
        error "Командата завърши с грешка:"
        error "$*"
        return 1
    fi
}

run_sudo() {
    log "sudo команда: $*"

    if sudo "$@"; then
        return 0
    else
        error "sudo командата завърши с грешка:"
        error "$*"
        return 1
    fi
}

confirm() {
    local message="$1"
    local answer

    read -rp "$message [д/Н]: " answer

    [[ "$answer" =~ ^[ДдYy]$ ]]
}

check_environment() {
    if [[ "${EUID}" -eq 0 ]]; then
        error "Не стартирайте скрипта директно като root."
        echo
        echo "Правилно стартиране:"
        echo
        echo "  $SCRIPT_DIR/linux-app-manager.sh"
        exit 1
    fi

    if [[ ! -f /etc/os-release ]]; then
        error "Не може да бъде установена операционната система."
        exit 1
    fi

    # shellcheck disable=SC1091
    source /etc/os-release

    if [[ "${ID_LIKE:-}" != *debian* &&
          "${ID:-}" != "debian" &&
          "${ID:-}" != "ubuntu" &&
          "${ID:-}" != "linuxmint" ]]; then

        warning "Скриптът е предназначен за Debian, Ubuntu и Linux Mint."
        echo "Установена система: ${PRETTY_NAME:-неизвестна}"
        echo

        if ! confirm "Желаете ли да продължите"; then
            exit 0
        fi
    fi

    if ! command_exists sudo; then
        error "Командата sudo не е налична."
        exit 1
    fi

    if ! command_exists apt-get; then
        error "Командата apt-get не е налична."
        exit 1
    fi
}

check_internet() {
    if ! curl -fsS --connect-timeout 5 https://www.google.com >/dev/null 2>&1; then
        warning "Няма достъп до интернет или връзката е ограничена."

        if ! confirm "Желаете ли да продължите"; then
            return 1
        fi
    fi
}

apt_update() {
    info "Обновяване на списъка с пакети..."
    run_sudo apt-get update
}

install_packages() {
    local packages=("$@")

    info "Инсталиране на следните пакети:"
    echo
    echo "  ${packages[*]}"
    echo

    run_sudo apt-get install -y "${packages[@]}"
}

remove_packages() {
    local packages=("$@")

    info "Премахване на следните пакети:"
    echo
    echo "  ${packages[*]}"
    echo

    run_sudo apt-get remove --purge -y "${packages[@]}"
    run_sudo apt-get autoremove -y
}

download_file() {
    local url="$1"
    local output="$2"

    info "Изтегляне:"
    echo "  $url"

    run_command curl \
        --fail \
        --location \
        --retry 3 \
        --connect-timeout 20 \
        --output "$output" \
        "$url"
}

# ------------------------------------------------------------
# Основни инструменти
# ------------------------------------------------------------

install_basic_tools() {
    local packages=(
        vim
        git
        neovim
        kate
        gedit

        net-tools
        curl
        wget
        ca-certificates
        gpg
        apt-transport-https
        software-properties-common

        rsync
        unzip
        zip
        p7zip-full
        tar
        mc

        tmux
        htop
        btop
        ncdu
        tree
        jq
        ripgrep
        fd-find

        pwgen
        keepassxc
        gnome-characters

        nmap
        preload
        ansible
        whois
        dnsutils
        traceroute

        filezilla
        vlc
        ffmpeg
        gimp
        imagemagick

        synaptic
        gparted
        timeshift

        telegram-desktop
    )

    info "Инсталиране на основни и допълнителни инструменти..."
    install_packages "${packages[@]}"
}

# ------------------------------------------------------------
# Инструменти за уеб разработка
# ------------------------------------------------------------

install_web_tools() {
    local packages=(
        git
        curl
        wget
        jq
        tree
        rsync
        unzip
        zip
        apache2-utils
        shellcheck
        nodejs
        npm
    )

    info "Инсталиране на инструменти за уеб разработка..."
    install_packages "${packages[@]}"
}

# ------------------------------------------------------------
# Инструменти за архивиране
# ------------------------------------------------------------

install_backup_tools() {
    local packages=(
        rsync
        timeshift
        deja-dup
        borgbackup
        restic
        rclone
        unzip
        zip
        p7zip-full
        tar
        mc
        ncdu
    )

    info "Инсталиране на инструменти за архивиране..."
    install_packages "${packages[@]}"
}

# ------------------------------------------------------------
# Мултимедийни програми
# ------------------------------------------------------------

install_multimedia_tools() {
    local packages=(
        vlc
        ffmpeg
        gimp
        imagemagick
        handbrake
        audacity
    )

    info "Инсталиране на мултимедийни програми..."
    install_packages "${packages[@]}"
}

# ------------------------------------------------------------
# Системна администрация
# ------------------------------------------------------------

install_admin_tools() {
    local packages=(
        htop
        btop
        ncdu
        iotop
        lsof
        strace
        net-tools
        nmap
        whois
        dnsutils
        traceroute
        tmux
        screen
    )

    info "Инсталиране на инструменти за системна администрация..."
    install_packages "${packages[@]}"
}

# ------------------------------------------------------------
# AppImageLauncher
# ------------------------------------------------------------

install_appimagelauncher() {
    if is_installed appimagelauncher; then
        warning "AppImageLauncher вече е инсталиран."
        return 0
    fi

    if ! command_exists add-apt-repository; then
        install_packages software-properties-common
    fi

    info "Добавяне на PPA за AppImageLauncher..."

    run_sudo add-apt-repository \
        -y ppa:appimagelauncher-team/stable || return 1

    apt_update || return 1
    install_packages appimagelauncher
}

# ------------------------------------------------------------
# Brave
# ------------------------------------------------------------

install_brave() {
    if is_installed brave-browser; then
        warning "Brave вече е инсталиран."
        return 0
    fi

    info "Добавяне на официалното хранилище на Brave..."

    run_sudo install -m 0755 -d /usr/share/keyrings

    run_sudo curl -fsSLo \
        /usr/share/keyrings/brave-browser-archive-keyring.gpg \
        https://brave-browser-apt-release.s3.brave.com/brave-browser-archive-keyring.gpg \
        || return 1

    run_sudo curl -fsSLo \
        /etc/apt/sources.list.d/brave-browser-release.sources \
        https://brave-browser-apt-release.s3.brave.com/brave-browser.sources \
        || return 1

    apt_update || return 1
    install_packages brave-browser
}

# ------------------------------------------------------------
# Google Chrome
# ------------------------------------------------------------

install_chrome() {
    if is_installed google-chrome-stable; then
        warning "Google Chrome вече е инсталиран."
        return 0
    fi

    local deb_file="${TEMP_DIR}/google-chrome-stable_current_amd64.deb"
    local url="https://dl.google.com/linux/direct/google-chrome-stable_current_amd64.deb"

    download_file "$url" "$deb_file" || return 1

    info "Инсталиране на Google Chrome..."
    run_sudo apt-get install -y "$deb_file"
}

# ------------------------------------------------------------
# AppImage приложения
# ------------------------------------------------------------

install_appimage() {
    local name="$1"
    local url="$2"
    local filename="$3"

    local download_path="${TEMP_DIR}/${filename}"
    local app_path="${APP_DIR}/${filename}"

    if [[ -f "$app_path" ]]; then
        warning "$name вече съществува в:"
        echo "  $app_path"
        return 0
    fi

    download_file "$url" "$download_path" || return 1

    info "Копиране на $name в:"
    echo "  $APP_DIR"

    cp "$download_path" "$app_path" || return 1
    chmod +x "$app_path" || return 1

    if command_exists ail-cli; then
        info "Интегриране на AppImage файла..."
        ail-cli integrate "$app_path" ||
            warning "Интеграцията на $name не беше завършена."
    fi

    success "$name беше инсталиран."
}

install_nextcloud() {
    install_appimage \
        "Nextcloud Desktop" \
        "https://github.com/nextcloud-releases/desktop/releases/latest/download/Nextcloud-x86_64.AppImage" \
        "Nextcloud-x86_64.AppImage"
}

install_viber() {
    install_appimage \
        "Viber" \
        "https://download.cdn.viber.com/desktop/Linux/viber.AppImage" \
        "viber.AppImage"
}

# ------------------------------------------------------------
# AnyDesk
# ------------------------------------------------------------

install_anydesk() {
    if is_installed anydesk; then
        warning "AnyDesk вече е инсталиран."
        return 0
    fi

    info "Добавяне на официалното хранилище на AnyDesk..."

    run_sudo install -m 0755 -d /etc/apt/keyrings

    run_sudo curl -fsSL \
        https://keys.anydesk.com/repos/DEB-GPG-KEY \
        -o /etc/apt/keyrings/keys.anydesk.com.asc \
        || return 1

    run_sudo chmod a+r \
        /etc/apt/keyrings/keys.anydesk.com.asc

    local repository
    repository="deb [signed-by=/etc/apt/keyrings/keys.anydesk.com.asc] https://deb.anydesk.com all main"

    echo "$repository" |
        sudo tee /etc/apt/sources.list.d/anydesk-stable.list >/dev/null ||
        return 1

    apt_update || return 1
    install_packages anydesk
}

# ------------------------------------------------------------
# Премахване на програми
# ------------------------------------------------------------

remove_basic_tools() {
    local packages=(
        vim
        git
        neovim
        kate
        gedit

        net-tools
        curl
        wget
        apt-transport-https
        software-properties-common

        rsync
        unzip
        zip
        p7zip-full
        tar
        mc

        tmux
        htop
        btop
        ncdu
        tree
        jq
        ripgrep
        fd-find

        pwgen
        keepassxc
        gnome-characters

        nmap
        preload
        ansible
        whois
        dnsutils
        traceroute

        filezilla
        vlc
        ffmpeg
        gimp
        imagemagick

        synaptic
        gparted
        timeshift

        telegram-desktop
    )

    remove_packages "${packages[@]}"
}

remove_web_tools() {
    local packages=(
        git
        curl
        wget
        jq
        tree
        rsync
        unzip
        zip
        apache2-utils
        shellcheck
        nodejs
        npm
    )

    remove_packages "${packages[@]}"
}

remove_backup_tools() {
    local packages=(
        rsync
        timeshift
        deja-dup
        borgbackup
        restic
        rclone
        unzip
        zip
        p7zip-full
        tar
        mc
        ncdu
    )

    remove_packages "${packages[@]}"
}

remove_multimedia_tools() {
    local packages=(
        vlc
        ffmpeg
        gimp
        imagemagick
        handbrake
        audacity
    )

    remove_packages "${packages[@]}"
}

remove_admin_tools() {
    local packages=(
        htop
        btop
        ncdu
        iotop
        lsof
        strace
        net-tools
        nmap
        whois
        dnsutils
        traceroute
        tmux
        screen
    )

    remove_packages "${packages[@]}"
}

remove_appimage() {
    local name="$1"
    local filename="$2"
    local app_path="${APP_DIR}/${filename}"

    if [[ ! -f "$app_path" ]]; then
        warning "$name не е намерен в:"
        echo "  $app_path"
        return 0
    fi

    if confirm "Да бъде ли изтрит $name"; then
        rm -f "$app_path"
        success "$name беше изтрит."
    else
        warning "Пропуснато: $name."
    fi
}

remove_brave_repository() {
    run_sudo rm -f \
        /etc/apt/sources.list.d/brave-browser-release.sources \
        /etc/apt/sources.list.d/brave-browser-release.list \
        /usr/share/keyrings/brave-browser-archive-keyring.gpg
}

remove_anydesk_repository() {
    run_sudo rm -f \
        /etc/apt/sources.list.d/anydesk-stable.list \
        /etc/apt/sources.list.d/anydesk.sources \
        /etc/apt/keyrings/keys.anydesk.com.asc
}

# ------------------------------------------------------------
# Менюта
# ------------------------------------------------------------

show_header() {
    clear

    echo -e "${BLUE}${BOLD}"
    echo "╔══════════════════════════════════════════════════════════╗"
    echo "║              LINUX APPLICATION MANAGER                 ║"
    echo "╚══════════════════════════════════════════════════════════╝"
    echo -e "${RESET}"

    echo -e "${GRAY}Лог файл:${RESET} $LOG_FILE"
    echo
}

show_main_menu() {
    show_header

    echo -e "${WHITE}${BOLD}Главно меню${RESET}"
    separator
    echo -e "${GREEN}1)${RESET} Инсталиране на програми"
    echo -e "${RED}2)${RESET} Деинсталиране на програми"
    echo -e "${CYAN}3)${RESET} Обновяване на системата"
    echo -e "${YELLOW}4)${RESET} Почистване на временни файлове"
    echo -e "${BLUE}5)${RESET} Информация за системата"
    echo -e "${GRAY}0)${RESET} Изход"
    separator
}

show_install_menu() {
    show_header

    echo -e "${GREEN}${BOLD}Инсталиране на програми${RESET}"
    separator
    echo "1) Основни инструменти и програми"
    echo "2) Инструменти за уеб разработка"
    echo "3) Инструменти за архивиране"
    echo "4) Мултимедийни програми"
    echo "5) Системна администрация"
    echo "6) AppImageLauncher"
    echo "7) Brave браузър"
    echo "8) Google Chrome"
    echo "9) Nextcloud Desktop"
    echo "10) Viber"
    echo "11) AnyDesk"
    echo "12) Инсталиране на всички"
    echo "0) Връщане"
    separator
}

show_remove_menu() {
    show_header

    echo -e "${RED}${BOLD}Деинсталиране на програми${RESET}"
    separator
    echo "1) Основни инструменти и програми"
    echo "2) Инструменти за уеб разработка"
    echo "3) Инструменти за архивиране"
    echo "4) Мултимедийни програми"
    echo "5) Системна администрация"
    echo "6) AppImageLauncher"
    echo "7) Brave браузър"
    echo "8) Google Chrome"
    echo "9) Nextcloud Desktop"
    echo "10) Viber"
    echo "11) AnyDesk"
    echo "12) Премахване на всички"
    echo "0) Връщане"
    separator
}

install_menu() {
    while true; do
        show_install_menu
        read -rp "Изберете действие: " choice
        echo

        case "$choice" in
            1)
                install_basic_tools
                pause_screen
                ;;
            2)
                install_web_tools
                pause_screen
                ;;
            3)
                install_backup_tools
                pause_screen
                ;;
            4)
                install_multimedia_tools
                pause_screen
                ;;
            5)
                install_admin_tools
                pause_screen
                ;;
            6)
                install_appimagelauncher
                pause_screen
                ;;
            7)
                install_brave
                pause_screen
                ;;
            8)
                install_chrome
                pause_screen
                ;;
            9)
                install_nextcloud
                pause_screen
                ;;
            10)
                install_viber
                pause_screen
                ;;
            11)
                install_anydesk
                pause_screen
                ;;
            12)
                install_basic_tools
                install_web_tools
                install_backup_tools
                install_multimedia_tools
                install_admin_tools
                install_appimagelauncher
                install_brave
                install_chrome
                install_nextcloud
                install_viber
                install_anydesk
                pause_screen
                ;;
            0)
                return
                ;;
            *)
                error "Невалиден избор."
                sleep 1
                ;;
        esac
    done
}

remove_menu() {
    while true; do
        show_remove_menu
        read -rp "Изберете действие: " choice
        echo

        case "$choice" in
            1)
                if confirm "Да се премахнат ли основните инструменти и програми"; then
                    remove_basic_tools
                fi
                pause_screen
                ;;
            2)
                if confirm "Да се премахнат ли инструментите за уеб разработка"; then
                    remove_web_tools
                fi
                pause_screen
                ;;
            3)
                if confirm "Да се премахнат ли инструментите за архивиране"; then
                    remove_backup_tools
                fi
                pause_screen
                ;;
            4)
                if confirm "Да се премахнат ли мултимедийните програми"; then
                    remove_multimedia_tools
                fi
                pause_screen
                ;;
            5)
                if confirm "Да се премахнат ли системните инструменти"; then
                    remove_admin_tools
                fi
                pause_screen
                ;;
            6)
                if confirm "Да се премахне ли AppImageLauncher"; then
                    remove_packages appimagelauncher
                fi
                pause_screen
                ;;
            7)
                if confirm "Да се премахне ли Brave"; then
                    remove_packages brave-browser
                    remove_brave_repository
                fi
                pause_screen
                ;;
            8)
                if confirm "Да се премахне ли Google Chrome"; then
                    remove_packages google-chrome-stable
                fi
                pause_screen
                ;;
            9)
                remove_appimage \
                    "Nextcloud Desktop" \
                    "Nextcloud-x86_64.AppImage"
                pause_screen
                ;;
            10)
                remove_appimage \
                    "Viber" \
                    "viber.AppImage"
                pause_screen
                ;;
            11)
                if confirm "Да се премахне ли AnyDesk"; then
                    remove_packages anydesk
                    remove_anydesk_repository
                fi
                pause_screen
                ;;
            12)
                if confirm "Да се премахнат ли всички програми"; then
                    remove_basic_tools
                    remove_web_tools
                    remove_backup_tools
                    remove_multimedia_tools
                    remove_admin_tools
                    remove_packages appimagelauncher
                    remove_packages brave-browser
                    remove_packages google-chrome-stable
                    remove_packages anydesk

                    remove_appimage \
                        "Nextcloud Desktop" \
                        "Nextcloud-x86_64.AppImage"

                    remove_appimage \
                        "Viber" \
                        "viber.AppImage"

                    remove_brave_repository
                    remove_anydesk_repository
                    apt_update
                fi
                pause_screen
                ;;
            0)
                return
                ;;
            *)
                error "Невалиден избор."
                sleep 1
                ;;
        esac
    done
}

# ------------------------------------------------------------
# Допълнителни функции
# ------------------------------------------------------------

system_update() {
    info "Обновяване на системата..."

    apt_update || return 1
    run_sudo apt-get upgrade -y
    run_sudo apt-get autoremove -y

    success "Системата беше обновена."
}

clean_temp_files() {
    echo "Ще бъдат изтрити временните файлове от:"
    echo
    echo "  $TEMP_DIR"
    echo

    if confirm "Да продължа ли"; then
        rm -rf "${TEMP_DIR:?}"/*
        success "Временните файлове бяха изтрити."
    else
        warning "Почистването беше отказано."
    fi

    pause_screen
}

system_information() {
    show_header

    echo -e "${CYAN}${BOLD}Информация за системата${RESET}"
    separator

    if command_exists hostnamectl; then
        hostnamectl
    else
        uname -a
    fi

    echo
    echo "Дисково пространство:"
    df -h "$HOME"

    echo
    echo "Памет:"
    free -h

    echo
    echo "Архитектура:"
    dpkg --print-architecture

    echo
    echo "Версия на Bash:"
    bash --version | head -n 1

    pause_screen
}

# ------------------------------------------------------------
# Главно меню
# ------------------------------------------------------------

main_menu() {
    while true; do
        show_main_menu
        read -rp "Изберете действие: " choice
        echo

        case "$choice" in
            1)
                install_menu
                ;;
            2)
                remove_menu
                ;;
            3)
                system_update
                pause_screen
                ;;
            4)
                clean_temp_files
                ;;
            5)
                system_information
                ;;
            0)
                echo -e "${CYAN}До скоро!${RESET}"
                exit 0
                ;;
            *)
                error "Невалиден избор."
                sleep 1
                ;;
        esac
    done
}

# ------------------------------------------------------------
# Стартиране
# ------------------------------------------------------------

check_environment

if ! command_exists curl; then
    echo "Командата curl липсва. Ще бъде инсталирана."

    sudo apt-get update
    sudo apt-get install -y curl ca-certificates
fi

check_internet || exit 1

log "Стартиран Linux Application Manager"
log "Потребител: ${USER}"
log "Домашна директория: ${HOME}"

main_menu