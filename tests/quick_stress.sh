#!/bin/bash
# Quick stress tests - faster version

PORT=6699
PASSWORD="testpass"
SERVER_PID=""
PASSED=0
TOTAL=0

start() {
    ../ircserv $PORT $PASSWORD >/dev/null 2>&1 &
    SERVER_PID=$!
    sleep 0.1
}

stop() {
    kill -9 $SERVER_PID 2>/dev/null
    wait $SERVER_PID 2>/dev/null
    sleep 0.1
}

test_cmd() {
    local name="$1"
    local cmd="$2"
    local pattern="$3"
    TOTAL=$((TOTAL + 1))
    RESPONSE=$(echo -e "$cmd" | nc -c localhost $PORT 2>/dev/null)
    if echo "$RESPONSE" | grep -qE "$pattern"; then
        echo "✓ $name"
        PASSED=$((PASSED + 1))
    else
        echo "✗ $name (expected: $pattern)"
    fi
}

test_alive() {
    local name="$1"
    TOTAL=$((TOTAL + 1))
    if kill -0 $SERVER_PID 2>/dev/null; then
        echo "✓ $name"
        PASSED=$((PASSED + 1))
    else
        echo "✗ $name - CRASHED"
    fi
}

cd "$(dirname "$0")"
echo "Quick Stress Tests"
echo "=================="

# Test 1: Basic connection
start
test_cmd "Basic connection" "PASS $PASSWORD\r\nNICK t1\r\nUSER t1 0 * :t\r\n" "001"
stop

# Test 2: Empty lines
start
echo -e "PASS $PASSWORD\r\nNICK t2\r\nUSER t2 0 * :t\r\n\r\n\r\n" | nc -c localhost $PORT >/dev/null
test_alive "Empty lines"
stop

# Test 3: Long message
start
LONG=$(printf 'A%.0s' {1..600})
echo -e "PASS $PASSWORD\r\nNICK t3\r\nUSER t3 0 * :t\r\nJOIN #t\r\nPRIVMSG #t :$LONG\r\n" | nc -c localhost $PORT >/dev/null
test_alive "Long message (600 chars)"
stop

# Test 4: Invalid nick
start
test_cmd "Invalid nick" "PASS $PASSWORD\r\nNICK @invalid\r\nUSER u 0 * :u\r\n" "432"
stop

# Test 5: Multiple JOINs same channel
start
echo -e "PASS $PASSWORD\r\nNICK t5\r\nUSER t5 0 * :t\r\nJOIN #x\r\nJOIN #x\r\nJOIN #x\r\n" | nc -c localhost $PORT >/dev/null
test_alive "Multiple JOIN same channel"
stop

# Test 6: Self-KICK
start
echo -e "PASS $PASSWORD\r\nNICK t6\r\nUSER t6 0 * :t\r\nJOIN #t\r\nKICK #t t6\r\n" | nc -c localhost $PORT >/dev/null
test_alive "Self-KICK"
stop

# Test 7: Channel modes toggle
start
test_cmd "Mode toggle" "PASS $PASSWORD\r\nNICK t7\r\nUSER t7 0 * :t\r\nJOIN #m\r\nMODE #m +itk pass\r\nMODE #m -itk\r\nMODE #m\r\n" "324"
stop

# Test 8: Invalid MODE +l
start
echo -e "PASS $PASSWORD\r\nNICK t8\r\nUSER t8 0 * :t\r\nJOIN #t\r\nMODE #t +l abc\r\n" | nc -c localhost $PORT >/dev/null
test_alive "MODE +l invalid"
stop

# Test 9: Nick collision (2 clients)
start
{ echo -e "PASS $PASSWORD\r\nNICK taken\r\nUSER t9 0 * :t\r\n"; sleep 1; } | nc localhost $PORT >/dev/null &
BG=$!
sleep 0.2
test_cmd "Nick collision" "PASS $PASSWORD\r\nNICK other\r\nUSER t9 0 * :t\r\nNICK taken\r\n" "433"
kill $BG 2>/dev/null
stop

# Test 10: Rapid connect/disconnect
start
for i in {1..5}; do
    echo -e "PASS $PASSWORD\r\nNICK r$i\r\nUSER r$i 0 * :r\r\nQUIT\r\n" | nc -c localhost $PORT >/dev/null &
done
sleep 0.5
test_alive "Rapid connect/disconnect"
stop

# Test 11: Many channels
start
CMD="PASS $PASSWORD\r\nNICK t11\r\nUSER t11 0 * :t\r\n"
for i in {1..10}; do CMD="${CMD}JOIN #ch$i\r\n"; done
echo -e "$CMD" | nc -c localhost $PORT >/dev/null
test_alive "Many channels (10)"
stop

# Test 12: UTF-8 in topic
start
echo -e "PASS $PASSWORD\r\nNICK t12\r\nUSER t12 0 * :тест\r\nJOIN #t\r\nTOPIC #t :Привет 🌍\r\n" | nc -c localhost $PORT >/dev/null
test_alive "UTF-8 support"
stop

# Test 13: Binary data
start
echo -e "PASS $PASSWORD\r\nNICK t13\r\nUSER t13 0 * :t\r\nJOIN #t\r\nPRIVMSG #t :\x00\x01\x02\r\n" | nc -c localhost $PORT >/dev/null
test_alive "Binary data"
stop

# Test 14: LF only (no CR)
start
printf "PASS $PASSWORD\nNICK t14\nUSER t14 0 * :t\n" | nc -c localhost $PORT >/dev/null
test_alive "LF-only lines"
stop

# Test 15: Channel limit
start
{ echo -e "PASS $PASSWORD\r\nNICK owner\r\nUSER o 0 * :o\r\nJOIN #lim\r\nMODE #lim +l 1\r\n"; sleep 1; } | nc localhost $PORT >/dev/null &
BG=$!
sleep 0.2
test_cmd "Channel limit" "PASS $PASSWORD\r\nNICK guest\r\nUSER g 0 * :g\r\nJOIN #lim\r\n" "471"
kill $BG 2>/dev/null
stop

# Test 16: Channel key
start
{ echo -e "PASS $PASSWORD\r\nNICK owner16\r\nUSER o 0 * :o\r\nJOIN #key\r\nMODE #key +k secret\r\n"; sleep 1; } | nc localhost $PORT >/dev/null &
BG=$!
sleep 0.2
test_cmd "Wrong key rejected" "PASS $PASSWORD\r\nNICK guest16\r\nUSER g 0 * :g\r\nJOIN #key wrong\r\n" "475"
kill $BG 2>/dev/null
stop

# Test 17: Invite-only
start
{ echo -e "PASS $PASSWORD\r\nNICK owner17\r\nUSER o 0 * :o\r\nJOIN #inv\r\nMODE #inv +i\r\n"; sleep 1; } | nc localhost $PORT >/dev/null &
BG=$!
sleep 0.2
test_cmd "Invite-only enforced" "PASS $PASSWORD\r\nNICK guest17\r\nUSER g 0 * :g\r\nJOIN #inv\r\n" "473"
kill $BG 2>/dev/null
stop

# Test 18: Partial command
start
{ echo -n "PASS "; sleep 0.1; } | nc localhost $PORT >/dev/null
test_alive "Partial command"
stop

echo ""
echo "=================="
echo "Results: $PASSED/$TOTAL"
[ $PASSED -eq $TOTAL ] && echo "All passed!" || echo "Some failed"
