#!/bin/sh
WALLPAPER_DIR="$HOME/Изображения/wallpaper"
[ ! -d "$WALLPAPER_DIR" ] && exit 1

random_wall() {
    find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.webp" \) | shuf -n1
}

# Первый запуск
swww img "$(random_wall)" --transition-type random --transition-duration 3

# Цикл
while true; do
    sleep 7200
    swww img "$(random_wall)" --transition-type random --transition-duration 3
done
