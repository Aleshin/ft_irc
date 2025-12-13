# FT_IRC Testing Framework

Система тестирования для проекта IRC сервера

## 🚀 Быстрый Старт

```bash
# Запустить тесты текущей фазы
cd tests
make phase1

# Посмотреть все доступные команды
make help
```

## 📁 Структура

```
tests/
├── phase_tests/        # Тесты по фазам разработки
│   ├── phase1_tests.sh   ← Фаза 1: Критические исправления
│   ├── phase2_tests.sh   ← Фаза 2: Парсинг команд
│   ├── phase3_tests.sh   ← Фаза 3: Регистрация
│   ├── phase4_tests.sh   ← Фаза 4: Каналы
│   └── phase5_tests.sh   ← Фаза 5: Операторские команды
│
├── scripts/            # Вспомогательные скрипты
│   └── test_helpers.sh   ← Общие функции для тестов
│
├── unit/               # Модульные тесты (C++)
├── integration/        # Интеграционные тесты (bash)
├── stress/             # Нагрузочные тесты
├── fixtures/           # Тестовые данные
│
├── Makefile           # Основной файл для запуска тестов
└── README.md          # Этот файл
```

## 📋 Команды

### Тесты по фазам
```bash
make phase1    # Фаза 1: Критические исправления
make phase2    # Фаза 2: Парсинг IRC команд
make phase3    # Фаза 3: Регистрация клиентов
make phase4    # Фаза 4: Каналы и сообщения
make phase5    # Фаза 5: Операторские команды
```

### Другие тесты
```bash
make unit          # Модульные тесты
make integration   # Интеграционные тесты
make stress        # Нагрузочные тесты
make valgrind      # Проверка утечек памяти
```

### Утилиты
```bash
make clean         # Очистить временные файлы
make help          # Показать справку
make quick         # Быстрая проверка (только phase1)
make continuous    # Запустить все доступные тесты
```

## 🎯 Фаза 1: Критические Исправления

Текущая активная фаза разработки.

### Что тестируется:
1. ✅ Сервер запускается без ошибок
2. ✅ Принимает подключения
3. ✅ Не крашится при отключении клиента
4. ✅ Быстрый перезапуск (SO_REUSEADDR)
5. ✅ Множественные клиенты
6. ✅ Нет утечек памяти (valgrind)
7. ✅ Обработка команд без крашей

### Запуск:
```bash
cd tests
make phase1
```

### Ожидаемый результат:
```
===================================
    PHASE 1 TESTS
===================================

[1/7] Testing server starts...
✓ Server started successfully

[2/7] Testing connection acceptance...
✓ Server accepts connections

[3/7] Testing graceful disconnect...
✓ Server survives client disconnect

[4/7] Testing rapid restart (SO_REUSEADDR)...
✓ Rapid restart works (SO_REUSEADDR enabled)

[5/7] Testing multiple clients...
✓ Server handles multiple clients

[6/7] Testing memory leaks (valgrind)...
✓ No memory leaks detected

[7/7] Testing command extraction...
✓ Server processes commands without crashing

===================================
PHASE 1 RESULTS
===================================
Total:  7
Passed: 7
Failed: 0
===================================
✓ PHASE 1 COMPLETE

You can now proceed to Phase 2!
```

## 🔧 Разработка Тестов

### Добавление нового теста

1. Создайте функцию теста:
```bash
test_my_feature() {
    echo "Testing my feature..."
    
    # Ваша логика теста
    local result=$?
    
    if [ $result -eq 0 ]; then
        echo "✓ Test passed"
        return 0
    else
        echo "✗ Test failed"
        return 1
    fi
}
```

2. Добавьте вызов в нужный файл:
```bash
run_test test_my_feature
```

### Использование helper функций

```bash
# Импортировать хелперы
source tests/scripts/test_helpers.sh

# Запустить сервер
start_server 6667 password

# Отправить IRC команду
response=$(send_irc_command "NICK john" 6667)

# Проверить ответ
if check_response "$response" "Welcome"; then
    echo "✓ OK"
fi

# Остановить сервер
stop_server
```

## 📊 Отчеты

### Генерация полного отчета:
```bash
make continuous > test_report.txt 2>&1
```

### Просмотр логов:
```bash
# Логи сервера
cat /tmp/irc_server_*.log

# Логи valgrind
cat /tmp/valgrind.log

# Логи тестов
cat /tmp/test_*.log
```

## ✅ Критерии Прохождения

### Phase 1: ✓ Готово
- [x] Сервер стартует
- [x] Принимает соединения
- [x] Не крашится при отключении
- [x] Быстрый перезапуск
- [x] Множественные клиенты
- [x] Нет утечек памяти
- [x] Обработка команд

### Phase 2: ⏳ Ожидает
- [ ] Парсинг всех типов команд
- [ ] Построение ответов
- [ ] Валидация

### Phase 3: ⏳ Ожидает
- [ ] Полная регистрация
- [ ] Проверка пароля
- [ ] Уникальность nickname

### Phase 4: ⏳ Ожидает
- [ ] JOIN создает канал
- [ ] PRIVMSG работает
- [ ] Broadcast работает

### Phase 5: ⏳ Ожидает
- [ ] Операторские команды
- [ ] Проверка прав

## 🐛 Отладка

### Если тесты не проходят:

1. **Проверьте компиляцию:**
   ```bash
   cd ..
   make re
   ```

2. **Запустите сервер вручную:**
   ```bash
   ./ircserv 6667 password
   ```

3. **Проверьте логи:**
   ```bash
   cat /tmp/irc_server_*.log
   ```

4. **Проверьте valgrind:**
   ```bash
   make valgrind
   ```

5. **Запустите отдельный тест:**
   ```bash
   bash tests/phase_tests/phase1_tests.sh
   ```

## 📚 Дополнительная Информация

- [TESTING_GUIDE.md](../docs/TESTING_GUIDE.md) - Полное руководство по тестированию
- [DEVELOPMENT_PLAN.md](../docs/DEVELOPMENT_PLAN.md) - План разработки
- [GETTING_STARTED.md](../docs/GETTING_STARTED.md) - Примеры реализации

## 🤝 Вклад

При добавлении новых функций:
1. Создайте соответствующие тесты
2. Убедитесь что все существующие тесты проходят
3. Обновите документацию

---

**Последнее обновление:** 13 декабря 2025
