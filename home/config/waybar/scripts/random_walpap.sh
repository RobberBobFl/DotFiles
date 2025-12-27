#!/bin/sh

WALLPAPER_DIR="$HOME/Pictures/wallpaper/"
[ ! -d "$WALLPAPER_DIR" ] && exit 1

random_wall() {
    find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.webp" \) | shuf -n1
}

# Запускаем демон, если он не запущен
if ! pgrep -x "awww-daemon" > /dev/null; then
    awww-daemon &
    sleep 1  # Даём ему время стартануть
fi

# Первый запуск
awww img "$(random_wall)" --transition-type random --transition-duration 3

# Цикл
while true; do
    sleep 7200
    awww img "$(random_wall)" --transition-type random --transition-duration 3
done
