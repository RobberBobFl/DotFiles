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
    # checkout (даже --force) тут не годится: после pull без фильтра рабочая копия побайтово
    # равна индексу, git считает файл актуальным и smudge не запускает. Разворачиваем сами —
    # канон из индекса через тот же фильтр, атомарно через temp+mv.
    for f in "${stale[@]}"; do
        tmp="$root/$f.tmp.$$"
        git -C "$root" show ":$f" | perl "$root/scripts/git-home-filter" smudge > "$tmp"
        mv -f "$tmp" "$root/$f"
    done
fi

# git status считает файл грязным по стат-данным: рабочая копия длиннее индекса, хотя после
# clean содержимое совпадает побайтово (git diff при этом пустой, --really-refresh не помогает).
# Пересчитываем кэш staging'ом по всему списку и следим, чтобы он оказался no-op: если blob
# изменился, в файле настоящие правки — снимаем staging и предупреждаем.
for f in "${present[@]}"; do
    before="$(git -C "$root" rev-parse ":$f")"
    git -C "$root" add -- "$f"
    after="$(git -C "$root" rev-parse ":$f")"
    if [ "$before" != "$after" ]; then
        git -C "$root" reset -q -- "$f"
        echo "setup-git-filters: в $f есть реальные изменения — оставил как есть" >&2
    fi
done

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
