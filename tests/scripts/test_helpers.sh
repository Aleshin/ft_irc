#!/bin/bash

# Вспомогательные функции для тестирования IRC сервера

# Цвета для вывода
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Глобальные переменные
SERVER_PID=""
DEFAULT_PORT=6667
DEFAULT_PASSWORD="password"

# Функция для запуска сервера
start_server() {
    local port=${1:-$DEFAULT_PORT}
    local password=${2:-$DEFAULT_PASSWORD}
    
    echo -e "${BLUE}Starting server on port $port...${NC}"
    ./ircserv $port $password > /tmp/irc_server_$port.log 2>&1 &
    SERVER_PID=$!
    sleep 1
    
    if kill -0 $SERVER_PID 2>/dev/null; then
        echo -e "${GREEN}✓ Server started (PID: $SERVER_PID)${NC}"
        return 0
    else
        echo -e "${RED}✗ Failed to start server${NC}"
        cat /tmp/irc_server_$port.log
        return 1
    fi
}

# Функция для остановки сервера
stop_server() {
    if [ -n "$SERVER_PID" ]; then
        echo -e "${BLUE}Stopping server (PID: $SERVER_PID)...${NC}"
        kill $SERVER_PID 2>/dev/null
        wait $SERVER_PID 2>/dev/null
        echo -e "${GREEN}✓ Server stopped${NC}"
        unset SERVER_PID
    fi
}

# Функция для отправки IRC команды
send_irc_command() {
    local command="$1"
    local port=${2:-$DEFAULT_PORT}
    local timeout=${3:-2}
    
    echo -e "${command}\r\n" | nc -w $timeout localhost $port 2>&1
}

# Функция для отправки нескольких команд
send_irc_commands() {
    local port=${1:-$DEFAULT_PORT}
    local timeout=${2:-2}
    shift 2
    
    local commands=""
    for cmd in "$@"; do
        commands+="${cmd}\r\n"
    done
    
    echo -e "$commands" | nc -w $timeout localhost $port 2>&1
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

# Функция для проверки численного ответа IRC (001, 464, и т.д.)
check_numeric_response() {
    local response="$1"
    local numeric="$2"
    
    if echo "$response" | grep -qE "^:[^ ]+ $numeric "; then
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
        return 0
    else
        echo -e "${RED}✗${NC} $test_name"
        return 1
    fi
}

# Функция для проверки, что порт свободен
check_port_free() {
    local port=${1:-$DEFAULT_PORT}
    
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${RED}✗ Port $port is already in use${NC}"
        return 1
    else
        return 0
    fi
}

# Функция для ожидания, пока порт станет доступным
wait_for_port() {
    local port=${1:-$DEFAULT_PORT}
    local max_attempts=${2:-10}
    local attempt=0
    
    while [ $attempt -lt $max_attempts ]; do
        if nc -z localhost $port 2>/dev/null; then
            return 0
        fi
        sleep 0.5
        ((attempt++))
    done
    
    return 1
}

# Функция для проверки компиляции проекта
check_compilation() {
    echo -e "${BLUE}Checking compilation...${NC}"
    
    if make > /tmp/make.log 2>&1; then
        echo -e "${GREEN}✓ Project compiled successfully${NC}"
        return 0
    else
        echo -e "${RED}✗ Compilation failed${NC}"
        cat /tmp/make.log
        return 1
    fi
}

# Функция для генерации случайного порта
random_port() {
    echo $((6000 + RANDOM % 1000))
}

# Cleanup при выходе
cleanup() {
    stop_server
    rm -f /tmp/irc_test_*
    rm -f /tmp/irc_server_*.log
    rm -f /tmp/make.log
}

trap cleanup EXIT INT TERM

# Вывод информации о системе (для отладки)
print_system_info() {
    echo -e "${BLUE}=== System Info ===${NC}"
    echo "OS: $(uname -s)"
    echo "Date: $(date)"
    echo "Working Directory: $(pwd)"
    echo "User: $(whoami)"
    echo
}
