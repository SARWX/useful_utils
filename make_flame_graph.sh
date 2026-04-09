#!/bin/bash

# ============================================================================
# FlameGraph Generator Script
# ============================================================================

set -e

# Настройки по умолчанию
DURATION=30
FREQUENCY=99
OUTPUT="flame.svg"
WIDTH=2560
COMMAND=""
FLAMEGRAPH_DIR="./FlameGraph"
KEEP_TEMP=false
VERBOSE=false

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# ============================================================================
# Функции
# ============================================================================

show_help() {
    cat << EOF
Использование: $0 [ОПЦИИ]

Генератор FlameGraph для профилирования производительности.

ОПЦИИ:
    -d, --duration SEC    Длительность записи perf (по умолчанию: 30 сек)
    -f, --freq HZ         Частота сэмплирования perf (по умолчанию: 99 Гц)
    -o, --output FILE     Имя выходного SVG файла (по умолчанию: flame.svg)
    -w, --width PX        Ширина SVG в пикселях (по умолчанию: 2560)
    -c, --command CMD     Команда для профилирования вместо sleep
    -p, --pid PID         Профилировать конкретный PID вместо всей системы
    -t, --tid TID         Профилировать конкретный TID (поток)
    --flamegraph-dir DIR  Путь к FlameGraph (по умолчанию: ./FlameGraph)
    --keep-temp           Сохранить временные файлы (out.perf, out.folded)
    -v, --verbose         Подробный вывод
    -h, --help            Показать эту справку

ПРИМЕРЫ:
    # Базовое использование (профилирование всей системы 30 сек)
    $0

    # Профилирование 60 секунд с частотой 199 Гц
    $0 -d 60 -f 199

    # Профилирование конкретной команды
    $0 -c "stress-ng --cpu 4 --timeout 10s"

    # Профилирование процесса по PID
    $0 -p 12345 -d 20

    # Профилирование во время сетевого теста
    $0 -d 30 -o network_test.svg -c "iperf3 -c localhost -t 25"

    # С сохранением временных файлов для анализа
    $0 --keep-temp -v -o debug.svg

EOF
}

print_error() {
    echo -e "${RED}ОШИБКА:${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}ПРЕДУПРЕЖДЕНИЕ:${NC} $1" >&2
}

print_info() {
    echo -e "${GREEN}INFO:${NC} $1"
}

print_debug() {
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "DEBUG: $1"
    fi
}

check_dependencies() {
    local missing=()
    
    if ! command -v perf &> /dev/null; then
        missing+=("perf")
    fi
    
    if [[ ! -f "$FLAMEGRAPH_DIR/stackcollapse-perf.pl" ]]; then
        missing+=("FlameGraph/stackcollapse-perf.pl (not found in $FLAMEGRAPH_DIR)")
    fi
    
    if [[ ! -f "$FLAMEGRAPH_DIR/flamegraph.pl" ]]; then
        missing+=("FlameGraph/flamegraph.pl (not found in $FLAMEGRAPH_DIR)")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        print_error "Отсутствуют зависимости:"
        for dep in "${missing[@]}"; do
            echo "  - $dep"
        done
        exit 1
    fi
}

cleanup() {
    if [[ "$KEEP_TEMP" == "false" ]]; then
        print_debug "Удаление временных файлов..."
        rm -f out.perf out.folded
    else
        print_info "Временные файлы сохранены: out.perf, out.folded"
    fi
}

# ============================================================================
# Парсинг аргументов
# ============================================================================

PERF_TARGET="-a"  # По умолчанию вся система
PERF_PID=""
PERF_TID=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--duration)
            DURATION="$2"
            shift 2
            ;;
        -f|--freq)
            FREQUENCY="$2"
            shift 2
            ;;
        -o|--output)
            OUTPUT="$2"
            shift 2
            ;;
        -w|--width)
            WIDTH="$2"
            shift 2
            ;;
        -c|--command)
            COMMAND="$2"
            shift 2
            ;;
        -p|--pid)
            PERF_PID="$2"
            PERF_TARGET="-p $2"
            shift 2
            ;;
        -t|--tid)
            PERF_TID="$2"
            PERF_TARGET="-t $2"
            shift 2
            ;;
        --flamegraph-dir)
            FLAMEGRAPH_DIR="$2"
            shift 2
            ;;
        --keep-temp)
            KEEP_TEMP=true
            shift
            ;;
        -v|--verbose)
            VERBOSE=true
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            print_error "Неизвестная опция: $1"
            show_help
            exit 1
            ;;
    esac
done

# ============================================================================
# Проверки
# ============================================================================

# Проверка прав суперпользователя
if [[ $EUID -ne 0 ]]; then
    print_warning "Скрипт запущен без sudo. Некоторые функции perf могут быть недоступны."
    print_warning "Рекомендуется: sudo $0"
    read -p "Продолжить? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Проверка зависимостей
check_dependencies

# Проверка конфликтующих опций
if [[ -n "$COMMAND" ]] && [[ -n "$PERF_PID$PERF_TID" ]]; then
    print_error "Нельзя одновременно указать --command и --pid/--tid"
    exit 1
fi

# ============================================================================
# Вывод конфигурации
# ============================================================================

print_info "=========================================="
print_info "Конфигурация FlameGraph:"
print_info "=========================================="
print_info "Длительность:      $DURATION сек"
print_info "Частота:           $FREQUENCY Гц"
print_info "Выходной файл:     $OUTPUT"
print_info "Ширина SVG:        $WIDTH px"
print_info "Цель perf:         $PERF_TARGET"
[[ -n "$COMMAND" ]] && print_info "Команда:           $COMMAND"
print_info "Директория FG:     $FLAMEGRAPH_DIR"
print_info "Сохранять temp:    $KEEP_TEMP"
print_info "=========================================="

# ============================================================================
# Сбор данных
# ============================================================================

print_info "Этап 1/4: Сбор данных perf..."

PERF_CMD="perf record -F $FREQUENCY -g $PERF_TARGET"
PERF_OUTPUT_FILE="out.perf"

if [[ -n "$COMMAND" ]]; then
    print_info "Выполнение команды: $COMMAND"
    eval "sudo $PERF_CMD -- $COMMAND"
else
    print_info "Запись в течение $DURATION секунд..."
    sudo $PERF_CMD -- sleep $DURATION
fi

if [[ ! -f perf.data ]]; then
    print_error "perf.data не создан. Проверьте права доступа."
    exit 1
fi

print_info "Проверка собранных данных:"
sudo perf report -n --stdio 2>/dev/null | head -20 || {
    print_warning "Не удалось прочитать perf.data"
}

# ============================================================================
# Генерация скрипта
# ============================================================================

print_info "Этап 2/4: Генерация perf script..."

sudo perf script -F +pid > "$PERF_OUTPUT_FILE" 2>/dev/null || {
    print_error "Ошибка при выполнении 'perf script'"
    exit 1
}

if [[ ! -s "$PERF_OUTPUT_FILE" ]]; then
    print_error "Файл $PERF_OUTPUT_FILE пуст. Возможно, не было событий."
    exit 1
fi

print_info "Размер $PERF_OUTPUT_FILE: $(wc -l < "$PERF_OUTPUT_FILE") строк"

# ============================================================================
# Конвертация
# ============================================================================

print_info "Этап 3/4: Конвертация в folded формат..."

FOLDED_FILE="out.folded"
"$FLAMEGRAPH_DIR/stackcollapse-perf.pl" "$PERF_OUTPUT_FILE" > "$FOLDED_FILE"

if [[ ! -s "$FOLDED_FILE" ]]; then
    print_error "Файл $FOLDED_FILE пуст. Ошибка конвертации."
    exit 1
fi

print_info "Размер $FOLDED_FILE: $(wc -l < "$FOLDED_FILE") строк"

if [[ "$VERBOSE" == "true" ]]; then
    print_debug "Пример folded данных:"
    head -5 "$FOLDED_FILE"
fi

# ============================================================================
# Генерация SVG
# ============================================================================

print_info "Этап 4/4: Генерация FlameGraph..."

"$FLAMEGRAPH_DIR/flamegraph.pl" --width "$WIDTH" \
    --title "FlameGraph: ${COMMAND:-system profile ${DURATION}s @ ${FREQUENCY}Hz}" \
    "$FOLDED_FILE" > "$OUTPUT"

if [[ ! -s "$OUTPUT" ]]; then
    print_error "Не удалось создать $OUTPUT"
    exit 1
fi

# ============================================================================
# Очистка
# ============================================================================

# Удаляем perf.data в любом случае
sudo rm -f perf.data

# Очистка временных файлов
cleanup

# ============================================================================
# Результат
# ============================================================================

print_info "=========================================="
print_info "✓ FlameGraph успешно создан!"
print_info "=========================================="
print_info "Файл:       $OUTPUT"
print_info "Размер:     $(ls -lh "$OUTPUT" | awk '{print $5}')"
print_info ""
print_info "Открыть в браузере:"
print_info "  firefox $OUTPUT"
print_info "  google-chrome $OUTPUT"
print_info "=========================================="

exit 0
