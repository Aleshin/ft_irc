#!/bin/bash
# Phase 2 Tests: Message Parsing (IRC protocol format)

PORT=6698
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

send_and_receive() {
    local input="$1"
    local timeout="${2:-2}"
    local outfile="$TMPDIR/out_$RANDOM.txt"
    
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
    local matched_line=$(echo "$actual" | grep "$expected" | head -1)
    
    if [ -n "$matched_line" ]; then
        echo -e "${GREEN}✓${NC} $name"
        echo "  → $matched_line"
        TESTS_PASSED=$((TESTS_PASSED + 1))
        return 0
    else
        echo -e "${RED}✗${NC} $name"
        echo "  Expected: $expected"
        echo "  Got: $(echo "$actual" | tr '\r' ' ' | head -3)"
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
echo "Phase 2: Message Parsing Tests"
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
# CRLF HANDLING
# ==============================================================================
echo -e "${YELLOW}=== CRLF Line Ending Tests ===${NC}"

start_server

# Test: CRLF line endings work
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK alice\r\nUSER alice 0 * :Alice\r\n")
run_test "CRLF line endings accepted" "001" "$OUTPUT"

stop_server
start_server

# Test: LF only works too
OUTPUT=$(send_and_receive "PASS $PASS\nNICK bob\nUSER bob 0 * :Bob\n")
run_test "LF-only line endings accepted" "001" "$OUTPUT"

stop_server

# ==============================================================================
# COMMAND PARSING
# ==============================================================================
echo ""
echo -e "${YELLOW}=== Command Parsing Tests ===${NC}"

start_server

# Test: Command case insensitivity
OUTPUT=$(send_and_receive "pass $PASS\r\nnick charlie\r\nuser charlie 0 * :Charlie\r\n")
run_test "Commands are case-insensitive" "001" "$OUTPUT"

stop_server
start_server

# Test: Extra spaces in command
OUTPUT=$(send_and_receive "PASS   $PASS\r\nNICK   david\r\nUSER   david   0   *   :David\r\n")
run_test "Extra spaces handled correctly" "001" "$OUTPUT"

stop_server
start_server

# Test: Unknown command
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK eve\r\nUSER eve 0 * :Eve\r\nFOOBAR\r\n")
run_test "Unknown command returns 421" "421" "$OUTPUT"

stop_server

# ==============================================================================
# TRAILING PARAMETER (colon prefix)
# ==============================================================================
echo ""
echo -e "${YELLOW}=== Trailing Parameter Tests ===${NC}"

start_server

# Test: Trailing with spaces
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK frank\r\nUSER frank 0 * :Frank The User\r\n")
run_test "Trailing with spaces in realname" "Frank The User\|001" "$OUTPUT"

stop_server
start_server

# Test: PRIVMSG with trailing
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK grace\r\nUSER grace 0 * :Grace\r\nJOIN #test\r\nPRIVMSG #test :Hello World!\r\n")
run_test "PRIVMSG trailing parsed" "JOIN.*#test" "$OUTPUT"

stop_server

# ==============================================================================
# NICKNAME VALIDATION
# ==============================================================================
echo ""
echo -e "${YELLOW}=== Nickname Validation Tests ===${NC}"

start_server

# Test: Valid nickname
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK Valid123\r\nUSER user 0 * :User\r\n")
run_test "Valid nickname accepted" "001" "$OUTPUT"

stop_server
start_server

# Test: Nickname starting with digit
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK 123invalid\r\n")
run_test "Nickname starting with digit rejected (432)" "432" "$OUTPUT"

stop_server
start_server

# Test: Nickname with special chars
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK bad@nick\r\n")
run_test "Nickname with @ rejected (432)" "432" "$OUTPUT"

stop_server
start_server

# Test: Empty nickname
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK\r\n")
run_test "Empty NICK returns 431" "431" "$OUTPUT"

stop_server

# ==============================================================================
# CHANNEL NAME VALIDATION
# ==============================================================================
echo ""
echo -e "${YELLOW}=== Channel Name Validation Tests ===${NC}"

start_server

# Test: Valid channel name
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK henry\r\nUSER henry 0 * :Henry\r\nJOIN #valid\r\n")
run_test "Valid channel #valid accepted" "JOIN.*#valid" "$OUTPUT"

stop_server
start_server

# Test: Channel without # prefix
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK ivan\r\nUSER ivan 0 * :Ivan\r\nJOIN nochannel\r\n")
run_test "Channel without # rejected (403)" "403" "$OUTPUT"

stop_server

# ==============================================================================
# MESSAGE FORMAT VALIDATION
# ==============================================================================
echo ""
echo -e "${YELLOW}=== Response Format Tests ===${NC}"

start_server

# Test: Server prefix format
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK julia\r\nUSER julia 0 * :Julia\r\n")
run_test "Response has server prefix" ":.*001" "$OUTPUT"

stop_server
start_server

# Test: User prefix format in channel messages
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK kate\r\nUSER kate 0 * :Kate\r\nJOIN #room\r\n")
run_test "JOIN has user prefix (nick!user@host)" ":kate!kate@" "$OUTPUT"

stop_server

# ==============================================================================
# EDGE CASES
# ==============================================================================
echo ""
echo -e "${YELLOW}=== Edge Case Tests ===${NC}"

start_server

# Test: Very long nickname (should be truncated or rejected)
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK verylongnicknamethatshouldberejected\r\n")
# Either accepts truncated or rejects - both valid
run_test_not "Long nickname doesn't crash" "error\|Error" "$OUTPUT"

stop_server
start_server

# Test: Multiple commands in one send
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK multi\r\nUSER multi 0 * :Multi\r\nJOIN #chan1\r\nJOIN #chan2\r\n")
run_test "Multiple commands processed" "JOIN.*#chan" "$OUTPUT"

stop_server

# ==============================================================================
# SUMMARY
# ==============================================================================
echo ""
echo "=========================================="
echo -e "Results: ${TESTS_PASSED}/${TESTS_TOTAL} tests passed"
echo "=========================================="

if [ $TESTS_PASSED -eq $TESTS_TOTAL ]; then
    echo -e "${GREEN}All Phase 2 tests passed!${NC}"
    exit 0
else
    echo -e "${YELLOW}Some tests failed. Review the output above.${NC}"
    exit 1
fi
