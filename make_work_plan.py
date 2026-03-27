#!/bin/python3

import os
from datetime import datetime
import subprocess

# Конфигурация
BASE_DIR = "/home/tnovikov/Obsidian/common/планерка/"  # Укажите вашу базовую директорию
MONTHS_RU = {
    1: "январь",
    2: "февраль",
    3: "март",
    4: "апрель",
    5: "май",
    6: "июнь",
    7: "июль",
    8: "август",
    9: "сентябрь",
    10: "октябрь",
    11: "ноябрь",
    12: "декабрь"
}

WEEKDAYS_RU = {
    0: "Понедельник",
    1: "Вторник", 
    2: "Среда",
    3: "Четверг",
    4: "Пятница",
    5: "Суббота",
    6: "Воскресенье"
}

# Шаблон содержимого файла
TEMPLATE = """### {weekday}

- [ ] Проверить почту
- [ ] 
- [ ] Заполнить Tempo

----------

"""

def create_daily_note():
    """Создаёт ежедневную заметку в структуре годов и месяцев"""
    
    # Получаем текущую дату
    now = datetime.now()
    current_year = str(now.year)
    current_month = now.month
    current_day = now.strftime("%d.%m.%y")
    weekday = WEEKDAYS_RU[now.weekday()]
    
    # Формируем пути
    year_dir = os.path.join(BASE_DIR, current_year)
    month_dir = os.path.join(year_dir, MONTHS_RU[current_month])
    
    # Создаём директории, если их нет
    os.makedirs(month_dir, exist_ok=True)
    
    # Полный путь к файлу
    file_path = os.path.join(month_dir, f"{current_day}.md")
    
    # Проверяем, существует ли уже файл
    if os.path.exists(file_path):
        print(f"Файл {file_path} уже существует!")
        return False
    
    # Заполняем шаблон
    content = TEMPLATE.format(weekday=weekday) 
    
    # Создаём и записываем файл
    try:
        with open(file_path, 'w', encoding='utf-8') as f:
            f.write(content)
        print(f"✅ Создан файл: {file_path}")
        return True
    except Exception as e:
        print(f"❌ Ошибка при создании файла: {e}")
        return False
    
def cleanup_empty_notes():
    """Удаляет пустые (неизменённые) заметки за предыдущие дни, пока не встретит заполненную"""
    
    now = datetime.now()
    current_year = str(now.year)
    current_month = now.month
    current_day = now.day
    
    # Идём от текущего дня назад
    for i in range(1, 5):  # Проверяем последние 5 дней
        check_date = now.replace(day=current_day - i) if current_day - i > 0 else now.replace(month=current_month - 1, day=30)
        
        # Формируем путь к файлу
        year_dir = os.path.join(BASE_DIR, str(check_date.year))
        month_dir = os.path.join(year_dir, MONTHS_RU[check_date.month])
        file_name = check_date.strftime("%d.%m.%y") + ".md"
        file_path = os.path.join(month_dir, file_name)
        
        # Если файл не существует, пропускаем
        if not os.path.exists(file_path):
            continue
        
        # Читаем содержимое
        with open(file_path, 'r', encoding='utf-8') as f:
            content = f.read()
        
        # Проверяем, отличается ли от шаблона
        weekday = WEEKDAYS_RU[check_date.weekday()]
        template_content = TEMPLATE.format(weekday=weekday)
        
        if content.strip() == template_content.strip():
            # Пустой файл - удаляем
            os.remove(file_path)
            print(f"🗑️  Удалён пустой файл: {file_path}")
        else:
            # Нашли заполненный файл - останавливаемся
            print(f"✅ Найден заполненный файл: {file_path}, остановка очистки")
            break

def send_notification():
    """Отправляет уведомление через fly"""

    subprocess.run([
        "fly", "notify",
        "-t", "📝 Планерка",
        "-m", "Заполни план работы на сегодня!",
        "-i", "face-smiling",
        "-u", "5m"
    ])
    print("🔔 Уведомление отправлено")

if __name__ == "__main__":
    create_daily_note()
    cleanup_empty_notes()
