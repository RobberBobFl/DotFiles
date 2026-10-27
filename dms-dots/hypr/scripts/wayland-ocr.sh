#!/bin/bash

wayfreeze & PID=$!

# Микро-задержка для правильного порядка слоев и отпускания хоткея
sleep 0.1

GEOMETRY=$(slurp)
kill $PID

[ -z "$GEOMETRY" ] && exit

TEXT=$(grim -g "$GEOMETRY" - | tesseract stdin stdout -l rus+eng)

if [ -n "$(echo "$TEXT" | tr -d '[:space:]')" ]; then
    echo "$TEXT" | wl-copy
    notify-send -a "OCR" "Текст скопирован:" "$TEXT"
else
    notify-send -a "OCR" "Ошибка" "Не удалось распознать текст"
fi
