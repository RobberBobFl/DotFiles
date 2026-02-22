#!/bin/bash
set -euo pipefail

# --- ПЕРЕМЕННЫЕ ---
DOT_DIR="$HOME/DotFiles"

# Официальные пакеты
PKGS_PACMAN=(
    fish xdg-desktop-portal-gtk xdg-desktop-portal-gnome 
    gnome-keyring xwayland-satellite waybar wofi mako gtklock
    gtklock-powerbar-module gtklock-playerctl-module alacritty cliphist
    wlsunset qt5ct qt6ct qt6-wayland qt5-wayland kvantum kvantum-qt5
    ttf-roboto ttf-fira-code ttf-firacode-nerd micro gnome-calendar pavucontrol
    blueman networkmanager network-manager-applet thunar nwg-look timeshift
    obsidian qbittorrent nodejs npm neovim geany yazi git mangohud kitty
    ripgrep eza  wl-clipboard dconf niri mate-polkit 
)

# AUR пакеты
PKGS_AUR=(
     awww wlogout v2rayn portproton yandex-browser geany-themes xdg-terminal-exec
)

# --- ФУНКЦИИ ---
info() { echo -e "\e[32m[INFO]\e[0m $1"; }
warn() { echo -e "\e[33m[WARN]\e[0m $1"; }

# Проверка папки дотфайлов
if [ ! -d "$DOT_DIR" ]; then
    warn "Папка $DOT_DIR не найдена! Сначала склонируй репозиторий."
    exit 1
fi

# 1. Обновление и установка из Pacman
info "Обновляю систему и ставлю официальные пакеты..."
sudo pacman -Syu --needed --noconfirm "${PKGS_PACMAN[@]}"

# 2. AUR helper
if command -v yay &> /dev/null; then
    AUR_HELPER="yay"
elif command -v paru &> /dev/null; then
    AUR_HELPER="paru"
else
    info "AUR helper не найден. Ставлю yay..."
    sudo pacman -S --needed --noconfirm git base-devel
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
    AUR_HELPER="yay"
fi

# 3. Установка AUR
info "Устанавливаю AUR-пакеты..."
$AUR_HELPER -S --needed --noconfirm "${PKGS_AUR[@]}"

# 4. Симлинки ~/.config (теперь и папки, и файлы)
info "Создаю симлинки для ~/.config..."
mkdir -p "$HOME/.config"

find "$DOT_DIR/home/config" -mindepth 1 -maxdepth 1 | while read -r item; do
    base=$(basename "$item")
    target="$HOME/.config/$base"

    # --- ВОТ ЭТА ПРОВЕРКА ---
    # Если это уже симлинк и он указывает ровно на наш файл в DotFiles — просто скипаем
    if [ -L "$target" ] && [ "$(readlink -f "$target")" == "$(readlink -f "$item")" ]; then
        info "Уже настроено (пропускаю): ~/.config/$base"
        continue
    fi
    # ------------------------

    # Если там что-то есть (файл или папка), делаем бэкап перед линковкой
    if [ -e "$target" ] || [ -L "$target" ]; then
        mv "$target" "${target}.backup.$(date +%F_%H-%M)"
        info "Забэкапил старый: ~/.config/$base"
    fi

    ln -sfn "$item" "$target"
    info "Линканул: ~/.config/$base"
done

# 5. Темы и иконки
info "Линкуем темы и иконки..."
mkdir -p "$HOME/.local/share/themes" "$HOME/.local/share/icons"

if [ -d "$DOT_DIR/usr/share/themes" ]; then
    for theme in "$DOT_DIR/usr/share/themes"/*; do
        [ -e "$theme" ] || continue
        ln -sfn "$theme" "$HOME/.local/share/themes/$(basename "$theme")"
        info "Theme: $(basename "$theme")"
    done
fi

if [ -d "$DOT_DIR/usr/share/icons" ]; then
    for icon in "$DOT_DIR/usr/share/icons"/*; do
        [ -e "$icon" ] || continue
        ln -sfn "$icon" "$HOME/.local/share/icons/$(basename "$icon")"
        info "Icon: $(basename "$icon")"
    done
fi
gtk-update-icon-cache -f -t -q ~/.local/share/icons/* 2>/dev/null || true

# 6. Обои
info "Настраиваю обои..."
mkdir -p "$HOME/Pictures"
if [ -d "$DOT_DIR/wallpaper" ]; then
    ln -sfn "$DOT_DIR/wallpaper" "$HOME/Pictures/wallpaper"
    info "Обои прилинкованы в ~/Pictures/wallpaper"
else
    warn "Папка wallpaper не найдена"
fi

# 7. Тёмная тема
info "Включаю тёмный режим..."
dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'" 2>/dev/null || true

# 8. Смена оболочки
if [[ "$SHELL" != */fish ]]; then
    if command -v fish >/dev/null; then
        info "Меняю оболочку на fish..."
        chsh -s "$(which fish)"
    else
        warn "fish не найден"
    fi
else
    info "fish уже основная оболочка"
fi

# 9. Финал
info "Всё готово! Перелогинься (или перезагрузись). Рекомендую запустить nwg-look для финальной настройки тем."
