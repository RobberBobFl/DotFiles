#!/bin/bash
set -euo pipefail
set -o errtrace

# =============================================================================
# DOTFILES INSTALLER — финальная версия
# =============================================================================
# Использование:
#   ./<скрипт>           # обычная установка
#   ./<скрипт> --dry-run # предпросмотр без изменений
# =============================================================================

# --- КОНФИГУРАЦИЯ ---
DRY_RUN=false
LOG_FILE="install-$(date +%F).log"
SUCCESS=false

# --- ПОЛЬЗОВАТЕЛЬ ---
REAL_USER="${SUDO_USER:-$(whoami)}"
USER_HOME="$(getent passwd "$REAL_USER" | cut -d: -f6)"
DOT_DIR="$USER_HOME/DotFiles/dms-dots"

readonly REAL_USER
readonly USER_HOME
readonly DOT_DIR
readonly LOG_FILE

# PID процесса sudo keepalive
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

if ! command -v pacman &>/dev/null; then
    error "Этот скрипт предназначен только для Arch Linux."
fi

if [ ! -d "$DOT_DIR" ]; then
    error "Папка DotFiles не найдена: $DOT_DIR"
fi

if [ "$DRY_RUN" = false ]; then
    info "Запрос прав администратора..."
    sudo -v
    start_sudo_keepalive
fi

# =============================================================================
# --- ВЫБОР НАБОРА ПАКЕТОВ ---
# =============================================================================

echo
echo "Выберите набор программ для установки:"
echo "  1) GTK (GNOME-based)"
echo "  2) QT (KDE-based)"
echo

read -rp "Введите цифру (1 или 2): " choice
CHOICE="$choice"

if [[ "$choice" == "1" ]]; then
    info "Выбран набор GTK."

    PKGS_PACMAN=(
        breeze adw-gtk-theme capitaine-cursors tela-circle-icon-theme-all
        ddcutil i2c-tools dgop matugen fish gnome-calculator xdg-desktop-portal-gtk
        gnome-keyring xwayland-satellite alacritty cliphist wlsunset qt6-wayland
        qt5-wayland kvantum kvantum-qt5 baobab ttf-roboto ttf-fira-code
        ttf-firacode-nerd micro pavucontrol blueman networkmanager
        network-manager-applet thunar nwg-look obsidian qbittorrent nodejs npm
        neovim geany yazi git mangohud kitty ripgrep eza wl-clipboard dconf niri
        keyd celluloid imv xarchiver xfce4-settings gvfs-mtp gvfs-afc libmtp
        tumbler nvtop gnome-disk-utility heroic-games-launcher-bin
        fuse2 foliate zed obs-studio ncdu socat xdg-desktop-portal-wlr gparted
        archlinux-xdg-menu
    )
    PKGS_AUR=(
        greetd-dms-greeter-git quickshell-git v2rayn yandex-browser
        geany-themes xdg-terminal-exec qt6ct-kde qt5ct-kde dsearch-bin
        portprotonqt python-pywalfox dms-shell-git
    )

elif [[ "$choice" == "2" ]]; then
    info "Выбран набор QT."

    PKGS_PACMAN=(
        dolphin kate ark kcalc breeze adw-gtk-theme capitaine-cursors
        tela-circle-icon-theme-all
        ddcutil i2c-tools dgop matugen fish
        xdg-desktop-portal-kde xwayland-satellite alacritty cliphist wlsunset
        qt6-wayland qt5-wayland kvantum kvantum-qt5 ttf-roboto ttf-fira-code
        ttf-firacode-nerd micro pavucontrol blueman networkmanager
        network-manager-applet nwg-look obsidian qbittorrent nodejs npm neovim
        filelight yazi git mangohud kitty ripgrep eza wl-clipboard dconf niri
        keyd gnome-keyring imv mpv nvtop kio-extras kio-admin gvfs-mtp gvfs-afc
        libmtp ffmpegthumbs kdegraphics-thumbnailers gnome-disk-utility
        heroic-games-launcher-bin
        fuse2 foliate zed obs-studio ncdu socat xdg-desktop-portal-wlr gparted
        archlinux-xdg-menu
    )
    PKGS_AUR=(
        greetd-dms-greeter-git quickshell-git v2rayn yandex-browser
        xdg-terminal-exec qt6ct-kde qt5ct-kde dsearch-bin
        portprotonqt python-pywalfox dms-shell-git
    )
else
    error "Неверный выбор. Введите 1 или 2."
fi

# =============================================================================
# --- УСТАНОВКА: PACMAN ---
# =============================================================================

info "Обновление системы..."
run_cmd sudo pacman -Syu --noconfirm --ask=4

# --- Фильтрация пакетов: проверяем доступность в репозиториях ---
info "Проверка доступности пакетов в репозиториях..."

AVAILABLE_PKGS=()
MISSING_PKGS=()

for pkg in "${PKGS_PACMAN[@]}"; do
    if pacman -Si "$pkg" &>/dev/null; then
        AVAILABLE_PKGS+=("$pkg")
    else
        MISSING_PKGS+=("$pkg")
    fi
done

# Сообщаем о пропущенных пакетах
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

# Устанавливаем только доступные пакеты
if [ ${#AVAILABLE_PKGS[@]} -gt 0 ]; then
    info "Установка пакетов из репозиториев..."
    run_cmd sudo pacman -S --needed --noconfirm --ask=4 "${AVAILABLE_PKGS[@]}"
else
    warn "Нет доступных пакетов для установки из репозиториев."
fi

# =============================================================================
# --- УСТАНОВКА: AUR HELPER ---
# =============================================================================

if command -v yay &>/dev/null; then
    AUR_HELPER="yay"
elif command -v paru &>/dev/null; then
    AUR_HELPER="paru"
else
    info "Установка yay..."

    run_cmd sudo pacman -S --needed --noconfirm --ask=4 git base-devel
    run_cmd rm -rf /tmp/yay
    run_cmd git clone https://aur.archlinux.org/yay.git /tmp/yay

    if [ "$DRY_RUN" = false ] && [ -d /tmp/yay ]; then
        (cd /tmp/yay && makepkg -si --noconfirm)
    else
        info "[DRY-RUN] Сборка yay из AUR..."
    fi
    AUR_HELPER="yay"
fi

# =============================================================================
# --- УСТАНОВКА: AUR ПАКЕТЫ ---
# =============================================================================

info "Установка AUR-пакетов (подтверждение каждого пакета вручную)..."
if [ "$DRY_RUN" = true ]; then
    run_cmd "$AUR_HELPER" -S --needed "${PKGS_AUR[@]}"
else
    "$AUR_HELPER" -S --needed "${PKGS_AUR[@]}"
fi

# =============================================================================
# --- НАСТРОЙКА: ГРУППЫ ПОЛЬЗОВАТЕЛЯ ---
# =============================================================================

info "Настройка прав для пользователя $REAL_USER..."
run_cmd sudo usermod -aG i2c "$REAL_USER"

if getent group greeter >/dev/null; then
    run_cmd sudo usermod -aG greeter "$REAL_USER"
else
    warn "Группа 'greeter' не найдена, пропускаю."
fi

# =============================================================================
# --- НАСТРОЙКА: KEYD ---
# =============================================================================

if [ -f "$USER_HOME/DotFiles/default.conf" ]; then
    info "Настройка keyd..."
    run_cmd sudo mkdir -p /etc/keyd
    run_cmd sudo cp "$USER_HOME/DotFiles/default.conf" /etc/keyd/default.conf
    run_cmd sudo systemctl enable --now keyd
else
    warn "Конфиг keyd не найден, пропускаю."
fi

# =============================================================================
# --- НАСТРОЙКА: ЛИНКОВКА КОНФИГОВ ---
# =============================================================================

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

# =============================================================================
# --- НАСТРОЙКА: ОБОИ ---
# =============================================================================

if [ -d "$USER_HOME/DotFiles/wallpaper" ]; then
    info "Настройка обоев..."
    run_cmd mkdir -p "$USER_HOME/Pictures"
    run_cmd ln -sfn "$USER_HOME/DotFiles/wallpaper" "$USER_HOME/Pictures/wallpaper"
else
    warn "Папка wallpaper не найдена, пропускаю."
fi

# =============================================================================
# --- НАСТРОЙКА: ТЁМНАЯ ТЕМА ---
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
# --- НАСТРОЙКА: Niri Portals ---
# =============================================================================

NIRI_PORTALS="/usr/share/xdg-desktop-portal/niri-portals.conf"

if [ -f "$NIRI_PORTALS" ]; then
    info "Настройка niri-portals.conf..."

    # 9) FileChooser: проверяем наличие, заменяем или добавляем
    if [ "$DRY_RUN" = true ]; then
        echo -e "\e[36m[DRY-RUN]\e[0m Проверил бы/добавил бы: FileChooser=gtk;"
    else
        if sudo grep -q "^org\.freedesktop\.impl\.portal\.FileChooser=" "$NIRI_PORTALS"; then
            # Строка уже есть — заменяем значение на gtk
            sudo sed -i 's|^org\.freedesktop\.impl\.portal\.FileChooser=.*|org.freedesktop.impl.portal.FileChooser=gtk;|' "$NIRI_PORTALS"
            info "Заменено: FileChooser=gtk;"
        else
            # Строки нет — добавляем в конец
            echo "org.freedesktop.impl.portal.FileChooser=gtk;" | sudo tee -a "$NIRI_PORTALS" > /dev/null
            info "Добавлено: FileChooser=gtk;"
        fi
    fi

    # 10) ScreenCast: проверяем наличие, заменяем или добавляем
    if [ "$DRY_RUN" = true ]; then
        echo -e "\e[36m[DRY-RUN]\e[0m Проверил бы/добавил бы: ScreenCast=wlr;"
    else
        if sudo grep -q "^org\.freedesktop\.impl\.portal\.ScreenCast=" "$NIRI_PORTALS"; then
            # Строка уже есть — заменяем значение на wlr
            sudo sed -i 's|^org\.freedesktop\.impl\.portal\.ScreenCast=.*|org.freedesktop.impl.portal.ScreenCast=wlr;|' "$NIRI_PORTALS"
            info "Заменено: ScreenCast=wlr;"
        else
            # Строки нет — добавляем в конец
            echo "org.freedesktop.impl.portal.ScreenCast=wlr;" | sudo tee -a "$NIRI_PORTALS" > /dev/null
            info "Добавлено: ScreenCast=wlr;"
        fi
    fi
else
    warn "Файл $NIRI_PORTALS не найден, пропускаю настройку порталов."
fi

# =============================================================================
# --- НАСТРОЙКА: СПЕЦИФИЧНЫЕ ДЛЯ QT ---
# =============================================================================

if [[ "$CHOICE" == "2" ]]; then
    info "Применение специфичных настроек QT..."

    # 6) Линк arch-applications.menu
    run_cmd sudo ln -sf /etc/xdg/menus/arch-applications.menu /etc/xdg/menus/applications.menu
    [ "$DRY_RUN" = false ] && info "Создан линк: arch-applications.menu -> applications.menu"

    # 7) kwriteconfig6: установка alacritty как терминал по умолчанию
    if command -v kwriteconfig6 &>/dev/null; then
        run_cmd kwriteconfig6 --file kdeglobals --group General --key TerminalApplication "alacritty"
        [ "$DRY_RUN" = false ] && info "Установлен терминал по умолчанию: alacritty"
    else
        warn "kwriteconfig6 не найден, пропускаю настройку терминала."
    fi
fi

# =============================================================================
# --- НАСТРОЙКА: PYWALFOX ---
# =============================================================================

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
# --- НАСТРОЙКА: SHELL (FISH) ---
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
# --- ЗАВЕРШЕНИЕ ---
# =============================================================================

SUCCESS=true

info "Установка завершена!"
info "Рекомендуется перезагрузить систему."

# cleanup() вызовется автоматически через trap
