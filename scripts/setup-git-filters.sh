#!/bin/bash
# Включает git-фильтр @@HOME@@ в этой репе и переразворачивает рабочую копию под
# текущего пользователя. Идемпотентно, можно запускать из любого каталога и
# сколько угодно раз: ./scripts/setup-git-filters.sh
#
# Список файлов должен совпадать с .gitattributes.
set -euo pipefail

root="$(git -C "$(dirname "$(readlink -f "$0")")" rev-parse --show-toplevel)"

FILTERED=(
    dms-dots/dms/settings.json
    dms-dots/qt5ct/qt5ct.conf
    dms-dots/qt6ct/qt6ct.conf
    dms-dots/gtk-3.0/bookmarks
    home/config/gtk-3.0/bookmarks
    home/config/fish/config.fish
)

git -C "$root" config filter.home.clean  'perl ./scripts/git-home-filter clean'
git -C "$root" config filter.home.smudge 'perl ./scripts/git-home-filter smudge'
# без required git молча пропускал бы файл как есть при падении фильтра — путь уехал бы в репу
git -C "$root" config filter.home.required true

present=()
for f in "${FILTERED[@]}"; do
    [ -f "$root/$f" ] && present+=("$f")
done

# Переразворачиваем ТОЛЬКО файлы, где в рабочей копии остался канон @@HOME@@ (приезжает из
# свежего clone/pull, когда фильтр ещё не был настроен). Безусловный checkout --force стёр бы
# незакоммиченные правки, а для settings.json это штатная ситуация: DMS пишет в него постоянно.
stale=()
for f in "${present[@]}"; do
    grep -q '@@HOME@@' "$root/$f" 2>/dev/null && stale+=("$f")
done

if [ ${#stale[@]} -gt 0 ]; then
    echo "setup-git-filters: разворачиваю канон @@HOME@@ в: ${stale[*]}"
    git -C "$root" checkout --force -- "${stale[@]}"
fi

# Контроль «не забыли развернуть»: канон в рабочей копии означает, что файлы читались
# до настройки фильтра (например, свежий клон), и приложения получат @@HOME@@ вместо пути.
leftover="$(grep -l '@@HOME@@' "${present[@]/#/"$root"/}" 2>/dev/null || true)"
if [ -n "$leftover" ]; then
    {
        echo "setup-git-filters: в рабочей копии остался канон @@HOME@@ — фильтр не применился:"
        echo "$leftover"
    } >&2
    exit 1
fi

echo "setup-git-filters: фильтр настроен (HOME=$HOME, репа=$root, файлов: ${#present[@]})"
