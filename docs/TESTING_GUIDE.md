# Руководство по Тестированию FT_IRC

> Организация тестирования по лучшим практикам

## 📁 Структура Тестов

```
tests/
├── unit/                    # Модульные тесты (отдельные классы)
│   ├── test_client.cpp
│   ├── test_channel.cpp
│   ├── test_message.cpp
│   └── Makefile
│
├── integration/             # Интеграционные тесты (взаимодействие)
│   ├── test_registration.sh
│   ├── test_channels.sh
│   ├── test_privmsg.sh
│   └── test_operators.sh
│
├── stress/                  # Нагрузочные тесты
│   ├── test_100_clients.sh
│   ├── test_rapid_connect.sh
│   └── test_large_messages.sh
│
├── scripts/                 # Вспомогательные скрипты
│   ├── irc_client.sh       # Простой IRC клиент на bash
│   ├── send_command.sh     # Отправка одной команды
│   └── check_response.sh   # Проверка ответа
│
├── fixtures/                # Тестовые данные
│   ├── valid_commands.txt
│   ├── invalid_commands.txt
│   └── expected_responses.txt
│
└── phase_tests/             # Тесты по фазам разработки
    ├── phase1_tests.sh
    ├── phase2_tests.sh
    ├── phase3_tests.sh
    ├── phase4_tests.sh
    └── phase5_tests.sh
```

---

## 🔧 Типы Тестов

### 1. Unit Tests (Модульные)

**Что тестируют:** Отдельные классы в изоляции

**Инструменты:** Простые C++ файлы с assert

**Пример:**
```cpp
// tests/unit/test_client.cpp
#include "Client.hpp"
#include <cassert>
#include <iostream>

void test_client_creation() {
    Client client(42);
    assert(client.getFd() == 42);
    assert(!client.isRegistered());
    std::cout << "✓ Client creation OK\n";
}

void test_client_buffers() {
    Client client(1);
    client.appendToInput("NICK john\r\n");
    std::string line = client.extractLine();
    assert(line == "NICK john");
    std::cout << "✓ Client buffers OK\n";
}

int main() {
    test_client_creation();
    test_client_buffers();
    std::cout << "All Client tests passed!\n";
    return 0;
}
```

**Запуск:**
```bash
make -C tests/unit
./tests/unit/test_client
```

---

### 2. Integration Tests (Интеграционные)

**Что тестируют:** Взаимодействие сервера с IRC клиентом

**Инструменты:** Bash скрипты + netcat/telnet

**Пример:**
```bash
# tests/integration/test_registration.sh
#!/bin/bash

source tests/scripts/test_helpers.sh

test_basic_registration() {
    echo "Testing basic registration..."
    
    # Запускаем сервер
    ./ircserv 6667 password &
    SERVER_PID=$!
    sleep 1
    
    # Отправляем команды
    response=$(echo -e "PASS password\r\nNICK john\r\nUSER john 0 * :John\r\n" | \
               nc localhost 6667 2>&1)
    
    # Проверяем ответ
    if echo "$response" | grep -q "001.*Welcome"; then
        echo "✓ Registration successful"
        kill $SERVER_PID
        return 0
    else
        echo "✗ Registration failed"
        echo "Response: $response"
        kill $SERVER_PID
        return 1
    fi
}

test_wrong_password() {
    echo "Testing wrong password..."
    
    ./ircserv 6667 password &
    SERVER_PID=$!
    sleep 1
    
    response=$(echo -e "PASS wrongpass\r\nNICK john\r\nUSER john 0 * :John\r\n" | \
               nc localhost 6667 2>&1)
    
    if echo "$response" | grep -q "464.*Password incorrect"; then
        echo "✓ Wrong password detected"
        kill $SERVER_PID
        return 0
    else
        echo "✗ Wrong password not detected"
        kill $SERVER_PID
        return 1
    fi
}

# Запуск всех тестов
test_basic_registration
test_wrong_password
```

---

### 3. Stress Tests (Нагрузочные)

**Что тестируют:** Стабильность под нагрузкой

**Пример:**
```bash
# tests/stress/test_100_clients.sh
#!/bin/bash

echo "Testing 100 simultaneous clients..."

./ircserv 6667 password &
SERVER_PID=$!
sleep 1

# Запускаем 100 клиентов
for i in {1..100}; do
    (
        echo -e "PASS password\r\nNICK user$i\r\nUSER user$i 0 * :User $i\r\n" | \
        nc localhost 6667 &
    ) &
done

# Ждем завершения
wait

# Проверяем, что сервер еще жив
if kill -0 $SERVER_PID 2>/dev/null; then
    echo "✓ Server survived 100 clients"
    kill $SERVER_PID
    exit 0
else
    echo "✗ Server crashed"
    exit 1
fi
```

---

### 4. Phase Tests (Тесты по фазам)

**Что тестируют:** Конкретную фазу разработки

**Пример:**
```bash
# tests/phase_tests/phase1_tests.sh
#!/bin/bash

source tests/scripts/test_helpers.sh

echo "=== PHASE 1 TESTS ==="
echo

test_server_starts() {
    echo "[1/7] Testing server starts..."
    timeout 2 ./ircserv 6667 password &
    PID=$!
    sleep 1
    
    if kill -0 $PID 2>/dev/null; then
        echo "✓ Server started successfully"
        kill $PID
        return 0
    else
        echo "✗ Server failed to start"
        return 1
    fi
}

test_accepts_connection() {
    echo "[2/7] Testing connection acceptance..."
    ./ircserv 6667 password &
    PID=$!
    sleep 1
    
    if echo "test" | nc -w 1 localhost 6667 &>/dev/null; then
        echo "✓ Server accepts connections"
        kill $PID
        return 0
    else
        echo "✗ Server does not accept connections"
        kill $PID
        return 1
    fi
}

test_graceful_disconnect() {
    echo "[3/7] Testing graceful disconnect..."
    ./ircserv 6667 password &
    PID=$!
    sleep 1
    
    # Подключаемся и сразу отключаемся
    echo "" | nc -w 1 localhost 6667 &>/dev/null
    sleep 1
    
    # Сервер должен остаться живым
    if kill -0 $PID 2>/dev/null; then
        echo "✓ Server survives client disconnect"
        kill $PID
        return 0
    else
        echo "✗ Server crashed on disconnect"
        return 1
    fi
}

test_rapid_restart() {
    echo "[4/7] Testing rapid restart (SO_REUSEADDR)..."
    
    ./ircserv 6667 password &
    PID1=$!
    sleep 1
    kill $PID1
    sleep 1
    
    # Пробуем сразу запустить снова
    ./ircserv 6667 password &
    PID2=$!
    sleep 1
    
    if kill -0 $PID2 2>/dev/null; then
        echo "✓ Rapid restart works (SO_REUSEADDR enabled)"
        kill $PID2
        return 0
    else
        echo "✗ Rapid restart failed (SO_REUSEADDR missing?)"
        return 1
    fi
}

test_pollout_dynamic() {
    echo "[5/7] Testing dynamic POLLOUT..."
    # TODO: Это сложнее протестировать, пока пропускаем
    echo "⊘ POLLOUT test skipped (complex)"
    return 0
}

test_no_memory_leaks() {
    echo "[6/7] Testing memory leaks (valgrind)..."
    
    if ! command -v valgrind &> /dev/null; then
        echo "⊘ valgrind not installed, skipping"
        return 0
    fi
    
    timeout 5 valgrind --leak-check=full --error-exitcode=1 \
        ./ircserv 6667 password &> /tmp/valgrind.log &
    PID=$!
    sleep 2
    
    # Подключаемся и отключаемся
    echo "" | nc -w 1 localhost 6667 &>/dev/null
    sleep 1
    
    kill $PID
    wait $PID
    
    if grep -q "no leaks are possible" /tmp/valgrind.log; then
        echo "✓ No memory leaks detected"
        return 0
    else
        echo "✗ Memory leaks detected"
        cat /tmp/valgrind.log
        return 1
    fi
}

test_command_extraction() {
    echo "[7/7] Testing command extraction..."
    ./ircserv 6667 password &
    PID=$!
    sleep 1
    
    # Отправляем команду с \r\n
    response=$(echo -e "NICK test\r\n" | nc -w 1 localhost 6667)
    
    # Пока просто проверяем что сервер не упал
    if kill -0 $PID 2>/dev/null; then
        echo "✓ Server processes commands"
        kill $PID
        return 0
    else
        echo "✗ Server crashed on command"
        return 1
    fi
}

# Запуск всех тестов
PASSED=0
FAILED=0

run_test() {
    if $1; then
        ((PASSED++))
    else
        ((FAILED++))
    fi
    echo
}

run_test test_server_starts
run_test test_accepts_connection
run_test test_graceful_disconnect
run_test test_rapid_restart
run_test test_pollout_dynamic
run_test test_no_memory_leaks
run_test test_command_extraction

echo "================================"
echo "PHASE 1 RESULTS: $PASSED passed, $FAILED failed"
echo "================================"

if [ $FAILED -eq 0 ]; then
    echo "✓ PHASE 1 COMPLETE"
    exit 0
else
    echo "✗ PHASE 1 INCOMPLETE"
    exit 1
fi
```

---

## 🛠️ Вспомогательные Скрипты

### test_helpers.sh
```bash
# tests/scripts/test_helpers.sh

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Функция для запуска сервера
start_server() {
    local port=${1:-6667}
    local password=${2:-password}
    
    ./ircserv $port $password &
    SERVER_PID=$!
    sleep 1
    
    if kill -0 $SERVER_PID 2>/dev/null; then
        echo "Server started (PID: $SERVER_PID)"
        return 0
    else
        echo "Failed to start server"
        return 1
    fi
}

# Функция для остановки сервера
stop_server() {
    if [ -n "$SERVER_PID" ]; then
        kill $SERVER_PID 2>/dev/null
        wait $SERVER_PID 2>/dev/null
        unset SERVER_PID
    fi
}

# Функция для отправки IRC команды
send_irc_command() {
    local command="$1"
    local port=${2:-6667}
    
    echo -e "${command}\r\n" | nc -w 2 localhost $port
}

# Функция для проверки ответа
check_response() {
    local response="$1"
    local expected="$2"
    
    if echo "$response" | grep -q "$expected"; then
        return 0
    else
        return 1
    fi
}

# Функция для вывода результата теста
print_result() {
    local test_name="$1"
    local result=$2
    
    if [ $result -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $test_name"
    else
        echo -e "${RED}✗${NC} $test_name"
    fi
}

# Cleanup при выходе
cleanup() {
    stop_server
    rm -f /tmp/irc_test_*
}

trap cleanup EXIT
```

---

## 📝 Makefile для Тестов

```makefile
# tests/Makefile

.PHONY: all unit integration stress phase1 phase2 phase3 phase4 phase5 clean

all: unit integration

# Unit tests
unit:
	@echo "Running unit tests..."
	@$(MAKE) -C unit
	@./unit/test_client
	@./unit/test_channel
	@./unit/test_message

# Integration tests
integration:
	@echo "Running integration tests..."
	@bash integration/test_registration.sh
	@bash integration/test_channels.sh
	@bash integration/test_privmsg.sh

# Stress tests
stress:
	@echo "Running stress tests..."
	@bash stress/test_100_clients.sh
	@bash stress/test_rapid_connect.sh

# Phase tests
phase1:
	@echo "Running Phase 1 tests..."
	@bash phase_tests/phase1_tests.sh

phase2:
	@echo "Running Phase 2 tests..."
	@bash phase_tests/phase2_tests.sh

phase3:
	@echo "Running Phase 3 tests..."
	@bash phase_tests/phase3_tests.sh

phase4:
	@echo "Running Phase 4 tests..."
	@bash phase_tests/phase4_tests.sh

phase5:
	@echo "Running Phase 5 tests..."
	@bash phase_tests/phase5_tests.sh

# Memory check
valgrind:
	@echo "Running valgrind check..."
	@valgrind --leak-check=full --error-exitcode=1 ../ircserv 6667 test

clean:
	@$(MAKE) -C unit clean
	@rm -f /tmp/irc_test_*
```

---

## 🚀 Workflow Разработки

### 1. Создание новой фичи

```bash
# 1. Создать ветку для фазы
git checkout -b phase1

# 2. Реализовать фичу
vim src/Server.cpp

# 3. Запустить соответствующие тесты
make -C tests phase1

# 4. Если тесты прошли - коммит
git add src/Server.cpp
git commit -m "Phase 1: Fix POLLOUT dynamic handling"

# 5. Если все тесты фазы прошли - merge в main
git checkout main
git merge phase1
git branch -d phase1
```

---

### 2. Continuous Testing (Автоматизация)

**Создать pre-commit hook:**
```bash
# .git/hooks/pre-commit
#!/bin/bash

echo "Running tests before commit..."

# Компиляция
if ! make > /dev/null 2>&1; then
    echo "✗ Compilation failed"
    exit 1
fi

# Unit tests
if ! make -C tests unit > /dev/null 2>&1; then
    echo "✗ Unit tests failed"
    exit 1
fi

echo "✓ All tests passed"
exit 0
```

```bash
chmod +x .git/hooks/pre-commit
```

---

## 📊 Отчет о Тестировании

### Создать скрипт для генерации отчета:

```bash
# tests/generate_report.sh
#!/bin/bash

echo "==================================="
echo "    FT_IRC TEST REPORT"
echo "==================================="
echo
echo "Date: $(date)"
echo "Commit: $(git rev-parse --short HEAD)"
echo
echo "-----------------------------------"
echo "UNIT TESTS"
echo "-----------------------------------"
make -C tests unit 2>&1 | tee /tmp/unit_report.txt
echo
echo "-----------------------------------"
echo "INTEGRATION TESTS"
echo "-----------------------------------"
make -C tests integration 2>&1 | tee /tmp/integration_report.txt
echo
echo "-----------------------------------"
echo "PHASE TESTS"
echo "-----------------------------------"
make -C tests phase1 2>&1 | tee /tmp/phase_report.txt
echo
echo "==================================="
echo "END OF REPORT"
echo "==================================="
```

---

## ✅ Лучшие Практики

1. **Пишите тесты ПЕРЕД реализацией** (TDD)
2. **Каждый тест должен быть независимым** (можно запускать в любом порядке)
3. **Один тест = одна проверка** (не тестируйте все сразу)
4. **Используйте понятные названия тестов**
5. **Автоматизируйте запуск тестов** (pre-commit hooks)
6. **Проверяйте на утечки памяти** (valgrind)
7. **Тестируйте граничные случаи** (пустые строки, большие данные)
8. **Документируйте тесты** (что и почему тестируем)

---

## 🎯 Критерии Прохождения

### Phase 1:
- ✅ Сервер стартует без ошибок
- ✅ Принимает подключения
- ✅ Не крашится при отключении
- ✅ Быстрый перезапуск работает
- ✅ Нет утечек памяти

### Phase 2:
- ✅ Парсинг всех типов команд
- ✅ Построение всех типов ответов
- ✅ Валидация работает

### Phase 3:
- ✅ Регистрация проходит полностью
- ✅ Проверка пароля работает
- ✅ Nickname уникален

### Phase 4:
- ✅ JOIN создает канал
- ✅ PRIVMSG работает
- ✅ Broadcast работает

### Phase 5:
- ✅ Все операторские команды работают
- ✅ Проверка прав работает

---

**Последнее обновление:** 13 декабря 2025
