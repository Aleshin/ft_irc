#!/bin/bash
# Phase 1 Tests: Server Infrastructure (startup, connections, signals)

PORT=6697
PASS="secret123"
SERVER_PID=""
TESTS_PASSED=0
TESTS_TOTAL=0
TMPDIR="/tmp/irc_tests_$$"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

mkdir -p "$TMPDIR"

cleanup() {
    [ -n "$SERVER_PID" ] && kill $SERVER_PID 2>/dev/null
    wait $SERVER_PID 2>/dev/null
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

run_test() {
    local name="$1"
    local result="$2"  # 0 = pass, 1 = fail
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if [ "$result" -eq 0 ]; then
        echo -e "${GREEN}✓${NC} $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $name"
        return 1
    fi
}

echo "=========================================="
echo "Phase 1: Server Infrastructure Tests"
echo "=========================================="
echo ""

# Build
echo -e "${YELLOW}Building...${NC}"
make -s
if [ $? -ne 0 ]; then
    echo -e "${RED}Build failed!${NC}"
    exit 1
fi
echo ""

# ==============================================================================
# TEST 1: Server starts with correct arguments
# ==============================================================================
echo -e "${YELLOW}=== Startup Tests ===${NC}"

./ircserv $PORT $PASS > "$TMPDIR/srv.log" 2>&1 &
SERVER_PID=$!
sleep 0.5

if kill -0 $SERVER_PID 2>/dev/null; then
    run_test "Server starts successfully" 0
else
    run_test "Server starts successfully" 1
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null
SERVER_PID=""
sleep 0.3

# ==============================================================================
# TEST 2: Server rejects wrong argument count
# ==============================================================================
./ircserv $PORT > "$TMPDIR/args.log" 2>&1 &
WRONG_PID=$!
sleep 0.3

if ! kill -0 $WRONG_PID 2>/dev/null; then
    run_test "Server rejects wrong argument count" 0
else
    run_test "Server rejects wrong argument count" 1
    kill $WRONG_PID 2>/dev/null
fi
wait $WRONG_PID 2>/dev/null

# ==============================================================================
# TEST 3: Server accepts connections
# ==============================================================================
echo ""
echo -e "${YELLOW}=== Connection Tests ===${NC}"

./ircserv $PORT $PASS > "$TMPDIR/srv.log" 2>&1 &
SERVER_PID=$!
sleep 0.5

OUTPUT=$(echo "QUIT" | nc -w 1 localhost $PORT 2>/dev/null)
if [ $? -eq 0 ]; then
    run_test "Server accepts TCP connections" 0
else
    run_test "Server accepts TCP connections" 1
fi

# ==============================================================================
# TEST 4: Multiple simultaneous connections
# ==============================================================================
(echo "PASS $PASS"; sleep 1) | nc localhost $PORT > "$TMPDIR/c1.txt" 2>&1 &
C1=$!
(echo "PASS $PASS"; sleep 1) | nc localhost $PORT > "$TMPDIR/c2.txt" 2>&1 &
C2=$!
(echo "PASS $PASS"; sleep 1) | nc localhost $PORT > "$TMPDIR/c3.txt" 2>&1 &
C3=$!

sleep 1.5
kill $C1 $C2 $C3 2>/dev/null
wait $C1 $C2 $C3 2>/dev/null

# Check if server is still alive
if kill -0 $SERVER_PID 2>/dev/null; then
    run_test "Handles multiple simultaneous connections" 0
else
    run_test "Handles multiple simultaneous connections" 1
fi

# ==============================================================================
# TEST 5: Client disconnect doesn't crash server
# ==============================================================================
echo ""
echo -e "${YELLOW}=== Stability Tests ===${NC}"

for i in 1 2 3 4 5; do
    echo "QUIT" | nc -w 1 localhost $PORT > /dev/null 2>&1
done

if kill -0 $SERVER_PID 2>/dev/null; then
    run_test "Server survives rapid connect/disconnect" 0
else
    run_test "Server survives rapid connect/disconnect" 1
fi

# ==============================================================================
# TEST 6: Empty input handling
# ==============================================================================
echo "" | nc -w 1 localhost $PORT > /dev/null 2>&1

if kill -0 $SERVER_PID 2>/dev/null; then
    run_test "Server handles empty input" 0
else
    run_test "Server handles empty input" 1
fi

# ==============================================================================
# TEST 7: Long input handling
# ==============================================================================
LONG_INPUT=$(python3 -c "print('A' * 1000)" 2>/dev/null || printf 'A%.0s' {1..1000})
echo "$LONG_INPUT" | nc -w 1 localhost $PORT > /dev/null 2>&1

if kill -0 $SERVER_PID 2>/dev/null; then
    run_test "Server handles long input (1000 chars)" 0
else
    run_test "Server handles long input (1000 chars)" 1
fi

# ==============================================================================
# TEST 8: Binary data handling
# ==============================================================================
printf '\x00\x01\x02\xff\xfe' | nc -w 1 localhost $PORT > /dev/null 2>&1

if kill -0 $SERVER_PID 2>/dev/null; then
    run_test "Server handles binary data" 0
else
    run_test "Server handles binary data" 1
fi

# ==============================================================================
# TEST 9: Partial message handling
# ==============================================================================
(printf "PASS "; sleep 0.2; printf "$PASS\r\n"; sleep 0.5) | nc localhost $PORT > "$TMPDIR/partial.txt" 2>&1

if kill -0 $SERVER_PID 2>/dev/null; then
    run_test "Server handles partial/slow messages" 0
else
    run_test "Server handles partial/slow messages" 1
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null
SERVER_PID=""

# ==============================================================================
# TEST 10: Port reuse after restart
# ==============================================================================
echo ""
echo -e "${YELLOW}=== Restart Tests ===${NC}"

./ircserv $PORT $PASS > "$TMPDIR/srv.log" 2>&1 &
SERVER_PID=$!
sleep 0.5

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null
sleep 0.3

./ircserv $PORT $PASS > "$TMPDIR/srv.log" 2>&1 &
SERVER_PID=$!
sleep 0.5

if kill -0 $SERVER_PID 2>/dev/null; then
    run_test "Port reusable after server restart" 0
else
    run_test "Port reusable after server restart" 1
fi

kill $SERVER_PID 2>/dev/null
wait $SERVER_PID 2>/dev/null
SERVER_PID=""

# ==============================================================================
# SUMMARY
# ==============================================================================
echo ""
echo "=========================================="
echo -e "Results: ${TESTS_PASSED}/${TESTS_TOTAL} tests passed"
echo "=========================================="

if [ $TESTS_PASSED -eq $TESTS_TOTAL ]; then
    echo -e "${GREEN}All Phase 1 tests passed!${NC}"
    exit 0
else
    echo -e "${YELLOW}Some tests failed. Review the output above.${NC}"
    exit 1
fi
