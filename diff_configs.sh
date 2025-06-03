#/bin/bash

# Устанавливаем коммит по умолчанию
COMMIT="HEAD~1"

# Парсим параметры
if [ $# -gt 0 ]; then
    COMMIT="$1"
    echo "Используем указанный коммит: $COMMIT"
else
    echo "Коммит не указан, используем по умолчанию: $COMMIT"
fi

original_branch=$(git rev-parse --abbrev-ref HEAD)
debian/rules quilt-push >/dev/null 2>&1

echo "NEW GENERIC"
debian/rules clean >/dev/null 2>&1
yes "" | debian/rules config-generic >/dev/null 2>&1
cp debian/build/.config ../new_generic.config

echo "NEW DEBUG"
debian/rules clean >/dev/null 2>&1
yes "" | debian/rules config-debug >/dev/null 2>&1
cp debian/build/.config ../new_debug.config

git checkout "$COMMIT" >/dev/null 2>&1

echo "OLD GENERIC"
debian/rules clean >/dev/null 2>&1
yes "" | debian/rules config-generic >/dev/null 2>&1
cp debian/build/.config ../old_generic.config

echo "OLD DEBUG"
debian/rules clean >/dev/null 2>&1
yes "" | debian/rules config-debug >/dev/null 2>&1
cp debian/build/.config ../old_debug.config

debian/rules quilt-pop >/dev/null 2>&1
git checkout "$original_branch"

echo "========== old debug vs new debug =========="
diff ../old_debug.config ../new_debug.config --color

echo "========== old generic vs new generic =========="
diff ../old_generic.config ../new_generic.config --color

rm ../new_debug.config
rm ../old_debug.config
rm ../new_generic.config
rm ../old_generic.config
