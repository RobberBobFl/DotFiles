#!/bin/bash
set -euo pipefail
set -o errtrace

# =============================================================================
# FEDORA DOTFILES INSTALLER (QT-only) — порт arch-dms_v3.sh под Fedora
# =============================================================================
# Использование:
#   sudo ./fedora-dms.sh           # обычная установка
#   sudo ./fedora-dms.sh --dry-run # предпросмотр без изменений
# =============================================================================

# --- КОНФИГУРАЦИЯ ---
DRY_RUN=false
LOG_FILE="fedora-install-$(date +%F).log"
SUCCESS=false

# --- ПОЛЬЗОВАТЕЛЬ ---
REAL_USER="${SUDO_USER:-$(whoami)}"
USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
DOT_DIR="$USER_HOME/DotFiles/dms-dots"

readonly REAL_USER
readonly USER_HOME
readonly DOT_DIR
readonly LOG_FILE

SUDO_KEEPALIVE_PID=""

# =============================================================================
# --- ОБРАБОТКА АРГУМЕНТОВ ---
# =============================================================================
WARN_UNKNOWN_ARG=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        -d|--dry-run)
            DRY_RUN=true
            shift
            ;;
        *)
            WARN_UNKNOWN_ARG=true
            echo -e "\e[33m[WARN]\e[0m Неизвестный аргумент: $1" >&2
            shift
            ;;
    esac
done

show_usage_hint() {
    if [ "$WARN_UNKNOWN_ARG" = true ]; then
        echo -e "\e[33m[WARN]\e[0m Использование: $0 [--dry-run]" >&2
    fi
}

# =============================================================================
# --- ФУНКЦИИ ---
# =============================================================================

info() {
    if [ "$DRY_RUN" = true ]; then
        echo -e "\e[36m[DRY-RUN]\e[0m $1"
    else
        echo -e "\e[32m[INFO]\e[0m $1"
    fi
}

warn() {
    echo -e "\e[33m[WARN]\e[0m $1" >&2
}

error() {
    echo -e "\e[31m[ERROR]\e[0m $1" >&2
    exit 1
}

run_cmd() {
    local msg=""
    printf -v msg '%q ' "$@"

    if [ "$DRY_RUN" = true ]; then
        echo -e "\e[36m[DRY-RUN]\e[0m Выполнил бы: $msg"
    else
        "$@"
    fi
}

start_sudo_keepalive() {
    while true; do
        sudo -n true 2>/dev/null || break
        sleep 60
        kill -0 "$$" 2>/dev/null || break
    done &
    SUDO_KEEPALIVE_PID=$!
}

stop_sudo_keepalive() {
    if [[ -n "${SUDO_KEEPALIVE_PID:-}" ]]; then
        kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
        wait "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    fi
}

handle_error() {
    local exit_code=$?
    local line_no=$1
    echo >&2
    echo -e "\e[31m[ERROR]\e[0m Ошибка на строке $line_no (код: $exit_code)" >&2
}
trap 'handle_error $LINENO' ERR

handle_sigint() {
    echo >&2
    warn "Получен сигнал прерывания (Ctrl+C)"
    exit 130
}
trap handle_sigint SIGINT SIGTERM

cleanup() {
    local exit_code=$?
    stop_sudo_keepalive
    show_usage_hint

    echo >&2

    if [ "$exit_code" -eq 130 ]; then
        warn "Установка прервана пользователем."
    elif [ "$SUCCESS" = true ]; then
        info "Установка успешно завершена."
    elif [ "$exit_code" -ne 0 ]; then
        echo -e "\e[31m[ERROR]\e[0m Скрипт завершился с ошибкой (код: $exit_code)." >&2
    fi

    if [ -f "$LOG_FILE" ]; then
        info "Полный лог доступен: $LOG_FILE"
    fi

    exit $exit_code
}
trap cleanup EXIT

# =============================================================================
# --- ИНИЦИАЛИЗАЦИЯ ---
# =============================================================================

exec > >(tee -a "$LOG_FILE") 2>&1

[ "$DRY_RUN" = true ] && info "Запущен в режиме предпросмотра (изменения не будут внесены)"

if [ "$(id -u)" -ne 0 ]; then
    error "Этот скрипт нужно запускать с правами root: sudo $0"
fi

if ! command -v dnf &>/dev/null; then
    error "Этот скрипт предназначен только для Fedora (dnf не найден)."
fi

if ! [ -f /etc/fedora-release ]; then
    warn "Похоже, это не Fedora (/etc/fedora-release не найден). Продолжаю на свой страх и риск."
fi

if [ ! -d "$DOT_DIR" ]; then
    warn "Папка DotFiles не найдена: $DOT_DIR — линковка конфигов будет пропущена."
fi

if [ "$DRY_RUN" = false ]; then
    info "Запрос прав администратора..."
    sudo -v
    start_sudo_keepalive
fi

# =============================================================================
# --- ШАГ 0: GEOBLOCK-ФИКС (Cisco openh264 + RPM Fusion + кодеки) ---
# =============================================================================

info "Применение geoblock-фикса (fedora-cisco-403-mitigation.sh)..."

MITIGATION_URL="https://raw.githubusercontent.com/supertico/fedora-open264-geoblock-fix/main/fedora-cisco-403-mitigation.sh"

if [ "$DRY_RUN" = true ]; then
    echo -e "\e[36m[DRY-RUN]\e[0m Скачал бы и запустил: $MITIGATION_URL"
else
    curl -fsSL "$MITIGATION_URL" -o /tmp/fedora-cisco-403-mitigation.sh
    bash /tmp/fedora-cisco-403-mitigation.sh
    rm -f /tmp/fedora-cisco-403-mitigation.sh
fi

info "Подключение Flathub (remote only)..."
run_cmd sudo dnf install -y flatpak
if ! flatpak remotes 2>/dev/null | grep -qi flathub; then
    info "Добавление Flathub remote (без интерактивного промпта)..."
    ( set +o pipefail; yes | run_cmd sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo ) || true
else
    info "Flathub уже подключён, пропускаю."
fi
info "Geoblock-фикс применён. Продолжаем установку пакетов..."

# =============================================================================
# --- ШАГ 1: DNF-ПАКЕТЫ (QT-НАБОР) ---
# =============================================================================

PKGS=(
    dolphin kate ark kcalc plasma-breeze
    adw-gtk3-theme la-capitaine-cursor-theme
    ddcutil i2c-tools fish
    xdg-desktop-portal-kde xwayland-satellite alacritty cliphist wlsunset
    qt6-wayland qt5-wayland kvantum qt6ct qt5ct
    google-roboto-fonts fira-code-fonts
    micro pavucontrol blueman NetworkManager network-manager-applet
    nwg-look qbittorrent nodejs npm neovim filelight yazi git
    mangohud kitty ripgrep eza wl-clipboard dconf niri
    gnome-keyring imv mpv nvtop kio-extras kio-admin
    gvfs-mtp gvfs-afc libmtp ffmpegthumbs kdegraphics-thumbnailers
    gnome-disk-utility fuse ncdu socat xdg-desktop-portal-wlr gparted
    xdg-terminal-exec matugen quickshell obs-studio
    make gcc python3-pip
)

info "Обновление системы..."
run_cmd sudo dnf upgrade -y

info "Проверка доступности пакетов в репозиториях..."
run_cmd sudo dnf makecache

AVAILABLE_PKGS=()
MISSING_PKGS=()

for pkg in "${PKGS[@]}"; do
    if dnf repoquery --available --quiet "$pkg" &>/dev/null; then
        AVAILABLE_PKGS+=("$pkg")
    else
        MISSING_PKGS+=("$pkg")
    fi
done

if [ ${#MISSING_PKGS[@]} -gt 0 ]; then
    warn "Следующие пакеты не найдены в репозиториях:"
    printf '  - %s\n' "${MISSING_PKGS[@]}" >&2

    if [ "$DRY_RUN" = true ]; then
        echo -e "\e[36m[DRY-RUN]\e[0m Продолжил бы установку без них."
    else
        read -rp "Продолжить установку без этих пакетов? [Y/n] " answer
        if [[ "$answer" =~ ^[Nn] ]]; then
            error "Установка прервана пользователем."
        fi
    fi
fi

if [ ${#AVAILABLE_PKGS[@]} -gt 0 ]; then
    info "Установка пакетов из репозиториев..."
    run_cmd sudo dnf install -y --needed "${AVAILABLE_PKGS[@]}"
else
    warn "Нет доступных пакетов для установки из репозиториев."
fi

# =============================================================================
# --- ШАГ 2: GIT-СБОРКИ (с очисткой исходников) ---
# =============================================================================

build_keyd() {
    info "Сборка keyd из исходников..."
    if [ "$DRY_RUN" = true ]; then
        echo -e "\e[36m[DRY-RUN]\e[0m Клонировал бы, собрал и установил keyd, затем удалил /tmp/keyd"
        return
    fi
    rm -rf /tmp/keyd
    git clone https://github.com/rvaiya/keyd /tmp/keyd
    (cd /tmp/keyd && make && sudo make install)
    sudo mkdir -p /etc/keyd
    if [ -f "$USER_HOME/DotFiles/default.conf" ]; then
        sudo cp "$USER_HOME/DotFiles/default.conf" /etc/keyd/default.conf
        info "Скопирован конфиг keyd: $USER_HOME/DotFiles/default.conf"
    else
        warn "Конфиг keyd не найден ($USER_HOME/DotFiles/default.conf), пропускаю."
    fi
    sudo systemctl enable --now keyd
    rm -rf /tmp/keyd
}
build_keyd

build_tela() {
    info "Установка tela-circle-icon-theme (скрипт upstream)..."
    if [ "$DRY_RUN" = true ]; then
        echo -e "\e[36m[DRY-RUN]\e[0m Клонировал бы Tela-circle-icon-theme и запустил ./install.sh -a, затем удалил исходники"
        return
    fi
    rm -rf /tmp/Tela-circle-icon-theme
    git clone https://github.com/vinceliuice/Tela-circle-icon-theme.git /tmp/Tela-circle-icon-theme
    (cd /tmp/Tela-circle-icon-theme && ./install.sh -a)
    rm -rf /tmp/Tela-circle-icon-theme
}
build_tela

# =============================================================================
# --- ШАГ 3: DMS (официальный инсталлер dankinstall, от имени пользователя) ---
# =============================================================================

install_dms() {
    info "Установка DMS через официальный инсталлер (dankinstall) от $REAL_USER..."
    if [ "$DRY_RUN" = true ]; then
        echo -e "\e[36m[DRY-RUN]\e[0m Скачал бы и запустил dankinstall от $REAL_USER"
        return 0
    fi
    sudo -u "$REAL_USER" bash -s <<'DMSINSTALL'
set -e
ARCH=$(uname -m)
case "$ARCH" in
  x86_64) ARCH="amd64" ;;
  aarch64) ARCH="arm64" ;;
  *) echo "Неподдерживаемая архитектура: $ARCH"; exit 1 ;;
esac
LATEST_VERSION=$(curl -s https://api.github.com/repos/AvengeMedia/DankMaterialShell/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
[ -z "$LATEST_VERSION" ] && { echo "Не удалось получить версию DMS"; exit 1; }
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR"
curl -L "https://github.com/AvengeMedia/DankMaterialShell/releases/download/$LATEST_VERSION/dankinstall-$ARCH.gz" -o installer.gz
curl -L "https://github.com/AvengeMedia/DankMaterialShell/releases/download/$LATEST_VERSION/dankinstall-$ARCH.gz.sha256" -o expected.sha256
EXPECTED=$(awk '{print $1}' expected.sha256)
ACTUAL=$(sha256sum installer.gz | awk '{print $1}')
if [ "$EXPECTED" != "$ACTUAL" ]; then echo "Ошибка проверки checksum DMS"; exit 1; fi
gunzip installer.gz
chmod +x installer
./installer
cd /
rm -rf "$TEMP_DIR"
DMSINSTALL
}
install_dms

# =============================================================================
# --- ШАГ 4: COPR + ВНЕШНИЕ ИНСТАЛЛЕРЫ ---
# =============================================================================

info "Установка portprotonqt (COPR boria138/portproton)..."
run_cmd sudo dnf copr enable -y boria138/portproton
run_cmd sudo dnf install -y portproton

info "Установка opencode..."
run_cmd sudo -u "$REAL_USER" bash -c 'curl -fsSL https://opencode.ai/install | bash'

info "Установка ollama..."
run_cmd sudo bash -c 'curl -fsSL https://ollama.com/install.sh | sh'

info "Установка pi..."
run_cmd sudo -u "$REAL_USER" bash -c 'curl -fsSL https://pi.dev/install.sh | sh'

# =============================================================================
# --- ШАГ 5: PYWALFOX ---
# =============================================================================

info "Установка python-pywalfox..."
run_cmd sudo -u "$REAL_USER" python3 -m pip install --user python-pywalfox

PYWALFOX_SRC="$USER_HOME/.cache/wal/dank-pywalfox.json"
PYWALFOX_DST="$USER_HOME/.cache/wal/colors.json"

if [ -f "$PYWALFOX_SRC" ]; then
    info "Настройка pywalfox..."
    run_cmd ln -sf "$PYWALFOX_SRC" "$PYWALFOX_DST"
    [ "$DRY_RUN" = false ] && info "Создан линк: dank-pywalfox.json -> colors.json"
else
    warn "Файл $PYWALFOX_SRC не найден, пропускаю настройку pywalfox."
fi

# =============================================================================
# --- ШАГ 6: ЛИНКОВКА КОНФИГОВ ---
# =============================================================================

if [ -d "$DOT_DIR" ]; then
    info "Линковка ~/.config из $DOT_DIR..."
    run_cmd mkdir -p "$USER_HOME/.config"

    find "$DOT_DIR" -mindepth 1 -maxdepth 1 -print0 | while IFS= read -r -d '' item; do
        base="$(basename "$item")"
        target="$USER_HOME/.config/$base"

        if ! real_source="$(realpath "$item" 2>/dev/null)"; then
            warn "Не удалось обработать: $item"
            continue
        fi

        if [ -L "$target" ] && [ "$(realpath "$target" 2>/dev/null)" = "$real_source" ]; then
            continue
        fi

        if [ -e "$target" ] || [ -L "$target" ]; then
            backup="${target}.backup.$(date +%F_%H-%M-%S)"
            if [ "$DRY_RUN" = true ]; then
                echo -e "\e[36m[DRY-RUN]\e[0m Создал бы бэкап: $backup"
            else
                mv "$target" "$backup"
                info "Бэкап: $backup"
            fi
        fi

        run_cmd ln -sfn "$real_source" "$target"
        [ "$DRY_RUN" = false ] && info "Линковка: $base -> $real_source"
    done

    if [ -d "$USER_HOME/DotFiles/wallpaper" ]; then
        info "Настройка обоев..."
        run_cmd mkdir -p "$USER_HOME/Pictures"
        run_cmd ln -sfn "$USER_HOME/DotFiles/wallpaper" "$USER_HOME/Pictures/wallpaper"
    else
        warn "Папка wallpaper не найдена, пропускаю."
    fi
else
    warn "DOT_DIR не существует, линковка конфигов пропущена."
fi

# =============================================================================
# --- ШАГ 7: ТЁМНАЯ ТЕМА ---
# =============================================================================

info "Включение тёмной темы..."

if command -v gsettings &>/dev/null; then
    run_cmd gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
elif command -v dconf &>/dev/null; then
    run_cmd dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'" 2>/dev/null || true
else
    warn "Ни gsettings, ни dconf не найдены, пропускаю настройку темы."
fi

# =============================================================================
# --- ШАГ 8: NIRI PORTALS ---
# =============================================================================

NIRI_PORTALS="/usr/share/xdg-desktop-portal/niri-portals.conf"

if [ -f "$NIRI_PORTALS" ]; then
    info "Настройка niri-portals.conf..."

    if [ "$DRY_RUN" = true ]; then
        echo -e "\e[36m[DRY-RUN]\e[0m Проверил бы/добавил бы: FileChooser=kde;"
    else
        if sudo grep -q "^org\.freedesktop\.impl\.portal\.FileChooser=" "$NIRI_PORTALS"; then
            sudo sed -i 's|^org\.freedesktop\.impl\.portal\.FileChooser=.*|org.freedesktop.impl.portal.FileChooser=kde;|' "$NIRI_PORTALS"
            info "Заменено: FileChooser=kde;"
        else
            echo "org.freedesktop.impl.portal.FileChooser=kde;" | sudo tee -a "$NIRI_PORTALS" > /dev/null
            info "Добавлено: FileChooser=kde;"
        fi
    fi

    if [ "$DRY_RUN" = true ]; then
        echo -e "\e[36m[DRY-RUN]\e[0m Проверил бы/добавил бы: ScreenCast=wlr;"
    else
        if sudo grep -q "^org\.freedesktop\.impl\.portal\.ScreenCast=" "$NIRI_PORTALS"; then
            sudo sed -i 's|^org\.freedesktop\.impl\.portal\.ScreenCast=.*|org.freedesktop.impl.portal.ScreenCast=wlr;|' "$NIRI_PORTALS"
            info "Заменено: ScreenCast=wlr;"
        else
            echo "org.freedesktop.impl.portal.ScreenCast=wlr;" | sudo tee -a "$NIRI_PORTALS" > /dev/null
            info "Добавлено: ScreenCast=wlr;"
        fi
    fi
else
    warn "Файл $NIRI_PORTALS не найден, пропускаю настройку порталов."
fi

# =============================================================================
# --- ШАГ 9: QT-СПЕЦИФИЧНЫЕ НАСТРОЙКИ ---
# =============================================================================

info "Применение специфичных настроек QT..."

if command -v kwriteconfig6 &>/dev/null; then
    run_cmd kwriteconfig6 --file kdeglobals --group General --key TerminalApplication "alacritty"
    [ "$DRY_RUN" = false ] && info "Установлен терминал по умолчанию: alacritty"
else
    warn "kwriteconfig6 не найден, пропускаю настройку терминала."
fi

# =============================================================================
# --- ШАГ 10: SHELL (FISH) ---
# =============================================================================

FISH_BIN="$(command -v fish 2>/dev/null || true)"
if [ -n "$FISH_BIN" ]; then
    CURRENT_SHELL="$(getent passwd "$REAL_USER" | cut -d: -f7)"

    if [ "$CURRENT_SHELL" != "$FISH_BIN" ]; then
        info "Смена shell на fish для пользователя $REAL_USER..."

        if ! grep -qxF "$FISH_BIN" /etc/shells 2>/dev/null; then
            run_cmd sudo sh -c "echo '$FISH_BIN' >> /etc/shells"
        fi

        run_cmd sudo usermod -s "$FISH_BIN" "$REAL_USER"
    fi
else
    warn "fish не найден в системе, пропускаю смену shell."
fi

# =============================================================================
# --- ЗАВЕРШЕНИЕ + НАПОМИНАЛКА ---
# =============================================================================

SUCCESS=true

info "Установка завершена!"
info "Рекомендуется перезагрузить систему."

echo
echo -e "\e[33m[НАПОМИНАНИЕ]\e[0m Следующие приложения установи вручную (версии плывут, поэтому не вшиваем):"
echo "  - Yandex-браузер : https://browser.yandex.ru/"
echo "  - v2rayn         : https://github.com/2dust/v2rayN/releases"
echo "  - Obsidian       : https://github.com/obsidianmd/obsidian-releases/releases"
echo "  - Telegram       : https://desktop.telegram.org/"
echo "  - Heroic Games   : https://github.com/Heroic-Games-Launcher/HeroicGamesLauncher/releases"

# cleanup() вызовется автоматически через trap
