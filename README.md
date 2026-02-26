Для niri
<details>
  <summary>Скриншоты</summary>
 
![](Screenshots/1.png)
![](Screenshots/2.png)
![](Screenshots/3.png)

 </details>
## Автоустановка только для Arch
Запустить скрипт
```bash
sh arch-installv2.sh
 ```
## Установка в ручную
```bash
git clone https://github.com/RobberBobFl/DotFiles.git
```
Из home/config в ~/.config
```bash
cp -r ~/DotFiles/home/config/* ~/.config/
```
Из usr/share в /usr/share/
```bash
sudo cp -r ~/DotFiles/usr/share/* /usr/share/
```
Из ~/DotFiles/wallpaper → в ~/Pictures/wallpaper/
```bash
mkdir -p ~/Pictures/wallpaper
cp ~/DotFiles/wallpaper/* ~/Pictures/wallpaper/
```

Темы, курсор, иконки поставить в nwg-look и в kvantum для qt

Приминить тёмную тему для libadwaita
```bash
dconf write /org/gnome/desktop/interface/color-scheme '"prefer-dark"'
```

## Обязательный софт
Arch
```bash
sudo pacman -S xdg-desktop-portal-gtk xdg-desktop-portal-gnome gnome-keyring xdg-terminal-exec xwayland-satellite
```
```bash
yay -S mate-polkit
```
Alt
```bash
sudo apt-get install xdg-desktop-portal-gtk xdg-desktop-portal-gnome gnome-keyring xdg-terminal-exec mate-polkit xwayland-satellite
```
- xdg-desktop-portal-gtk
- xdg-desktop-portal-gnome
- gnome-keyring
- xdg-desktop-portal-wlr(Может пригодится)
- xdg-terminal-exec(Если не будет открываться терминал)
- mate-polkit
- mate-polkit
- xwayland-satellite

## Доп. софт для niri
Arch
```bash
sudo pacman -S waybar wofi mako gtklock gtklock-powerbar-module gtklock-playerctl-module alacritty cliphist wlsunset qt5ct qt6ct qt6-wayland qt5-wayland ttf-roboto ttf-fira-code ttf-firacode-nerd
```
```bash
yay -S awww wlogout
```
Alt
```bash
sudo apt-get install waybar wofi mako gtklock gtklock-powerbar-module gtklock-playerctl-module wlogout alacritty cliphist wlsunset awww qt5ct qt6ct qt6-wayland qt5-wayland fonts-ttf-roboto fonts-ttf-fira-code
 fonts-ttf-fira-code-nerd
```
- Waybar 
- Wofi
- Mako 
- gtklock 
- Wlogout 
- Alacritty 
- cliphist 
- Wlsunset
- qt5ct
- qt6ct
- qt5-wayland
- qt6-wayland 
- swww/awww/swaybg

## Нужный мне софт
Arch
```bash
sudo pacman -s micro gsimplecal pavucontrol blueman networkmanager network-manager-applet thunar nwg-look timeshift kvantum obsidian qbittorrent nodejs npm neovim geany yazi git mangohud kitty ripgrep eza
```
```bash
yay -S v2rayn portproton yandex-browser geany-themes 
```
Alt
```bash
sudo apt-get install micro gnome-calendar pavucontrol blueman NetworkManager NetworkManager-applet-gtk thunar nwg-look timeshift Kvantum obsidian qbittorrent portproton nodejs npm neovim geany geany-themes yazi git mangohud kitty ripgrep ripgrep eza
```
```bash
epm play yandex-browser v2rayn
```
