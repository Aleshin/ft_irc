#!/bin/bash

# Проверка системных требований для тестирования

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== System Requirements Check ===${NC}"
echo

# Определение ОС
OS=$(uname -s)
echo "Operating System: $OS"

case "$OS" in
    Darwin)
        echo -e "${GREEN}✓${NC} macOS detected"
        ;;
    Linux)
        echo -e "${GREEN}✓${NC} Linux detected"
        ;;
    *)
        echo -e "${YELLOW}⚠${NC}  Unknown OS: $OS"
        ;;
esac
echo

# Проверка необходимых утилит
echo "Required utilities:"
echo

# 1. C++ compiler
if command -v c++ &> /dev/null; then
    echo -e "${GREEN}✓${NC} c++ ($(c++ --version | head -n1))"
else
    echo -e "${RED}✗${NC} c++ not found"
    exit 1
fi

# 2. make
if command -v make &> /dev/null; then
    echo -e "${GREEN}✓${NC} make ($(make --version | head -n1))"
else
    echo -e "${RED}✗${NC} make not found"
    exit 1
fi

# 3. netcat
if command -v nc &> /dev/null; then
    NC_VERSION=$(nc -h 2>&1 | head -n1)
    echo -e "${GREEN}✓${NC} nc (netcat)"
    
    # Проверка типа netcat
    if nc -h 2>&1 | grep -q "GNU"; then
        echo "  └─ GNU netcat (Linux)"
    else
        echo "  └─ BSD netcat (macOS)"
    fi
else
    echo -e "${RED}✗${NC} nc (netcat) not found"
    echo "  Install: "
    case "$OS" in
        Darwin)
            echo "    brew install netcat"
            ;;
        Linux)
            echo "    sudo apt-get install netcat  # Debian/Ubuntu"
            echo "    sudo yum install nc           # RHEL/CentOS"
            ;;
    esac
    exit 1
fi

# 4. git
if command -v git &> /dev/null; then
    echo -e "${GREEN}✓${NC} git ($(git --version))"
else
    echo -e "${YELLOW}⚠${NC}  git not found (optional)"
fi

# 5. valgrind (optional)
if command -v valgrind &> /dev/null; then
    echo -e "${GREEN}✓${NC} valgrind ($(valgrind --version))"
else
    echo -e "${YELLOW}⚠${NC}  valgrind not found (optional, for memory leak tests)"
    case "$OS" in
        Darwin)
            echo "  Note: valgrind has limited support on macOS"
            echo "  Install: brew install valgrind"
            ;;
        Linux)
            echo "  Install: sudo apt-get install valgrind"
            ;;
    esac
fi

echo
echo -e "${BLUE}=== Port Availability Check ===${NC}"
echo

# Проверка доступности портов для тестирования
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null 2>&1; then
        echo -e "${YELLOW}⚠${NC}  Port $port is in use"
        return 1
    else
        echo -e "${GREEN}✓${NC} Port $port is available"
        return 0
    fi
}

check_port 6667
check_port 6668
check_port 6669

echo
echo -e "${BLUE}=== Compilation Check ===${NC}"
echo

cd "$(dirname "$0")/.." || exit 1

if make > /tmp/make_check.log 2>&1; then
    echo -e "${GREEN}✓${NC} Project compiles successfully"
else
    echo -e "${RED}✗${NC} Compilation failed"
    echo "Error log:"
    cat /tmp/make_check.log
    exit 1
fi

echo
echo -e "${GREEN}=== All checks passed! ===${NC}"
echo "You can run tests with:"
echo "  cd tests && make phase1"
