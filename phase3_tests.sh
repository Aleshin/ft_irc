#!/bin/bash
# Phase 3 Tests: Client Registration (PASS, NICK, USER)

PORT=6699
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

start_server() {
    ./ircserv $PORT $PASS > "$TMPDIR/srv.log" 2>&1 &
    SERVER_PID=$!
    sleep 0.5
}

stop_server() {
    [ -n "$SERVER_PID" ] && kill $SERVER_PID 2>/dev/null
    wait $SERVER_PID 2>/dev/null
    SERVER_PID=""
    sleep 0.3
}

# Send commands and capture response to file
send_and_receive() {
    local input="$1"
    local timeout="${2:-2}"
    local outfile="$TMPDIR/out_$RANDOM.txt"
    
    # Use printf -v and $'...' style or echo -e for proper escape handling
    { printf '%b' "$input"; sleep $timeout; } | nc localhost $PORT > "$outfile" 2>&1 &
    local nc_pid=$!
    sleep $((timeout + 1))
    kill $nc_pid 2>/dev/null
    wait $nc_pid 2>/dev/null
    cat "$outfile"
}

run_test() {
    local name="$1"
    local expected="$2"
    local actual="$3"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    # Find the matching line for display
    local matched_line=$(echo "$actual" | grep "$expected" | head -1)
    
    if [ -n "$matched_line" ]; then
        echo -e "${GREEN}✓${NC} $name"
        echo "  → $matched_line"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $name"
        echo "  Expected: $expected"
        echo "  Got: $(echo "$actual" | head -1)"
        return 1
    fi
}

run_test_not() {
    local name="$1"
    local not_expected="$2"
    local actual="$3"
    
    TESTS_TOTAL=$((TESTS_TOTAL + 1))
    
    if ! echo "$actual" | grep -q "$not_expected"; then
        echo -e "${GREEN}✓${NC} $name"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $name"
        echo "  Should NOT contain: $not_expected"
        return 1
    fi
}

echo "=========================================="
echo "Phase 3: Client Registration Tests"
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

# Test 1: Full registration sequence
echo -e "${YELLOW}Test 1: Full registration (PASS+NICK+USER)${NC}"
start_server
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK alice\r\nUSER alice 0 * :Alice Test\r\n" 2)
run_test "RPL_WELCOME (001)" "001 alice" "$OUTPUT"
run_test "RPL_YOURHOST (002)" "002 alice" "$OUTPUT"
run_test "RPL_CREATED (003)" "003 alice" "$OUTPUT"
run_test "RPL_MYINFO (004)" "004 alice" "$OUTPUT"
run_test "Full prefix format" "alice!alice@" "$OUTPUT"
stop_server

# Test 2: Wrong password
echo ""
echo -e "${YELLOW}Test 2: Wrong password${NC}"
start_server
OUTPUT=$(send_and_receive "PASS wrongpass\r\nNICK bob\r\nUSER bob 0 * :Bob\r\n" 2)
run_test "ERR_PASSWDMISMATCH (464)" "464" "$OUTPUT"
stop_server

# Test 3: Missing password
echo ""
echo -e "${YELLOW}Test 3: Registration without PASS${NC}"
start_server
OUTPUT=$(send_and_receive "NICK charlie\r\nUSER charlie 0 * :Charlie\r\n" 2)
run_test_not "No welcome without password" "001" "$OUTPUT"
stop_server

# Test 4: Nick collision  
echo ""
echo -e "${YELLOW}Test 4: Duplicate nickname${NC}"
start_server
# First client registers in background
send_and_receive "PASS $PASS\r\nNICK david\r\nUSER david 0 * :David\r\n" 3 > /dev/null &
sleep 1.5
# Second client tries same nick
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK david\r\nUSER david2 0 * :David2\r\n" 2)
run_test "ERR_NICKNAMEINUSE (433)" "433" "$OUTPUT"
stop_server

# Test 5: Invalid nickname (starts with number)
echo ""
echo -e "${YELLOW}Test 5: Invalid nickname${NC}"
start_server
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK 123invalid\r\n" 2)
run_test "ERR_ERRONEUSNICKNAME (432)" "432" "$OUTPUT"
stop_server

# Test 6: Nickname change after registration
echo ""
echo -e "${YELLOW}Test 6: Nickname change${NC}"
start_server
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK eve\r\nUSER eve 0 * :Eve\r\nNICK eve_new\r\n" 2)
run_test "NICK change confirmation" "NICK" "$OUTPUT"
stop_server

# Test 7: PASS after registration
echo ""
echo -e "${YELLOW}Test 7: PASS after registration${NC}"
start_server
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK frank\r\nUSER frank 0 * :Frank\r\nPASS $PASS\r\n" 2)
run_test "ERR_ALREADYREGISTERED (462)" "462" "$OUTPUT"
stop_server

# Test 8: USER command with realname
echo ""
echo -e "${YELLOW}Test 8: USER command with realname${NC}"
start_server
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK grace\r\nUSER grace 0 * :Grace Hopper\r\n" 2)
run_test "Welcome with username" "001 grace" "$OUTPUT"
stop_server

# Test 9: Missing USER params
echo ""
echo -e "${YELLOW}Test 9: USER with missing params${NC}"
start_server
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK henry\r\nUSER henry\r\n" 2)
run_test "ERR_NEEDMOREPARAMS (461)" "461" "$OUTPUT"
stop_server

# Test 10: Order independence (USER before NICK)
echo ""
echo -e "${YELLOW}Test 10: USER before NICK (order test)${NC}"
start_server
OUTPUT=$(send_and_receive "PASS $PASS\r\nUSER ivan 0 * :Ivan\r\nNICK ivan\r\n" 2)
run_test "Registration with USER first" "001 ivan" "$OUTPUT"
stop_server

# Summary
echo ""
echo "=========================================="
echo -e "Results: ${GREEN}$TESTS_PASSED${NC}/${TESTS_TOTAL} tests passed"
echo "=========================================="

if [ $TESTS_PASSED -eq $TESTS_TOTAL ]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${YELLOW}Some tests failed - this is expected during development${NC}"
    exit 1
fi
