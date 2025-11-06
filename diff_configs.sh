#!/bin/bash

show_help() {
    cat << EOF
Usage: $0 [COMMIT_HASH]

Compare kernel configs between current HEAD and specified commit.

Arguments:
  COMMIT_HASH    Hash of commit to compare with (default: HEAD~1)

Examples:
  $0                  # Compare with previous commit (HEAD~1)
  $0 abc1234          # Compare with commit abc1234
  $0 HEAD~5           # Compare with 5 commits back
  $0 origin/main      # Compare with origin/main branch

Description:
  This script generates kernel configs for both debug and generic variants
  for current HEAD and specified commit, then shows differences between them.

Environment:
  Requires debian/rules with config-generic and config-debug targets
  Requires quilt for patch management
EOF
    exit 0
}

# Показать help если запрошен
if [[ "$1" == "-h" || "$1" == "--help" ]]; then
    show_help
fi

COMMIT="${1:-HEAD~1}"
TMP_DIR=$(mktemp -d)

cleanup() {
    rm -rf "$TMP_DIR" 2>/dev/null || true
    git checkout "$original_branch" >/dev/null 2>&1 || true
    debian/rules quilt-pop >/dev/null 2>&1 || true
    exit 1
}
trap cleanup EXIT INT TERM

if ! git rev-parse --verify "$COMMIT" >/dev/null 2>&1; then
    echo "Ошибка: коммит $COMMIT не существует"
    exit 1
fi

echo "Используем коммит: $COMMIT ($(git log -1 --format=%s "$COMMIT"))"

original_branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD)

generate_config() {
    local config_type=$1
    local output_file=$2
    
    debian/rules clean >/dev/null 2>&1
    yes "" | debian/rules "config-$config_type" >/dev/null 2>&1
    cp debian/build/.config "$output_file"
    debian/rules clean >/dev/null 2>&1
}

debian/rules quilt-push >/dev/null 2>&1
echo "NEW GENERIC"
generate_config generic "$TMP_DIR/new_generic.config"
echo "NEW DEBUG" 
generate_config debug "$TMP_DIR/new_debug.config"
debian/rules quilt-pop >/dev/null 2>&1

git checkout "$COMMIT" >/dev/null 2>&1

debian/rules quilt-push >/dev/null 2>&1
echo "OLD GENERIC"
generate_config generic "$TMP_DIR/old_generic.config"
echo "OLD DEBUG"
generate_config debug "$TMP_DIR/old_debug.config"
debian/rules quilt-pop >/dev/null 2>&1

git checkout "$original_branch" >/dev/null 2>&1

echo "========== old debug vs new debug =========="
diff "$TMP_DIR/old_debug.config" "$TMP_DIR/new_debug.config" --color || true

echo "========== old generic vs new generic =========="  
diff "$TMP_DIR/old_generic.config" "$TMP_DIR/new_generic.config" --color || true
