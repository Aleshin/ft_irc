#!/bin/bash

# Тесты для Фазы 1: Исправление критических проблем

cd "$(dirname "$0")/../.." || exit 1

source tests/scripts/test_helpers.sh

echo "==================================="
echo "    PHASE 1 TESTS"
echo "==================================="
echo

print_system_info

# Проверка компиляции
if ! check_compilation; then
    echo -e "${RED}Cannot proceed without successful compilation${NC}"
    exit 1
fi
echo

# Счетчики
PASSED=0
FAILED=0
TOTAL=0

# Функция для запуска теста
run_test() {
    local test_func=$1
    ((TOTAL++))
    
    if $test_func; then
        ((PASSED++))
        return 0
    else
        ((FAILED++))
        return 1
    fi
}

# ============================================
# ТЕСТ 1: Сервер запускается
# ============================================
test_server_starts() {
    echo "[1/7] Testing server starts..."
    
    local port=$(random_port)
    
    # Запускаем сервер в фоне
    ./ircserv $port password > /tmp/test_start.log 2>&1 &
    local pid=$!
    sleep 1
    
    if kill -0 $pid 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Server started successfully"
        kill $pid 2>/dev/null
        wait $pid 2>/dev/null
        return 0
    else
        echo -e "${RED}✗${NC} Server failed to start"
        cat /tmp/test_start.log
        return 1
    fi
}

# ============================================
# ТЕСТ 2: Сервер принимает соединения
# ============================================
test_accepts_connection() {
    echo "[2/7] Testing connection acceptance..."
    
    local port=$(random_port)
    
    ./ircserv $port password > /dev/null 2>&1 &
    local pid=$!
    sleep 1
    
    if ! wait_for_port $port; then
        echo -e "${RED}✗${NC} Server port not available"
        kill $pid 2>/dev/null
        return 1
    fi
    
    if echo "test" | nc -w 1 localhost $port > /dev/null 2>&1; then
        echo -e "${GREEN}✓${NC} Server accepts connections"
        kill $pid 2>/dev/null
        wait $pid 2>/dev/null
        return 0
    else
        echo -e "${RED}✗${NC} Server does not accept connections"
        kill $pid 2>/dev/null
        return 1
    fi
}

# ============================================
# ТЕСТ 3: Корректное отключение клиента
# ============================================
test_graceful_disconnect() {
    echo "[3/7] Testing graceful disconnect..."
    
    local port=$(random_port)
    
    ./ircserv $port password > /tmp/test_disconnect.log 2>&1 &
    local pid=$!
    sleep 1
    
    # Подключаемся и сразу отключаемся (EOF)
    echo "" | nc -w 1 localhost $port > /dev/null 2>&1
    sleep 1
    
    # Сервер должен остаться живым
    if kill -0 $pid 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Server survives client disconnect"
        kill $pid 2>/dev/null
        wait $pid 2>/dev/null
        return 0
    else
        echo -e "${RED}✗${NC} Server crashed on disconnect"
        cat /tmp/test_disconnect.log
        return 1
    fi
}

# ============================================
# ТЕСТ 4: Быстрый перезапуск (SO_REUSEADDR)
# ============================================
test_rapid_restart() {
    echo "[4/7] Testing rapid restart (SO_REUSEADDR)..."
    
    local port=$(random_port)
    
    # Запускаем первый раз
    ./ircserv $port password > /dev/null 2>&1 &
    local pid1=$!
    sleep 1
    
    # Убиваем
    kill $pid1 2>/dev/null
    wait $pid1 2>/dev/null
    sleep 0.5
    
    # Пробуем сразу запустить снова
    ./ircserv $port password > /tmp/test_restart.log 2>&1 &
    local pid2=$!
    sleep 1
    
    if kill -0 $pid2 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Rapid restart works (SO_REUSEADDR enabled)"
        kill $pid2 2>/dev/null
        wait $pid2 2>/dev/null
        return 0
    else
        echo -e "${RED}✗${NC} Rapid restart failed (SO_REUSEADDR missing?)"
        cat /tmp/test_restart.log
        return 1
    fi
}

# ============================================
# ТЕСТ 5: Множественные клиенты
# ============================================
test_multiple_clients() {
    echo "[5/7] Testing multiple clients..."
    
    local port=$(random_port)
    
    ./ircserv $port password > /dev/null 2>&1 &
    local pid=$!
    sleep 1
    
    # Подключаем 5 клиентов одновременно (в фоне)
    local client_pids=()
    for i in {1..5}; do
        (echo "CLIENT $i" | nc -w 1 localhost $port > /dev/null 2>&1) &
        client_pids+=($!)
    done
    
    # Ждем завершения клиентов с таймаутом
    local timeout=5
    local elapsed=0
    while [ $elapsed -lt $timeout ]; do
        local all_done=true
        for cpid in "${client_pids[@]}"; do
            if kill -0 $cpid 2>/dev/null; then
                all_done=false
                break
            fi
        done
        
        if [ "$all_done" = true ]; then
            break
        fi
        
        sleep 0.5
        ((elapsed++))
    done
    
    # Убиваем зависшие клиенты если есть
    for cpid in "${client_pids[@]}"; do
        kill -9 $cpid 2>/dev/null || true
    done
    
    sleep 0.5
    
    # Сервер должен быть жив
    if kill -0 $pid 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Server handles multiple clients"
        kill $pid 2>/dev/null
        wait $pid 2>/dev/null
        return 0
    else
        echo -e "${RED}✗${NC} Server crashed with multiple clients"
        return 1
    fi
}

# ============================================
# ТЕСТ 6: Проверка утечек памяти (valgrind)
# ============================================
test_no_memory_leaks() {
    echo "[6/7] Testing memory leaks (valgrind)..."
    
    if ! command -v valgrind &> /dev/null; then
        echo -e "${YELLOW}⊘${NC} valgrind not installed, skipping"
        return 0
    fi
    
    local port=$(random_port)
    
    # Запускаем под valgrind
    valgrind --leak-check=full --error-exitcode=1 --log-file=/tmp/valgrind.log \
        ./ircserv $port password > /dev/null 2>&1 &
    local pid=$!
    sleep 2
    
    # Подключаемся и отключаемся несколько раз
    for i in {1..3}; do
        echo "TEST" | nc -w 1 localhost $port > /dev/null 2>&1
        sleep 0.5
    done
    
    # Даем серверу 3 секунды на обработку, потом убиваем
    sleep 1
    kill $pid 2>/dev/null
    wait $pid 2>/dev/null
    
    # Проверяем отчет valgrind
    if grep -q "ERROR SUMMARY: 0 errors" /tmp/valgrind.log && \
       ! grep -q "definitely lost" /tmp/valgrind.log; then
        echo -e "${GREEN}✓${NC} No memory leaks detected"
        return 0
    else
        echo -e "${RED}✗${NC} Memory leaks detected"
        echo "Valgrind report:"
        cat /tmp/valgrind.log
        return 1
    fi
}

# ============================================
# ТЕСТ 7: Обработка команд
# ============================================
test_command_extraction() {
    echo "[7/7] Testing command extraction..."
    
    local port=$(random_port)
    
    ./ircserv $port password > /tmp/test_commands.log 2>&1 &
    local pid=$!
    sleep 1
    
    # Отправляем команду IRC
    local response=$(echo -e "NICK testuser\r\n" | nc -w 1 localhost $port 2>&1)
    
    sleep 1
    
    # Проверяем что сервер не упал
    if kill -0 $pid 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Server processes commands without crashing"
        kill $pid 2>/dev/null
        wait $pid 2>/dev/null
        return 0
    else
        echo -e "${RED}✗${NC} Server crashed on command"
        cat /tmp/test_commands.log
        return 1
    fi
}

# ============================================
# Запуск всех тестов
# ============================================
echo "-----------------------------------"
echo "Running tests..."
echo "-----------------------------------"
echo

run_test test_server_starts
echo

run_test test_accepts_connection
echo

run_test test_graceful_disconnect
echo

run_test test_rapid_restart
echo

run_test test_multiple_clients
echo

run_test test_no_memory_leaks
echo

run_test test_command_extraction
echo

# ============================================
# Итоговый отчет
# ============================================
echo "==================================="
echo "PHASE 1 RESULTS"
echo "==================================="
echo "Total:  $TOTAL"
echo -e "Passed: ${GREEN}$PASSED${NC}"
echo -e "Failed: ${RED}$FAILED${NC}"
echo "==================================="

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✓ PHASE 1 COMPLETE${NC}"
    echo
    echo "You can now proceed to Phase 2!"
    exit 0
else
    echo -e "${RED}✗ PHASE 1 INCOMPLETE${NC}"
    echo
    echo "Please fix the failing tests before proceeding."
    exit 1
fi
