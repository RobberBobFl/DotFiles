#!/bin/sh

WALLPAPER_DIR="$HOME/Pictures/wallpaper/"

# Проверка директории
[ ! -d "$WALLPAPER_DIR" ] && notify-send "Обои" "Папка $WALLPAPER_DIR не найдена!" && exit 1

# Функция выбора рандомной обоины
random_wall() {
    find "$WALLPAPER_DIR" -type f \( -iname "*.jpg" -o -iname "*.png" -o -iname "*.webp" \) | shuf -n1
}

# Проверяем, запущен ли демон
if ! pgrep -x "awww-daemon" > /dev/null; then
    awww-daemon &
    sleep 1
fi

# Меняем обои с переходом
awww img "$(random_wall)" --transition-type random --transition-duration 3

# Опционально: уведомление, какая обоя встала (полезно для дебага)
# notify-send "Обои" "Сменены на новую!" 
