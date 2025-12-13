#!/bin/bash
# Phase 4 Tests: Channels and Messages (JOIN, PART, PRIVMSG)

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
echo "Phase 4: Channels and Messages Tests"
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

# Test 1: JOIN a channel
echo -e "${YELLOW}Test 1: JOIN a channel${NC}"
start_server
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK alice\r\nUSER alice 0 * :Alice\r\nJOIN #test\r\n" 2)
run_test "JOIN message echoed" "JOIN" "$OUTPUT"
run_test "RPL_NAMREPLY (353)" "353" "$OUTPUT"
run_test "RPL_ENDOFNAMES (366)" "366" "$OUTPUT"
run_test "User in names list" "alice" "$OUTPUT"
stop_server

# Test 2: JOIN without registration
echo ""
echo -e "${YELLOW}Test 2: JOIN without registration${NC}"
start_server
OUTPUT=$(send_and_receive "JOIN #test\r\n" 2)
run_test "ERR_NOTREGISTERED (451)" "451" "$OUTPUT"
stop_server

# Test 3: JOIN with invalid channel name
echo ""
echo -e "${YELLOW}Test 3: Invalid channel name${NC}"
start_server
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK bob\r\nUSER bob 0 * :Bob\r\nJOIN nochannel\r\n" 2)
run_test "ERR_NOSUCHCHANNEL (403)" "403" "$OUTPUT"
stop_server

# Test 4: PART from channel
echo ""
echo -e "${YELLOW}Test 4: PART from channel${NC}"
start_server
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK charlie\r\nUSER charlie 0 * :Charlie\r\nJOIN #test\r\nPART #test :Goodbye\r\n" 2)
run_test "PART message" "PART" "$OUTPUT"
stop_server

# Test 5: PART from channel not on
echo ""
echo -e "${YELLOW}Test 5: PART from channel not on${NC}"
start_server
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK david\r\nUSER david 0 * :David\r\nPART #nochan\r\n" 2)
run_test "ERR_NOSUCHCHANNEL (403)" "403" "$OUTPUT"
stop_server

# Test 6: PRIVMSG to channel
echo ""
echo -e "${YELLOW}Test 6: PRIVMSG to channel (self-test)${NC}"
start_server
# Two clients: one joins and sends, we check sender doesn't get own message
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK eve\r\nUSER eve 0 * :Eve\r\nJOIN #chat\r\nPRIVMSG #chat :Hello world\r\n" 2)
run_test "JOIN successful" "JOIN" "$OUTPUT"
# Sender should NOT receive their own PRIVMSG
run_test_not "Sender doesn't get own PRIVMSG" "PRIVMSG #chat :Hello world" "$OUTPUT"
stop_server

# Test 7: PRIVMSG to user
echo ""
echo -e "${YELLOW}Test 7: PRIVMSG to user${NC}"
start_server
# Start receiver in background
{ printf 'PASS %s\r\nNICK frank\r\nUSER frank 0 * :Frank\r\n' "$PASS"; sleep 3; } | nc localhost $PORT > "$TMPDIR/frank.txt" 2>&1 &
FRANK_PID=$!
sleep 1
# Send message from grace to frank
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK grace\r\nUSER grace 0 * :Grace\r\nPRIVMSG frank :Hello Frank!\r\n" 2)
sleep 1
kill $FRANK_PID 2>/dev/null
wait $FRANK_PID 2>/dev/null
FRANK_OUTPUT=$(cat "$TMPDIR/frank.txt")
run_test "PRIVMSG received by target" "PRIVMSG frank :Hello Frank" "$FRANK_OUTPUT"
stop_server

# Test 8: PRIVMSG to non-existent user
echo ""
echo -e "${YELLOW}Test 8: PRIVMSG to non-existent user${NC}"
start_server
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK henry\r\nUSER henry 0 * :Henry\r\nPRIVMSG nobody :Hello?\r\n" 2)
run_test "ERR_NOSUCHNICK (401)" "401" "$OUTPUT"
stop_server

# Test 9: PRIVMSG to channel not member of
echo ""
echo -e "${YELLOW}Test 9: PRIVMSG to channel not member of${NC}"
start_server
# First create the channel
{ printf 'PASS %s\r\nNICK ivan\r\nUSER ivan 0 * :Ivan\r\nJOIN #private\r\n' "$PASS"; sleep 3; } | nc localhost $PORT > /dev/null 2>&1 &
IVAN_PID=$!
sleep 1
# Try to send without joining
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK julia\r\nUSER julia 0 * :Julia\r\nPRIVMSG #private :Sneaky\r\n" 2)
kill $IVAN_PID 2>/dev/null
run_test "ERR_CANNOTSENDTOCHAN (404)" "404" "$OUTPUT"
stop_server

# Test 10: First user becomes operator
echo ""
echo -e "${YELLOW}Test 10: First user is operator${NC}"
start_server
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK kate\r\nUSER kate 0 * :Kate\r\nJOIN #newchan\r\n" 2)
run_test "Operator prefix (@) in names" "@kate" "$OUTPUT"
stop_server

# Test 11: Channel message broadcast
echo ""
echo -e "${YELLOW}Test 11: Channel message broadcast${NC}"
start_server
# First user joins
{ printf 'PASS %s\r\nNICK larry\r\nUSER larry 0 * :Larry\r\nJOIN #room\r\n' "$PASS"; sleep 4; } | nc localhost $PORT > "$TMPDIR/larry.txt" 2>&1 &
LARRY_PID=$!
sleep 1
# Second user joins and sends message
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK mike\r\nUSER mike 0 * :Mike\r\nJOIN #room\r\nPRIVMSG #room :Hi everyone\r\n" 3)
sleep 1
kill $LARRY_PID 2>/dev/null
wait $LARRY_PID 2>/dev/null
LARRY_OUTPUT=$(cat "$TMPDIR/larry.txt")
run_test "Larry receives mike's JOIN" "mike.*JOIN" "$LARRY_OUTPUT"
run_test "Larry receives message" "PRIVMSG #room :Hi everyone" "$LARRY_OUTPUT"
stop_server

# Test 12: JOIN without params
echo ""
echo -e "${YELLOW}Test 12: JOIN without params${NC}"
start_server
OUTPUT=$(send_and_receive "PASS $PASS\r\nNICK nancy\r\nUSER nancy 0 * :Nancy\r\nJOIN\r\n" 2)
run_test "ERR_NEEDMOREPARAMS (461)" "461" "$OUTPUT"
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
    echo -e "${YELLOW}Some tests failed${NC}"
    exit 1
fi
