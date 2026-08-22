#!/bin/bash
set -euo pipefail
set -o errtrace

# =============================================================================
# FEDORA DOTFILES INSTALLER (QT-only) — порт arch-dms_v3.sh под Fedora
# =============================================================================
# Использование:
#   sudo ./fedora-dms.sh                 # обычная установка
#   sudo ./fedora-dms.sh --dry-run       # предпросмотр без изменений
#   sudo ./fedora-dms.sh --status        # статус выполненных шагов
#   sudo ./fedora-dms.sh --list-steps    # список шагов
#   sudo ./fedora-dms.sh --from flathub  # продолжить с указанного шага
#   sudo ./fedora-dms.sh --reset         # сбросить state и начать заново
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
SUDOERS_TMP=""

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

setup_temp_sudoers() {
    [ "$DRY_RUN" = true ] && return 0
    SUDOERS_TMP="/etc/sudoers.d/zz-dms-temp-$$"
    echo "$REAL_USER ALL=(ALL) NOPASSWD: ALL" > "$SUDOERS_TMP"
    chmod 0440 "$SUDOERS_TMP"
    if command -v visudo &>/dev/null; then
        if ! visudo -cf "$SUDOERS_TMP" >/dev/null 2>&1; then
            rm -f "$SUDOERS_TMP"
            SUDOERS_TMP=""
            warn "Не удалось создать временный sudoers (visudo не прошёл), пароль может потребоваться внутри установщиков."
            return 1
        fi
    fi
    info "Временно выдан passwordless sudo для $REAL_USER (снимется в конце)."
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
    if [[ -n "${SUDOERS_TMP:-}" ]]; then
        rm -f "$SUDOERS_TMP" 2>/dev/null || true
        info "Временный passwordless sudo снят."
    fi
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
# --- STATE & RESUME МЕНЕДЖЕР ---
# =============================================================================
STATE_DIR="$USER_HOME/.local/state"
STATE_FILE="$STATE_DIR/dms-install.state"
RESUME_MODE=false
FROM_STEP=""
RESET_STATE=false

# Упорядоченный массив шагов
STEPS=(
    "geoblock"
    "flathub"
    "packages"
    "gitbuilds"
    "dms_prep"
    "dms_install"
    "copr_external"
    "pywalfox"
    "symlink"
    "theme_portals_qt"
    "shell"
)

init_state() {
    if [ "$RESET_STATE" = true ]; then
        info "Сброс состояния установки..."
        run_cmd rm -f "$STATE_FILE"
    fi

    if [ ! -d "$STATE_DIR" ]; then
        run_cmd mkdir -p "$STATE_DIR"
        run_cmd chown "$REAL_USER":"$REAL_USER" "$STATE_DIR"
    fi

    if [ ! -f "$STATE_FILE" ]; then
        run_cmd touch "$STATE_FILE"
        run_cmd chown "$REAL_USER":"$REAL_USER" "$STATE_FILE"
    fi
}

is_step_done() {
    local step="$1"
    grep -qxF "$step" "$STATE_FILE" 2>/dev/null
}

mark_step_done() {
    [ "$DRY_RUN" = true ] && return 0
    local step="$1"
    if ! is_step_done "$step"; then
        echo "$step" >> "$STATE_FILE"
        info "✅ Шаг '$step' успешно завершён и сохранён в state."
    fi
}

run_step() {
    local step_name="$1"
    local step_func="$2"

    # Если указан --from, пропускаем все шаги до него
    if [ "$RESUME_MODE" = true ] && [ -n "$FROM_STEP" ]; then
        if [ "$step_name" != "$FROM_STEP" ]; then
            return 0
        else
            RESUME_MODE=false # Нашли точку старта, дальше выполняем всё
        fi
    fi

    if is_step_done "$step_name"; then
        info "⏭ Шаг '$step_name' уже выполнен ранее. Пропускаю."
        return 0
    fi

    info "▶️ Запуск шага: $step_name"
    if $step_func; then
        mark_step_done "$step_name"
    else
        echo >&2
        echo -e "\e[31m[ERROR]\e[0m Шаг '$step_name' завершился с ошибкой." >&2
        echo -e "\e[33m[ПОДСКАЗКА]\e[0m Исправь проблему и перезапусти с этого места:" >&2
        echo -e "        sudo $0 --from $step_name" >&2
        exit 1
    fi
}

show_status() {
    echo -e "\e[36m=== Статус установки DMS ===\e[0m"
    for step in "${STEPS[@]}"; do
        if is_step_done "$step"; then
            echo -e "  \e[32m[✓]\e[0m $step"
        else
            echo -e "  \e[33m[ ]\e[0m $step"
        fi
    done
    echo -e "\e[36m=========================\e[0m"
    exit 0
}

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
        --from)
            RESUME_MODE=true
            FROM_STEP="$2"
            if [[ ! " ${STEPS[*]} " =~ " ${FROM_STEP} " ]]; then
                error "Неизвестный шаг для --from: $FROM_STEP. Доступные: ${STEPS[*]}"
            fi
            shift 2
            ;;
        --reset)
            RESET_STATE=true
            shift
            ;;
        --status)
            show_status
            ;;
        --list-steps)
            echo "Доступные шаги: ${STEPS[*]}"
            exit 0
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
        echo -e "\e[33m[WARN]\e[0m Использование: $0 [--dry-run] [--from <step>] [--reset] [--status] [--list-steps]" >&2
    fi
}

# =============================================================================
# --- ИНИЦИАЛИЗАЦИЯ ---
# =============================================================================

exec > >(tee -a "$LOG_FILE") 2>&1

[ "$DRY_RUN" = true ] && info "Запущен в режиме предпросмотра (изменения не будут внесены)"

if [ "$(id -u)" -ne 0 ]; then
    error "Этот скрипт нужно запускать с правами root: sudo $0"
fi

setup_temp_sudoers || true

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
# --- ШАГОВЫЕ ФУНКЦИИ ---
# =============================================================================

step_geoblock() {
    info "Применение geoblock-фикса (fedora-cisco-403-mitigation.sh)..."

    MITIGATION_URL="https://raw.githubusercontent.com/supertico/fedora-open264-geoblock-fix/main/fedora-cisco-403-mitigation.sh"

    if [ "$DRY_RUN" = true ]; then
        echo -e "\e[36m[DRY-RUN]\e[0m Скачал бы и запустил: $MITIGATION_URL"
    else
        curl -fsSL "$MITIGATION_URL" -o /tmp/fedora-cisco-403-mitigation.sh
        bash /tmp/fedora-cisco-403-mitigation.sh
        rm -f /tmp/fedora-cisco-403-mitigation.sh
    fi
}

step_flathub() {
    info "Подключение Flathub (remote only)..."
    run_cmd sudo dnf install -y flatpak

    if ! sudo flatpak remotes --columns=name 2>/dev/null | grep -qx "flathub"; then
        info "Добавление Flathub remote (без интерактивного промпта)..."
        run_cmd sudo flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
    else
        info "Flathub уже подключён, пропускаю."
    fi

    info "Установка Gearlever (Flatpak)..."
    run_cmd sudo flatpak install -y flathub it.mijorus.gearlever

    info "Geoblock-фикс и Flathub готовы. Продолжаем установку пакетов..."
}

step_packages() {
    PKGS=(
        dolphin kate ark kcalc plasma-breeze
        adw-gtk3-theme
        ddcutil i2c-tools fish
        xdg-desktop-portal-kde xwayland-satellite alacritty cliphist wlsunset
        qt6-qtwayland qt5-qtwayland kvantum qt6ct qt5ct
        google-roboto-fonts fira-code-fonts
        micro pavucontrol blueman NetworkManager network-manager-applet
        qbittorrent nodejs npm neovim filelight git
        mangohud kitty ripgrep eza wl-clipboard dconf niri
        gnome-keyring imv mpv nvtop kio-extras kio-admin
        gvfs-mtp gvfs-afc libmtp ffmpegthumbs kdegraphics-thumbnailers
        gnome-disk-utility fuse ncdu socat xdg-desktop-portal-wlr gparted
        xdg-terminal-exec obs-studio
        make gcc python3-pip
    )

    info "Обновление системы..."
    run_cmd sudo dnf upgrade -y

    info "Проверка доступности пакетов в репозиториях..."
    run_cmd sudo dnf makecache

    AVAILABLE_PKGS=()
    MISSING_PKGS=()

    for pkg in "${PKGS[@]}"; do
        if dnf repoquery --available --quiet "name:$pkg" &>/dev/null; then
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
            read -rp "Продолжить установку без этих пакетов? [Y/n] " answer || answer="Y"
            if [[ "$answer" =~ ^[Nn] ]]; then
                error "Установка прервана пользователем."
            fi
        fi
    fi

    if [ ${#AVAILABLE_PKGS[@]} -gt 0 ]; then
        info "Установка пакетов из репозиториев..."
        run_cmd sudo dnf install -y --skip-unavailable "${AVAILABLE_PKGS[@]}"
    else
        warn "Нет доступных пакетов для установки из репозиториев."
    fi
}

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

step_gitbuilds() {
    build_keyd
    build_tela
}

step_dms_prep() {
    info "Подготовка зависимостей DMS (COPR + пакеты, чтобы dankinstall не звал sudo)..."
    run_cmd sudo dnf copr enable -y avengemedia/danklinux
    run_cmd sudo dnf copr enable -y avengemedia/dms
    run_cmd sudo dnf install -y golang-bin git gcc make tar unzip
    run_cmd sudo dnf install -y dms dms-greeter quickshell matugen cliphist danksearch dgop dankcalendar-git ghostty
}

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

step_dms_install() {
    install_dms
}

step_copr_external() {
    info "Установка portprotonqt (COPR boria138/portproton)..."
    run_cmd sudo dnf copr enable -y boria138/portproton
    run_cmd sudo dnf install -y portproton

    info "Установка opencode..."
    run_cmd sudo -u "$REAL_USER" bash -c 'curl -fsSL https://opencode.ai/install | bash'

    info "Установка ollama..."
    run_cmd sudo bash -c 'curl -fsSL https://ollama.com/install.sh | sh'

    info "Установка pi..."
    run_cmd sudo -u "$REAL_USER" bash -c 'curl -fsSL https://pi.dev/install.sh | sh'
}

step_pywalfox() {
    info "Установка pywalfox..."
    run_cmd sudo -u "$REAL_USER" python3 -m pip install --user --break-system-packages pywalfox

    PYWALFOX_SRC="$USER_HOME/.cache/wal/dank-pywalfox.json"
    PYWALFOX_DST="$USER_HOME/.cache/wal/colors.json"

    if [ -f "$PYWALFOX_SRC" ]; then
        info "Настройка pywalfox..."
        run_cmd ln -sf "$PYWALFOX_SRC" "$PYWALFOX_DST"
        [ "$DRY_RUN" = false ] && info "Создан линк: dank-pywalfox.json -> colors.json"
    else
        warn "Файл $PYWALFOX_SRC не найден, пропускаю настройку pywalfox."
    fi
}

step_symlink() {
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
}

step_theme_portals_qt() {
    info "Включение тёмной темы..."

    if command -v gsettings &>/dev/null; then
        run_cmd gsettings set org.gnome.desktop.interface color-scheme 'prefer-dark' 2>/dev/null || true
    elif command -v dconf &>/dev/null; then
        run_cmd dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'" 2>/dev/null || true
    else
        warn "Ни gsettings, ни dconf не найдены, пропускаю настройку темы."
    fi

    NIRI_PORTALS="/usr/share/xdg-desktop-portal/niri-portals.conf"

    if [ -f "$NIRI_PORTALS" ]; then
        info "Настройка niri-portals.conf..."

        if [ "$DRY_RUN" = true ]; then
            echo -e "\e[36m[DRY-RUN]\e[0m Проверил бы/добавил бы: FileChooser=kde; ScreenCast=wlr;"
        else
            if sudo grep -q "^org\.freedesktop\.impl\.portal\.FileChooser=" "$NIRI_PORTALS"; then
                sudo sed -i 's|^org\.freedesktop\.impl\.portal\.FileChooser=.*|org.freedesktop.impl.portal.FileChooser=kde;|' "$NIRI_PORTALS"
                info "Заменено: FileChooser=kde;"
            else
                echo "org.freedesktop.impl.portal.FileChooser=kde;" | sudo tee -a "$NIRI_PORTALS" > /dev/null
                info "Добавлено: FileChooser=kde;"
            fi

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

    info "Применение специфичных настроек QT..."

    if command -v kwriteconfig6 &>/dev/null; then
        run_cmd kwriteconfig6 --file kdeglobals --group General --key TerminalApplication "alacritty"
        [ "$DRY_RUN" = false ] && info "Установлен терминал по умолчанию: alacritty"
    else
        warn "kwriteconfig6 не найден, пропускаю настройку терминала."
    fi
}

step_shell() {
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
}

# =============================================================================
# --- ГЛАВНЫЙ ДИСПЕТЧЕР ---
# =============================================================================

init_state

# Проверяем, не установлено ли уже всё
all_done=true
for step in "${STEPS[@]}"; do
    if ! is_step_done "$step"; then
        all_done=false
        break
    fi
done

if [ "$all_done" = true ] && [ "$RESET_STATE" = false ]; then
    info "🎉 Все шаги уже выполнены! Система настроена."
    info "Используй sudo $0 --reset, чтобы выполнить установку заново."
    exit 0
fi

run_step "geoblock" step_geoblock
run_step "flathub" step_flathub
run_step "packages" step_packages
run_step "gitbuilds" step_gitbuilds
run_step "dms_prep" step_dms_prep
run_step "dms_install" step_dms_install
run_step "copr_external" step_copr_external
run_step "pywalfox" step_pywalfox
run_step "symlink" step_symlink
run_step "theme_portals_qt" step_theme_portals_qt
run_step "shell" step_shell

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
echo "  - LM Studio      : https://lmstudio.ai/"

# cleanup() вызовется автоматически через trap
