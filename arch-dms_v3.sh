#!/bin/bash
set -euo pipefail

# --- ПЕРЕМЕННЫЕ ---
DOT_DIR="$HOME/DotFiles/dms-dots"

# --- ФУНКЦИИ ---
info() { echo -e "\e[32m[INFO]\e[0m $1"; }
warn() { echo -e "\e[33m[WARN]\e[0m $1"; }

# 0. Выбор набора пакетов
echo "Выберите пакет программ для установки:"
echo "1) GTK (Gnome-based)"
echo "2) QT (KDE-based)"
read -p "Введите цифру (1 или 2): " choice

if [ "$choice" == "1" ]; then
    info "Выбраны GTK пакеты."
    PKGS_PACMAN=(
        breeze adw-gtk-theme capitaine-cursors tela-circle-icon-theme-all dms-shell 
        ddcutil i2c-tools dgop matugen fish gnome-calculator xdg-desktop-portal-gtk
        gnome-keyring xwayland-satellite alacritty cliphist wlsunset qt6-wayland 
        qt5-wayland kvantum kvantum-qt5 baobab ttf-roboto ttf-fira-code 
        ttf-firacode-nerd micro pavucontrol blueman networkmanager 
        network-manager-applet thunar nwg-look obsidian qbittorrent nodejs npm 
        neovim geany yazi git mangohud kitty ripgrep eza wl-clipboard dconf niri 
        keyd celluloid imv xarchiver xfce4-settings gvfs-mtp gvfs-afc libmtp 
        tumbler nvtop gnome-disk-utility heroic-games-launcher-bin
    )
    PKGS_AUR=(
        greetd-dms-greeter-git quickshell-git v2rayn portproton yandex-browser 
        geany-themes xdg-terminal-exec qt6ct-kde qt5ct-kde dsearch-bin gowall
    )
elif [ "$choice" == "2" ]; then
    info "Выбраны QT пакеты."
    PKGS_PACMAN=(
        dolphin kate ark kcalc breeze adw-gtk-theme capitaine-cursors 
        tela-circle-icon-theme-all dms-shell ddcutil i2c-tools dgop matugen 
        fish xdg-desktop-portal-kde xwayland-satellite alacritty cliphist 
        wlsunset qt6-wayland qt5-wayland kvantum kvantum-qt5 ttf-roboto 
        ttf-fira-code ttf-firacode-nerd micro pavucontrol blueman networkmanager 
        network-manager-applet nwg-look obsidian qbittorrent nodejs npm neovim 
        filelight yazi git mangohud kitty ripgrep eza wl-clipboard dconf niri 
        keyd gnome-keyring imv mpv nvtop kio-extras kio-admin gvfs-mtp 
        gvfs-afc libmtp ffmpegthumbs kdegraphics-thumbnailers gnome-disk-utility 
        heroic-games-launcher-bin
    )
    PKGS_AUR=(
        greetd-dms-greeter-git quickshell-git v2rayn portproton yandex-browser 
        xdg-terminal-exec qt6ct-kde qt5ct-kde dsearch-bin gowall
    )
else
    warn "Ошибка: Нужно выбрать 1 или 2."
    exit 1
fi

# 1. Системное обновление
info "Обновляю систему..."
sudo pacman -Syu --needed --noconfirm "${PKGS_PACMAN[@]}"

# 2. Проверка AUR хелпера
if command -v yay &> /dev/null; then
    AUR_HELPER="yay"
elif command -v paru &> /dev/null; then
    AUR_HELPER="paru"
else
    info "Устанавливаю yay..."
    sudo pacman -S --needed --noconfirm git base-devel
    git clone https://aur.archlinux.org/yay.git /tmp/yay
    (cd /tmp/yay && makepkg -si --noconfirm)
    AUR_HELPER="yay"
fi

# 3. Установка AUR пакетов
info "Устанавливаю AUR пакеты..."
$AUR_HELPER -S --needed --noconfirm "${PKGS_AUR[@]}"

# 4. Группы и права
info "Настраиваю права доступа..."
sudo usermod -aG i2c $USER
sudo usermod -aG greeter $USER

# 5. Keyd
info "Настройка keyd..."
if [ -f "$HOME/DotFiles/default.conf" ]; then
    sudo mkdir -p /etc/keyd
    sudo cp "$HOME/DotFiles/default.conf" /etc/keyd/default.conf
    sudo systemctl enable --now keyd
else
    warn "Конфиг keyd не найден."
fi

# 6. Умная линковка конфигов (обрабатывает и симлинки, и папки)
info "Линкую ~/.config из $DOT_DIR..."
mkdir -p "$HOME/.config"

find "$DOT_DIR" -mindepth 1 -maxdepth 1 | while read -r item; do
    base=$(basename "$item")
    target="$HOME/.config/$base"
    
    # Резолвим реальный путь (для симлинков уйдет в home/config, для папок останется в dms-dots)
    real_source=$(readlink -f "$item")

    if [ -L "$target" ] && [ "$(readlink -f "$target")" == "$real_source" ]; then
        info "Пропускаю (уже линковано): $base"
        continue
    fi

    if [ -e "$target" ] || [ -L "$target" ]; then
        mv "$target" "${target}.backup.$(date +%F_%H-%M)"
        info "Бэкап: $base"
    fi

    ln -sfn "$real_source" "$target"
    info "Линковка: $base -> $real_source"
done

# 7. Обои
info "Настройка обоев..."
mkdir -p "$HOME/Pictures"
if [ -d "$HOME/DotFiles/wallpaper" ]; then
    ln -sfn "$HOME/DotFiles/wallpaper" "$HOME/Pictures/wallpaper"
fi

# 8. Тёмная тема
dconf write /org/gnome/desktop/interface/color-scheme "'prefer-dark'" 2>/dev/null || true

# 9. Смена Shell
if [[ "$SHELL" != */fish ]]; then
    chsh -s "$(which fish)"
fi

info "Установка завершена! Перезагрузитесь."
