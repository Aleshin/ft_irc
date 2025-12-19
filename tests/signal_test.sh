#!/bin/bash
# Signal Handling Test Suite for ft_irc
# Tests graceful shutdown and signal behavior
# NOTE: This test requires the server binary, not a running server

IRCSERV="${IRCSERV:-./ircserv}"
TEST_PORT=6697
TEST_PASS="testpass"

PASSED=0
FAILED=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

cleanup() {
    pkill -f "$IRCSERV $TEST_PORT" 2>/dev/null
    sleep 0.2
}

check() {
    local name="$1" result="$2"
    if [ "$result" = "1" ]; then
        echo -e "  ${GREEN}✅ $name${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}❌ $name${NC}"
        FAILED=$((FAILED + 1))
    fi
}

# Ensure cleanup on exit
trap cleanup EXIT

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Signal Handling Test Suite"
echo "  Binary: $IRCSERV"
echo "  Port: $TEST_PORT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# Check if binary exists
if [ ! -x "$IRCSERV" ]; then
    echo -e "${RED}Error: $IRCSERV not found or not executable${NC}"
    echo "Run from project root or set IRCSERV env var"
    exit 1
fi

# =============================================================================
# SIGNAL TESTS
# =============================================================================
echo "━━━ 1. SIGINT (Ctrl+C) ━━━"

# Test 1: Basic SIGINT handling
cleanup
$IRCSERV $TEST_PORT $TEST_PASS &
SERVER_PID=$!
sleep 0.5

if kill -0 $SERVER_PID 2>/dev/null; then
    kill -SIGINT $SERVER_PID
    sleep 0.5
    if ! kill -0 $SERVER_PID 2>/dev/null; then
        check "SIGINT terminates server" "1"
    else
        check "SIGINT terminates server" "0"
        kill -9 $SERVER_PID 2>/dev/null
    fi
else
    check "Server started" "0"
fi

# Test 2: SIGINT during client connection
cleanup
$IRCSERV $TEST_PORT $TEST_PASS &
SERVER_PID=$!
sleep 0.5

# Connect a client
{ 
    printf "PASS $TEST_PASS\r\nNICK sigtest\r\nUSER s 0 * :S\r\n"
    sleep 2
} | nc localhost $TEST_PORT &
CLIENT_PID=$!
sleep 0.3

if kill -0 $SERVER_PID 2>/dev/null; then
    kill -SIGINT $SERVER_PID
    sleep 0.5
    if ! kill -0 $SERVER_PID 2>/dev/null; then
        check "SIGINT during connection" "1"
    else
        check "SIGINT during connection" "0"
        kill -9 $SERVER_PID 2>/dev/null
    fi
else
    check "Server started for connection test" "0"
fi
kill $CLIENT_PID 2>/dev/null

# =============================================================================
echo ""
echo "━━━ 2. SIGTERM ━━━"

# Test 3: Basic SIGTERM handling
cleanup
$IRCSERV $TEST_PORT $TEST_PASS &
SERVER_PID=$!
sleep 0.5

if kill -0 $SERVER_PID 2>/dev/null; then
    kill -SIGTERM $SERVER_PID
    sleep 0.5
    if ! kill -0 $SERVER_PID 2>/dev/null; then
        check "SIGTERM terminates server" "1"
    else
        check "SIGTERM terminates server" "0"
        kill -9 $SERVER_PID 2>/dev/null
    fi
else
    check "Server started for SIGTERM" "0"
fi

# Test 4: SIGTERM with multiple clients
cleanup
$IRCSERV $TEST_PORT $TEST_PASS &
SERVER_PID=$!
sleep 0.5

# Connect multiple clients
for i in 1 2 3; do
    {
        printf "PASS $TEST_PASS\r\nNICK term$i\r\nUSER t 0 * :T\r\n"
        sleep 3
    } | nc localhost $TEST_PORT &
done
sleep 0.5

if kill -0 $SERVER_PID 2>/dev/null; then
    kill -SIGTERM $SERVER_PID
    sleep 0.5
    if ! kill -0 $SERVER_PID 2>/dev/null; then
        check "SIGTERM with multiple clients" "1"
    else
        check "SIGTERM with multiple clients" "0"
        kill -9 $SERVER_PID 2>/dev/null
    fi
else
    check "Server started for multi-client" "0"
fi

# =============================================================================
echo ""
echo "━━━ 3. SERVER RESTART ━━━"

# Test 5: Server can restart on same port after graceful shutdown
cleanup
$IRCSERV $TEST_PORT $TEST_PASS &
SERVER_PID=$!
sleep 0.5

kill -SIGINT $SERVER_PID
sleep 0.5

# Try to start again on same port
$IRCSERV $TEST_PORT $TEST_PASS &
NEW_PID=$!
sleep 0.5

if kill -0 $NEW_PID 2>/dev/null; then
    check "Restart on same port" "1"
    kill -SIGINT $NEW_PID 2>/dev/null
else
    check "Restart on same port" "0"
fi

# Test 6: Quick restart cycle
cleanup
for i in 1 2 3; do
    $IRCSERV $TEST_PORT $TEST_PASS &
    PID=$!
    sleep 0.3
    if kill -0 $PID 2>/dev/null; then
        kill -SIGINT $PID
        sleep 0.3
    fi
done

$IRCSERV $TEST_PORT $TEST_PASS &
FINAL_PID=$!
sleep 0.5
if kill -0 $FINAL_PID 2>/dev/null; then
    check "Quick restart cycle (3x)" "1"
    kill -SIGINT $FINAL_PID 2>/dev/null
else
    check "Quick restart cycle (3x)" "0"
fi

# =============================================================================
echo ""
echo "━━━ 4. RESOURCE CLEANUP ━━━"

# Test 7: No zombie processes after SIGINT
cleanup
$IRCSERV $TEST_PORT $TEST_PASS &
SERVER_PID=$!
sleep 0.3
kill -SIGINT $SERVER_PID
sleep 0.5

ZOMBIES=$(ps aux | grep -E "Z.*$IRCSERV" | grep -v grep | wc -l)
if [ "$ZOMBIES" -eq 0 ]; then
    check "No zombie processes" "1"
else
    check "No zombie processes" "0"
fi

# Test 8: Port released after shutdown
cleanup
$IRCSERV $TEST_PORT $TEST_PASS &
sleep 0.3
kill -SIGINT $!
sleep 0.5

# Check if port is free
if ! lsof -i :$TEST_PORT 2>/dev/null | grep -q LISTEN; then
    check "Port released after shutdown" "1"
else
    check "Port released after shutdown" "0"
fi

# =============================================================================
echo ""
echo "━━━ 5. EDGE CASES ━━━"

# Test 9: Multiple SIGINTs (should not crash)
cleanup
$IRCSERV $TEST_PORT $TEST_PASS &
SERVER_PID=$!
sleep 0.3

kill -SIGINT $SERVER_PID 2>/dev/null
kill -SIGINT $SERVER_PID 2>/dev/null
kill -SIGINT $SERVER_PID 2>/dev/null
sleep 0.5

# Should have terminated without crash
if ! kill -0 $SERVER_PID 2>/dev/null; then
    check "Multiple SIGINTs handled" "1"
else
    check "Multiple SIGINTs handled" "0"
    kill -9 $SERVER_PID 2>/dev/null
fi

# Test 10: SIGINT during startup
cleanup
$IRCSERV $TEST_PORT $TEST_PASS &
SERVER_PID=$!
kill -SIGINT $SERVER_PID 2>/dev/null  # Immediate signal
sleep 0.3

if ! kill -0 $SERVER_PID 2>/dev/null; then
    check "SIGINT during startup" "1"
else
    check "SIGINT during startup" "0"
    kill -9 $SERVER_PID 2>/dev/null
fi

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
TOTAL=$((PASSED + FAILED))
echo "  Result: $PASSED/$TOTAL passed"
if [ $FAILED -eq 0 ]; then
    echo -e "  ${GREEN}✅ All signal tests passed${NC}"
else
    echo -e "  ${RED}❌ $FAILED tests failed${NC}"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

cleanup
exit $FAILED
