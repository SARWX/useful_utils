#!/bin/bash

# Цвета
FUNC_COLOR='\033[1;34m'    # Синий для функций
FILE_COLOR='\033[0;37m'    # Серый для файлов
NC='\033[0m'               # No Color

# Функция для рекурсивного поиска вызовов
find_callers() {
    local func=$1
    local current_depth=$2
    local max_depth=$3
    local is_last=$4       # Флаг последнего элемента на уровне
    local file_info=$5     # Информация о файле
    local parent_prefix=$6 # Префикс от родителя

    # Формируем префикс для визуализации дерева
    local tree_prefix="$parent_prefix"
    if [[ $current_depth -gt 0 ]]; then
        if [[ $is_last -eq 1 ]]; then
            tree_prefix+="└── "
        else
            tree_prefix+="├── "
        fi
    fi
    
    # Выводим функцию и файл в одной строке
    echo -e "${tree_prefix}${FUNC_COLOR}$func${NC} ${FILE_COLOR}($file_info)${NC}"
    
    # Проверяем глубину рекурсии
    if [[ $current_depth -ge $max_depth ]]; then
        return
    fi
    
    # Получаем все вызовы для текущей функции
    local calls=()
    while IFS= read -r line; do
        calls+=("$line")
    done < <(cscope -d -L3 "$func" 2>/dev/null)
    
    local total_calls=${#calls[@]}
    local call_index=0
    
    # Обрабатываем каждый вызов
    for call in "${calls[@]}"; do
        read -r file caller line context <<< "$call"
        
        if [[ ! -z "$caller" && "$caller" != "$func" ]]; then
            ((call_index++))
            
            # Определяем файл для дочерней функции
            local child_file_info=$(basename "$file"):$line
            
            # Определяем префикс для дочерних элементов
            local child_prefix="$parent_prefix"
            if [[ $current_depth -gt 0 ]]; then
                if [[ $is_last -eq 1 ]]; then
                    child_prefix+="    "
                else
                    child_prefix+="│   "
                fi
            fi
            
            # Рекурсивный вызов с флагом последнего элемента
            local last_flag=0
            if [[ $call_index -eq $total_calls ]]; then
                last_flag=1
            fi
            
            find_callers "$caller" $((current_depth + 1)) $max_depth $last_flag "$child_file_info" "$child_prefix"
        fi
    done
}

# Основная функция
analyze_call_tree() {
    local target_func=$1
    local tree_depth=${2:-5}
    
    if [[ -z "$target_func" ]]; then
        echo "Usage: $0 <function_name> [depth]"
        echo "Example: $0 __xfs_free_extent 5"
        exit 1
    fi
    
    echo "=== Call tree for: $target_func (max depth: $tree_depth) ==="
    
    # Получаем информацию о первом вызове для корневой функции
    local first_call=$(cscope -d -L3 "$target_func" 2>/dev/null | head -1)
    if [[ ! -z "$first_call" ]]; then
        read -r file caller line context <<< "$first_call"
        local file_info=$(basename "$file"):$line
    else
        local file_info="unknown:0"
    fi
    
    find_callers "$target_func" 0 $tree_depth 1 "$file_info" ""
}

# Проверяем наличие cscope
if ! command -v cscope &> /dev/null; then
    echo "Error: cscope is not installed"
    echo "Install with: sudo apt install cscope"
    exit 1
fi

# Проверяем наличие базы данных cscope
if [[ ! -f "cscope.out" ]]; then
    echo "Generating cscope database..."
    cscope -R -b
fi

# Запускаем анализ
analyze_call_tree "$1" "$2"
