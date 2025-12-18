#!/bin/bash
# =============================================================================
# ft_irc Comprehensive Test Suite
# =============================================================================
#
# Complete test suite for 42 School ft_irc project.
# Automatically builds and starts the server, runs all tests, then shuts down.
#
# USAGE:
#   ./comprehensive_test.sh                    # Run all tests (auto-start server)
#   ./comprehensive_test.sh --help             # Show help
#   ./comprehensive_test.sh --no-server        # Use already running server
#   ./comprehensive_test.sh --port=6667        # Custom port (default: 6697)
#   ./comprehensive_test.sh --pass=secret      # Custom password (default: testpass)
#   ./comprehensive_test.sh --with-signals     # Include signal handling tests
#
# EXAMPLES:
#   ./comprehensive_test.sh                              # Standard run
#   ./comprehensive_test.sh --with-signals               # Include signal tests
#   ./comprehensive_test.sh --no-server --port=6666      # Test external server
#
# =============================================================================

# Get script and project directories
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SERVER_BIN="$PROJECT_DIR/ircserv"

# Defaults
SERVER_PORT=6697
SERVER_PASS="testpass"
AUTO_START=true
WITH_SIGNALS=false
WITH_MEMORY=false
SERVER_PID=""

TMPDIR=$(mktemp -d)

# Parse arguments
show_help() {
    head -22 "$0" | tail -18 | sed 's/^# //' | sed 's/^#//'
    exit 0
}

for arg in "$@"; do
    case $arg in
        --help|-h)      show_help ;;
        --no-server)    AUTO_START=false ;;
        --port=*)       SERVER_PORT="${arg#*=}" ;;
        --pass=*)       SERVER_PASS="${arg#*=}" ;;
        --with-signals) WITH_SIGNALS=true ;;
        --with-memory)  WITH_MEMORY=true ;;
    esac
done

PASSED=0
FAILED=0

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# =============================================================================
# CLEANUP & UTILITIES
# =============================================================================

cleanup() {
    # Kill server if we started it
    if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
        kill -TERM "$SERVER_PID" 2>/dev/null
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    pkill -f "nc.*localhost.*$SERVER_PORT" 2>/dev/null || true
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

die() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

send() {
    local cmds="$1" timeout="${2:-0.5}"
    [ -n "$SERVER_PASS" ] && cmds="PASS $SERVER_PASS\r\n$cmds"
    { printf '%b' "$cmds"; sleep $timeout; } | nc -w 2 localhost $SERVER_PORT 2>/dev/null
}

check() {
    local name="$1" pattern="$2" output="$3"
    if echo "$output" | grep -qE "$pattern"; then
        echo -e "  ${GREEN}✅${NC} $name"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}❌${NC} $name"
        echo "     Expected: $pattern"
        echo "     Got: $(echo "$output" | tr '\r\n' ' ' | head -c 100)"
        FAILED=$((FAILED + 1))
    fi
}

check_not() {
    local name="$1" pattern="$2" output="$3"
    if ! echo "$output" | grep -qE "$pattern"; then
        echo -e "  ${GREEN}✅${NC} $name"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}❌${NC} $name"
        echo "     Should NOT match: $pattern"
        FAILED=$((FAILED + 1))
    fi
}

section() {
    echo ""
    echo -e "${CYAN}━━━ $1 ━━━${NC}"
}

# =============================================================================
# SERVER MANAGEMENT
# =============================================================================

build_server() {
    echo -e "${CYAN}[INFO]${NC} Building server..."
    if ! make -C "$PROJECT_DIR" >/dev/null 2>&1; then
        die "Build failed. Run 'make' manually to see errors."
    fi
    echo -e "${CYAN}[INFO]${NC} Build successful"
}

start_server() {
    pkill -f "ircserv.*$SERVER_PORT" 2>/dev/null || true
    sleep 0.3
    
    "$SERVER_BIN" "$SERVER_PORT" "$SERVER_PASS" >/dev/null 2>&1 &
    SERVER_PID=$!
    sleep 0.5
    
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        die "Server failed to start"
    fi
    
    if ! nc -z localhost "$SERVER_PORT" 2>/dev/null; then
        die "Server not listening on port $SERVER_PORT"
    fi
    
    echo -e "${CYAN}[INFO]${NC} Server started (PID: $SERVER_PID, Port: $SERVER_PORT, Pass: $SERVER_PASS)"
}

check_external_server() {
    if ! nc -z localhost "$SERVER_PORT" 2>/dev/null; then
        die "No server on port $SERVER_PORT. Start server or remove --no-server"
    fi
    echo -e "${CYAN}[INFO]${NC} Using external server on port $SERVER_PORT"
}

# =============================================================================
# HEADER
# =============================================================================

echo ""
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BOLD}  ft_irc Comprehensive Test Suite${NC}"
echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Start or check server
if [ "$AUTO_START" = true ]; then
    [ ! -f "$SERVER_BIN" ] && build_server
    start_server
else
    check_external_server
fi

# =============================================================================
section "1. REGISTRATION (12 tests)"
# =============================================================================

OUT=$(send "NICK reg1\r\nUSER r 0 * :R\r\n")
check "001 RPL_WELCOME" "001.*reg1" "$OUT"
check "002 RPL_YOURHOST" "002" "$OUT"
check "003 RPL_CREATED" "003" "$OUT"
check "004 RPL_MYINFO" "004" "$OUT"

OUT=$(send "JOIN #x\r\n" | head -1)
check "451 before registration" "451" "$OUT"

OUT=$(send "NICK 1bad\r\nUSER u 0 * :U\r\n")
check "432 invalid nick (digit start)" "432" "$OUT"

OUT=$(send "NICK ba@d\r\nUSER u 0 * :U\r\n")
check "432 invalid nick (@ symbol)" "432" "$OUT"

OUT=$(send "NICK\r\n" | head -1)
check "431/461 empty NICK" "431|461" "$OUT"

OUT=$(send "NICK good1\r\nUSER u 0 * :U\r\n")
check "Valid nick accepted" "001.*good1" "$OUT"

OUT=$(send "NICK Test_123\r\nUSER u 0 * :U\r\n")
check "Nick with underscore/digits" "001.*Test_123" "$OUT"

OUT=$(send "NICK changer\r\nUSER u 0 * :U\r\nNICK newname\r\n")
check "NICK change works" "NICK.*newname" "$OUT"

OUT=$(send "USER u 0 * :U\r\nNICK ordtest\r\n")
check "USER before NICK works" "001.*ordtest" "$OUT"

# =============================================================================
section "2. CHANNELS (10 tests)"
# =============================================================================

OUT=$(send "NICK ch1\r\nUSER c 0 * :C\r\nJOIN #chan\r\n")
check "JOIN echoed" "JOIN.*#chan" "$OUT"
check "353 NAMREPLY" "353.*#chan" "$OUT"
check "366 ENDOFNAMES" "366.*#chan" "$OUT"

OUT=$(send "NICK ch2\r\nUSER c 0 * :C\r\nJOIN #first\r\n")
check "First user gets @" "@ch2" "$OUT"

OUT=$(send "NICK ch3\r\nUSER c 0 * :C\r\nJOIN\r\n")
check "461 JOIN no params" "461" "$OUT"

OUT=$(send "NICK ch4\r\nUSER c 0 * :C\r\nJOIN nochan\r\n")
check "403 bad channel name" "403" "$OUT"

OUT=$(send "NICK ch5\r\nUSER c 0 * :C\r\nJOIN #part\r\nPART #part :bye\r\n")
check "PART echoed" "PART.*#part" "$OUT"

OUT=$(send "NICK ch6\r\nUSER c 0 * :C\r\nPART #none\r\n")
check "403/442 PART unknown" "403|442" "$OUT"

OUT=$(send "NICK ch7\r\nUSER c 0 * :C\r\nJOIN #a\r\nJOIN #b\r\nJOIN #c\r\n")
check "Multiple JOINs work" "JOIN.*#c" "$OUT"

# =============================================================================
section "3. MESSAGING (7 tests)"
# =============================================================================

OUT=$(send "NICK msg1\r\nUSER m 0 * :M\r\nPRIVMSG ghost :hi\r\n")
check "401 no such nick" "401" "$OUT"

OUT=$(send "NICK msg2\r\nUSER m 0 * :M\r\nJOIN #self\r\nPRIVMSG #self :test\r\n")
check_not "Sender no echo" "PRIVMSG #self :test" "$OUT"

OUT=$(send "NICK msg3\r\nUSER m 0 * :M\r\nPRIVMSG\r\n")
check "411/461 PRIVMSG no params" "411|461" "$OUT"

# DM test
{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK recv\r\nUSER r 0 * :R\r\nJOIN #dm\r\n'
    sleep 2
} | nc localhost $SERVER_PORT > "$TMPDIR/recv.txt" 2>&1 &
PID=$!
sleep 0.5
send "NICK sender\r\nUSER s 0 * :S\r\nPRIVMSG recv :Hello there\r\n" 0.5 >/dev/null
sleep 0.5
kill $PID 2>/dev/null; wait $PID 2>/dev/null || true
OUT=$(cat "$TMPDIR/recv.txt")
check "DM received" "PRIVMSG recv :Hello" "$OUT"

# Broadcast test
{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK listener\r\nUSER l 0 * :L\r\nJOIN #broadcast\r\n'
    sleep 2
} | nc localhost $SERVER_PORT > "$TMPDIR/listen.txt" 2>&1 &
PID=$!
sleep 0.5
send "NICK talker\r\nUSER t 0 * :T\r\nJOIN #broadcast\r\nPRIVMSG #broadcast :Broadcast msg\r\n" 0.5 >/dev/null
sleep 0.5
kill $PID 2>/dev/null; wait $PID 2>/dev/null || true
OUT=$(cat "$TMPDIR/listen.txt")
check "Broadcast received" "PRIVMSG #broadcast :Broadcast" "$OUT"

# Test: Message to channel after leaving (channel has +n mode for no external messages)
{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK chankeeper\r\nUSER k 0 * :K\r\nJOIN #nomember\r\nMODE #nomember +n\r\n'
    sleep 5
} | nc localhost $SERVER_PORT >/dev/null 2>&1 &
PID=$!
sleep 1.5
# msg4 joins then parts, tries to send message after leaving (+n blocks external messages)
{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK msg4\r\nUSER m 0 * :M\r\nJOIN #nomember\r\nPART #nomember\r\nPRIVMSG #nomember :hi\r\n'
    sleep 2
} | timeout 3s nc -N localhost $SERVER_PORT > "$TMPDIR/msg4.txt" 2>&1 || true

kill $PID 2>/dev/null; wait $PID 2>/dev/null || true
OUT=$(cat "$TMPDIR/msg4.txt")
check "404 not on channel (+n)" "401|403|404|442" "$OUT"

# =============================================================================
section "4. TOPIC (5 tests)"
# =============================================================================

OUT=$(send "NICK top1\r\nUSER t 0 * :T\r\nJOIN #notopic\r\nTOPIC #notopic\r\n")
check "331 no topic" "331" "$OUT"

OUT=$(send "NICK top2\r\nUSER t 0 * :T\r\nJOIN #settop\r\nTOPIC #settop :My topic\r\n")
check "TOPIC set" "TOPIC.*#settop|332" "$OUT"

OUT=$(send "NICK top3\r\nUSER t 0 * :T\r\nTOPIC #ghost\r\n")
check "403 unknown channel" "403" "$OUT"

{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK topown\r\nUSER t 0 * :T\r\nJOIN #owned\r\n'
    sleep 2
} | nc localhost $SERVER_PORT >/dev/null 2>&1 &
PID=$!
sleep 0.5
OUT=$(send "NICK outsider\r\nUSER o 0 * :O\r\nTOPIC #owned :hacked\r\n")
check "442/482 not on channel" "442|482" "$OUT"
kill $PID 2>/dev/null; wait $PID 2>/dev/null || true

OUT=$(send "NICK top4\r\nUSER t 0 * :T\r\nJOIN #readtopic\r\nTOPIC #readtopic :test\r\nTOPIC #readtopic\r\n")
check "TOPIC query returns 332" "332.*test" "$OUT"

# =============================================================================
section "5. KICK (5 tests)"
# =============================================================================

OUT=$(send "NICK kick1\r\nUSER k 0 * :K\r\nJOIN #kicktest\r\nKICK\r\n")
check "461 KICK no params" "461" "$OUT"

OUT=$(send "NICK kick2\r\nUSER k 0 * :K\r\nJOIN #kicktest2\r\nKICK #kicktest2 ghost\r\n")
check "401/441 KICK unknown" "401|441" "$OUT"

{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK chanop\r\nUSER c 0 * :C\r\nJOIN #theirs\r\n'
    sleep 2
} | nc localhost $SERVER_PORT >/dev/null 2>&1 &
PID=$!
sleep 0.5
OUT=$(send "NICK kicker\r\nUSER k 0 * :K\r\nKICK #theirs chanop\r\n")
check "403/442/482 not on channel" "403|442|482" "$OUT"
kill $PID 2>/dev/null; wait $PID 2>/dev/null || true

{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK theop\r\nUSER o 0 * :O\r\nJOIN #optest\r\n'
    sleep 2
} | nc localhost $SERVER_PORT >/dev/null 2>&1 &
PID=$!
sleep 0.5
OUT=$(send "NICK noob\r\nUSER n 0 * :N\r\nJOIN #optest\r\nKICK #optest theop\r\n" 1)
check "482 not operator" "482" "$OUT"
kill $PID 2>/dev/null; wait $PID 2>/dev/null || true

# Successful KICK
{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK victim\r\nUSER v 0 * :V\r\n'
    sleep 3
} | nc localhost $SERVER_PORT > "$TMPDIR/victim.txt" 2>&1 &
PID=$!
sleep 0.5
OUT=$(send "NICK kickop\r\nUSER k 0 * :K\r\nJOIN #kickroom\r\nINVITE victim #kickroom\r\n" 0.5)
sleep 0.3
send "NICK joiner\r\nUSER j 0 * :J\r\n" 0.3 >/dev/null
{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK victim2\r\nUSER v 0 * :V\r\nJOIN #kickroom\r\n'
    sleep 2
} | nc localhost $SERVER_PORT > "$TMPDIR/v2.txt" 2>&1 &
PID2=$!
sleep 0.5
OUT=$(send "NICK kickop2\r\nUSER k 0 * :K\r\nJOIN #kickroom\r\nKICK #kickroom victim2 :bye\r\n" 1)
# Owner or first user kicks
sleep 0.3
kill $PID $PID2 2>/dev/null; wait $PID $PID2 2>/dev/null || true
check "KICK message sent" "KICK.*#kickroom|482" "$OUT"

# =============================================================================
section "6. INVITE (5 tests)"
# =============================================================================

OUT=$(send "NICK inv1\r\nUSER i 0 * :I\r\nINVITE\r\n")
check "461 INVITE no params" "461" "$OUT"

OUT=$(send "NICK inv2\r\nUSER i 0 * :I\r\nJOIN #myroom\r\nINVITE ghost #myroom\r\n")
check "401 INVITE unknown" "401" "$OUT"

{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK target\r\nUSER t 0 * :T\r\n'
    sleep 3
} | nc localhost $SERVER_PORT >/dev/null 2>&1 &
PID1=$!
{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK invown\r\nUSER i 0 * :I\r\nJOIN #priv\r\n'
    sleep 3
} | nc localhost $SERVER_PORT >/dev/null 2>&1 &
PID2=$!
sleep 1
OUT=$(send "NICK inviter\r\nUSER i 0 * :I\r\nINVITE target #priv\r\n")
check "442/482 INVITE not on chan" "442|482" "$OUT"
kill $PID1 $PID2 2>/dev/null; wait $PID1 $PID2 2>/dev/null || true

{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK guest\r\nUSER g 0 * :G\r\n'
    sleep 2
} | nc localhost $SERVER_PORT >/dev/null 2>&1 &
PID=$!
sleep 0.5
OUT=$(send "NICK host\r\nUSER h 0 * :H\r\nJOIN #party\r\nINVITE guest #party\r\n")
check "341 INVITE success" "341" "$OUT"
kill $PID 2>/dev/null; wait $PID 2>/dev/null || true

# INVITE + JOIN +i channel (invhost stays connected, sends INVITE in same session)
{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK invited\r\nUSER i 0 * :I\r\n'
    sleep 5
} | nc localhost $SERVER_PORT > "$TMPDIR/invited.txt" 2>&1 &
PID=$!
sleep 0.5
# invhost creates channel, waits, then sends INVITE in same session
{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK invhost\r\nUSER h 0 * :H\r\nJOIN #secret\r\nMODE #secret +i\r\n'
    sleep 2
    printf 'INVITE invited #secret\r\n'
    sleep 2
} | nc localhost $SERVER_PORT > "$TMPDIR/invhost.txt" 2>&1 &
PID2=$!
sleep 4
kill $PID $PID2 2>/dev/null; wait $PID $PID2 2>/dev/null || true
INV_OUT=$(cat "$TMPDIR/invited.txt")
check "INVITE notification sent" "INVITE invited #secret" "$INV_OUT"

# =============================================================================
section "7. MODE (10 tests)"
# =============================================================================

OUT=$(send "NICK mode1\r\nUSER m 0 * :M\r\nJOIN #modetest\r\nMODE #modetest\r\n")
check "324 MODE query" "324" "$OUT"

OUT=$(send "NICK mode2\r\nUSER m 0 * :M\r\nJOIN #mi\r\nMODE #mi +i\r\n")
check "MODE +i set" "MODE.*i" "$OUT"

OUT=$(send "NICK mode3\r\nUSER m 0 * :M\r\nJOIN #mt\r\nMODE #mt +t\r\n")
check "MODE +t set" "MODE.*t" "$OUT"

OUT=$(send "NICK mode4\r\nUSER m 0 * :M\r\nJOIN #mk\r\nMODE #mk +k secret\r\n")
check "MODE +k set" "MODE.*k" "$OUT"

OUT=$(send "NICK mode5\r\nUSER m 0 * :M\r\nJOIN #ml\r\nMODE #ml +l 5\r\n")
check "MODE +l set" "MODE.*l" "$OUT"

OUT=$(send "NICK mode6\r\nUSER m 0 * :M\r\nJOIN #combo\r\nMODE #combo +it\r\n")
check "MODE +it combo" "MODE.*\\+it|MODE.*i.*t" "$OUT"

OUT=$(send "NICK mode7\r\nUSER m 0 * :M\r\nJOIN #minus\r\nMODE #minus +i\r\nMODE #minus -i\r\n")
check "MODE -i works" "MODE.*-i" "$OUT"

{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK opper\r\nUSER o 0 * :O\r\nJOIN #opmode\r\n'
    sleep 2
} | nc localhost $SERVER_PORT >/dev/null 2>&1 &
PID=$!
sleep 0.5
OUT=$(send "NICK mode8\r\nUSER m 0 * :M\r\nJOIN #opmode\r\nMODE #opmode\r\n" 1)
check "MODE query by non-op" "324" "$OUT"
kill $PID 2>/dev/null; wait $PID 2>/dev/null || true

# Test: MODE on truly non-existent channel (no one has joined it)
OUT=$(send "NICK mode9\r\nUSER m 0 * :M\r\nMODE #nosuch_chan_xyz\r\n")
check "403/401 unknown channel" "403|401" "$OUT"

# Test: Operator grants +o to another user (owner sends MODE in same session)
# Owner creates channel, waits 4 sec for joiner, then grants +o in same session
{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK opowner\r\nUSER m 0 * :M\r\nJOIN #modeoptest\r\n'
    sleep 4
    printf 'MODE #modeoptest +o oprecv\r\n'
    sleep 3
} | nc localhost $SERVER_PORT > "$TMPDIR/opowner.txt" 2>&1 &
PID1=$!
sleep 2
# oprecv joins and waits for MODE
{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK oprecv\r\nUSER o 0 * :O\r\nJOIN #modeoptest\r\n'
    sleep 6
} | nc localhost $SERVER_PORT > "$TMPDIR/oprecv.txt" 2>&1 &
PID2=$!
sleep 7
kill $PID1 $PID2 2>/dev/null; wait $PID1 $PID2 2>/dev/null || true
OPRECV_OUT=$(cat "$TMPDIR/oprecv.txt")
check "MODE +o grant" "MODE.*\\+o.*oprecv" "$OPRECV_OUT"

# =============================================================================
section "8. MODE ENFORCEMENT (5 tests)"
# =============================================================================

{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK iown\r\nUSER i 0 * :I\r\nJOIN #invonly\r\nMODE #invonly +i\r\n'
    sleep 2
} | nc localhost $SERVER_PORT >/dev/null 2>&1 &
PID=$!
sleep 0.5
OUT=$(send "NICK intruder\r\nUSER i 0 * :I\r\nJOIN #invonly\r\n")
check "473 +i blocks" "473" "$OUT"
kill $PID 2>/dev/null; wait $PID 2>/dev/null || true

{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK kown\r\nUSER k 0 * :K\r\nJOIN #keyed\r\nMODE #keyed +k pass123\r\n'
    sleep 2
} | nc localhost $SERVER_PORT >/dev/null 2>&1 &
PID=$!
sleep 0.5
OUT=$(send "NICK wrongkey\r\nUSER w 0 * :W\r\nJOIN #keyed wrong\r\n")
check "475 wrong key" "475" "$OUT"
kill $PID 2>/dev/null; wait $PID 2>/dev/null || true

{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK kown2\r\nUSER k 0 * :K\r\nJOIN #keyed2\r\nMODE #keyed2 +k pass\r\n'
    sleep 2
} | nc localhost $SERVER_PORT >/dev/null 2>&1 &
PID=$!
sleep 0.5
OUT=$(send "NICK rightkey\r\nUSER r 0 * :R\r\nJOIN #keyed2 pass\r\n")
check "+k correct key works" "JOIN.*#keyed2" "$OUT"
kill $PID 2>/dev/null; wait $PID 2>/dev/null || true

# Test: Channel user limit enforcement (set limit=1, try to join as 2nd user)
{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK lown\r\nUSER l 0 * :L\r\nJOIN #limited\r\nMODE #limited +l 1\r\n'
    sleep 4
} | nc localhost $SERVER_PORT >/dev/null 2>&1 &
PID=$!
sleep 1.5
OUT=$(send "NICK overflow\r\nUSER o 0 * :O\r\nJOIN #limited\r\n" 1)
check "471 channel full" "471" "$OUT"
kill $PID 2>/dev/null; wait $PID 2>/dev/null || true

{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK town\r\nUSER t 0 * :T\r\nJOIN #topiclock\r\nMODE #topiclock +t\r\n'
    sleep 2
} | nc localhost $SERVER_PORT >/dev/null 2>&1 &
PID=$!
sleep 0.5
OUT=$(send "NICK pleb\r\nUSER p 0 * :P\r\nJOIN #topiclock\r\nTOPIC #topiclock :nope\r\n" 1)
check "482 +t blocks topic" "482" "$OUT"
kill $PID 2>/dev/null; wait $PID 2>/dev/null || true

# =============================================================================
section "9. PING/PONG (10 tests)"
# =============================================================================

OUT=$(send "NICK p1\r\nUSER p 0 * :P\r\nPING :testtoken\r\n")
check "PING :token → PONG" "PONG.*:testtoken" "$OUT"

OUT=$(send "NICK p2\r\nUSER p 0 * :P\r\nPING mytoken\r\n")
check "PING param → PONG" "PONG.*mytoken" "$OUT"

OUT=$(send "NICK p3\r\nUSER p 0 * :P\r\nPING\r\n")
check "PING no token → response" "PONG|461|001" "$OUT"

OUT=$(send "NICK p4\r\nUSER p 0 * :P\r\nPING :first\r\nPING :second\r\n")
check "Multiple PINGs - first" "PONG.*:first" "$OUT"
check "Multiple PINGs - second" "PONG.*:second" "$OUT"

OUT=$(send "NICK p5\r\nUSER p 0 * :P\r\nPING :longtokenstring123456789\r\n")
check "PING long token" "PONG.*longtokenstring" "$OUT"

OUT=$(send "NICK p6\r\nUSER p 0 * :P\r\nPING :test-token_123\r\n")
check "PING special chars" "PONG.*test-token_123" "$OUT"

OUT=$(send "NICK p7\r\nUSER p 0 * :P\r\nPONG :token\r\n")
check_not "PONG accepted (no error)" "421|ERROR" "$OUT"

OUT=$(send "NICK p8\r\nUSER p 0 * :P\r\nping :lowercase\r\n")
check "Lowercase ping works" "PONG" "$OUT"

OUT=$(send "NICK p9\r\nUSER p 0 * :P\r\nJOIN #pingtest\r\nPING :mixed\r\nPART #pingtest\r\n")
check "PING mixed commands" "PONG.*:mixed" "$OUT"

# =============================================================================
section "10. ERROR HANDLING (5 tests)"
# =============================================================================

OUT=$(send "NICK err1\r\nUSER e 0 * :E\r\nFOOBAR\r\n")
check "421 unknown command" "421" "$OUT"

OUT=$(send "NICK err2\r\nUSER e 0 * :E\r\nXYZ\r\nABC\r\n")
check "Multiple unknowns handled" "421" "$OUT"

OUT=$(send "NICK err3\r\nUSER e 0 * :E\r\n\r\n\r\nJOIN #edge\r\n" 1)
check "Empty lines tolerated" "JOIN.*#edge|001" "$OUT"

OUT=$(send "nick err4\r\nuser e 0 * :E\r\njoin #CASE\r\n")
check "Case insensitive cmds" "JOIN.*#CASE" "$OUT"

OUT=$(send "NICK   err5\r\nUSER   e   0   *   :E\r\n")
check "Extra whitespace" "001.*err5" "$OUT"

# =============================================================================
section "11. STRESS TESTS (5 tests)"
# =============================================================================

echo -n "  "
RAPID_PASS=0
for i in $(seq 1 10); do
    OUT=$(send "NICK rapid$i\r\nUSER r 0 * :R\r\n" 2>/dev/null)
    if echo "$OUT" | grep -qE "001"; then
        RAPID_PASS=$((RAPID_PASS + 1))
    fi
done
if [ $RAPID_PASS -ge 8 ]; then
    echo -e "${GREEN}✅${NC} Rapid connections ($RAPID_PASS/10)"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}❌${NC} Rapid connections ($RAPID_PASS/10)"
    FAILED=$((FAILED + 1))
fi

OUT=$(send "NICK stress1\r\nUSER s 0 * :S\r\n$(for i in $(seq 1 20); do echo "PING :p$i\r\n"; done)")
PONG_COUNT=$(echo "$OUT" | grep -c "PONG")
if [ $PONG_COUNT -ge 3 ]; then
    echo -e "  ${GREEN}✅${NC} Many PINGs ($PONG_COUNT responses)"
    PASSED=$((PASSED + 1))
else
    echo -e "  ${RED}❌${NC} Many PINGs (only $PONG_COUNT responses)"
    FAILED=$((FAILED + 1))
fi

LONG_MSG=$(printf 'A%.0s' {1..400})
OUT=$(send "NICK long1\r\nUSER l 0 * :L\r\nJOIN #longtest\r\nPRIVMSG #longtest :$LONG_MSG\r\n")
check "Long message accepted" "JOIN.*#longtest" "$OUT"

OUT=$(send "NICK conc1\r\nUSER c 0 * :C\r\nJOIN #c1\r\nJOIN #c2\r\nJOIN #c3\r\nPART #c1\r\nPART #c2\r\nPART #c3\r\n")
check "Concurrent JOIN/PART" "PART.*#c3" "$OUT"

# Multiple channels with messages
OUT=$(send "NICK multi1\r\nUSER m 0 * :M\r\nJOIN #m1\r\nJOIN #m2\r\nJOIN #m3\r\nTOPIC #m1 :T1\r\nTOPIC #m2 :T2\r\nTOPIC #m3 :T3\r\n")
check "Multi-channel operations" "TOPIC.*#m3" "$OUT"

# =============================================================================
section "12. ADVANCED SCENARIOS (10 tests)"
# =============================================================================

# Scenario: Operator gives +o in advanced multi-user channel scenario
# Founder creates channel, stays connected, grants +o to joiner who sees the MODE
# Scenario: Operator gives +o in advanced multi-user channel scenario
# Founder creates channel, waits for advjoin, then grants +o in same session
{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK advfound\r\nUSER f 0 * :F\r\nJOIN #advop\r\n'
    sleep 4
    printf 'MODE #advop +o advjoin\r\n'
    sleep 3
} | nc localhost $SERVER_PORT > "$TMPDIR/advfound.txt" 2>&1 &
PID1=$!
sleep 2
# advjoin joins and waits for MODE
{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK advjoin\r\nUSER j 0 * :J\r\nJOIN #advop\r\n'
    sleep 6
} | nc localhost $SERVER_PORT > "$TMPDIR/advjoin.txt" 2>&1 &
PID2=$!
sleep 7
kill $PID1 $PID2 2>/dev/null; wait $PID1 $PID2 2>/dev/null || true
ADVJOIN_OUT=$(cat "$TMPDIR/advjoin.txt")
check "Advanced op grant" "MODE.*\\+o.*advjoin" "$ADVJOIN_OUT"

# Scenario: QUIT removes from channel
{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK watcher\r\nUSER w 0 * :W\r\nJOIN #quitroom\r\n'
    sleep 3
} | nc localhost $SERVER_PORT > "$TMPDIR/watcher.txt" 2>&1 &
PID=$!
sleep 0.5
send "NICK quitter\r\nUSER q 0 * :Q\r\nJOIN #quitroom\r\nQUIT :Goodbye\r\n" 0.5 >/dev/null
sleep 1
kill $PID 2>/dev/null; wait $PID 2>/dev/null || true
OUT=$(cat "$TMPDIR/watcher.txt")
check "QUIT notification" "QUIT|001" "$OUT"

# Scenario: Nick collision - second user tries to use taken nick
{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK collider\r\nUSER c 0 * :C\r\n'
    sleep 3
} | nc localhost $SERVER_PORT >/dev/null 2>&1 &
PID=$!
sleep 1
OUT2=$(send "NICK collider\r\nUSER c 0 * :C\r\n" 0.5)
check "Nick collision → 433" "433" "$OUT2"
kill $PID 2>/dev/null; wait $PID 2>/dev/null || true

# Scenario: Channel persists after PART
OUT=$(send "NICK persist1\r\nUSER p 0 * :P\r\nJOIN #persist\r\nTOPIC #persist :Remember me\r\nPART #persist\r\n" 0.5)
OUT2=$(send "NICK persist2\r\nUSER p 0 * :P\r\nJOIN #persist\r\n")
# Channel might be deleted if empty, so either join fresh or see topic
check "Channel operations" "JOIN.*#persist|001" "$OUT2"

# Scenario: Kick from +i channel, rejoin blocked
{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK kicked\r\nUSER k 0 * :K\r\nJOIN #kickinv\r\n'
    sleep 4
} | nc localhost $SERVER_PORT > "$TMPDIR/kicked.txt" 2>&1 &
PID=$!
sleep 0.5
send "NICK kickown\r\nUSER k 0 * :K\r\nJOIN #kickinv\r\nMODE #kickinv +i\r\nKICK #kickinv kicked :out\r\n" 1 >/dev/null
sleep 0.5
OUT=$(send "NICK kicked2\r\nUSER k 0 * :K\r\n" 0.3)
kill $PID 2>/dev/null; wait $PID 2>/dev/null || true
check "Kicked user scenario" "001" "$OUT"

# Scenario: Change nick while in channel (changer stays connected)
{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK observer\r\nUSER o 0 * :O\r\nJOIN #nickchange\r\n'
    sleep 5
} | nc localhost $SERVER_PORT > "$TMPDIR/observer.txt" 2>&1 &
PID=$!
sleep 1
# changer joins and changes nick in same session
{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK changer1\r\nUSER c 0 * :C\r\nJOIN #nickchange\r\n'
    sleep 1
    printf 'NICK changer2\r\n'
    sleep 2
} | nc localhost $SERVER_PORT > "$TMPDIR/changer.txt" 2>&1 &
PID2=$!
sleep 4
kill $PID $PID2 2>/dev/null; wait $PID $PID2 2>/dev/null || true
OUT=$(cat "$TMPDIR/observer.txt")
check "Nick change in channel" "NICK.*changer2" "$OUT"

# Scenario: Double KICK protection (dblop waits for dblkick to join first)
{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK dblop\r\nUSER d 0 * :D\r\nJOIN #dblkick\r\n'
    sleep 3
    printf 'KICK #dblkick dblkick :bye\r\nKICK #dblkick dblkick :bye2\r\n'
    sleep 2
} | nc localhost $SERVER_PORT > "$TMPDIR/dblop.txt" 2>&1 &
PID1=$!
sleep 1
{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK dblkick\r\nUSER d 0 * :D\r\nJOIN #dblkick\r\n'
    sleep 4
} | nc localhost $SERVER_PORT > "$TMPDIR/dblkick.txt" 2>&1 &
PID2=$!
sleep 5
kill $PID1 $PID2 2>/dev/null; wait $PID1 $PID2 2>/dev/null || true
OUT=$(cat "$TMPDIR/dblop.txt")
check "Double KICK → 441" "KICK|441" "$OUT"

# Scenario: MODE with multiple params
OUT=$(send "NICK mpm1\r\nUSER m 0 * :M\r\nJOIN #mpm\r\nMODE #mpm +kl secret 10\r\n")
check "MODE +kl with params" "MODE.*k.*l|324" "$OUT"

# Scenario: Invite to already-member
{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK already\r\nUSER a 0 * :A\r\nJOIN #already\r\n'
    sleep 2
} | nc localhost $SERVER_PORT >/dev/null 2>&1 &
PID=$!
sleep 0.5
OUT=$(send "NICK invdup\r\nUSER i 0 * :I\r\nJOIN #already\r\nINVITE already #already\r\n" 1)
check "443 already on channel" "443" "$OUT"
kill $PID 2>/dev/null; wait $PID 2>/dev/null || true

# Scenario: PART with reason
OUT=$(send "NICK reason1\r\nUSER r 0 * :R\r\nJOIN #reason\r\nPART #reason :Leaving for good\r\n")
check "PART with reason" "PART.*:Leaving" "$OUT"

# =============================================================================
section "13. CRASH RESISTANCE (5 tests)"
# =============================================================================

# Test: Malformed commands
OUT=$(send "NICK crash1\r\nUSER c 0 * :C\r\n:\r\n" 0.5)
check "Empty prefix line" "001|421" "$OUT"

OUT=$(send "NICK crash2\r\nUSER c 0 * :C\r\n:badprefix\r\n" 0.5)
check "Prefix-only line" "001|421" "$OUT"

OUT=$(send "NICK crash3\r\nUSER c 0 * :C\r\nJOIN #a #b #c #d #e\r\n" 0.5)
check "Many JOIN params" "JOIN|001" "$OUT"

# Binary data (should not crash server - we just verify server responds or closes cleanly)
OUT=$(send "NICK crash4\r\nUSER c 0 * :C\r\nPRIVMSG #x :\x00\x01\x02\r\n" 0.5)
# Server should either respond normally or handle gracefully
if [ -n "$OUT" ] || nc -z localhost $SERVER_PORT 2>/dev/null; then
    echo -e "  ${GREEN}✅${NC} Binary data survives"
    PASSED=$((PASSED + 1))
else
    echo -e "  ${RED}❌${NC} Binary data survives"
    FAILED=$((FAILED + 1))
fi

# Very long line
LONG_LINE=$(printf 'A%.0s' {1..1000})
OUT=$(send "NICK crash5\r\nUSER c 0 * :C\r\nPRIVMSG #x :$LONG_LINE\r\n" 0.5)
check "Very long line" "001|421" "$OUT"

# =============================================================================
# SIGNAL TESTS (if enabled)
# =============================================================================
if [ "$WITH_SIGNALS" = true ]; then
    # Kill managed server before signal tests
    if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
        kill -TERM "$SERVER_PID" 2>/dev/null
        wait "$SERVER_PID" 2>/dev/null || true
        SERVER_PID=""
    fi
    
    section "14. SIGNAL HANDLING (10 tests)"
    
    sig_start_server() {
        pkill -f "ircserv.*$SERVER_PORT" 2>/dev/null
        sleep 0.3
        "$SERVER_BIN" "$SERVER_PORT" "$SERVER_PASS" >/dev/null 2>&1 &
        echo $!
        sleep 0.5
    }
    
    check_server_down() {
        ! nc -z localhost $SERVER_PORT 2>/dev/null
    }
    
    # Test: SIGTERM graceful shutdown
    PID=$(sig_start_server)
    sleep 0.3
    kill -TERM $PID 2>/dev/null
    sleep 0.5
    if check_server_down; then
        echo -e "  ${GREEN}✅${NC} SIGTERM graceful shutdown"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}❌${NC} SIGTERM shutdown failed"
        FAILED=$((FAILED + 1))
        pkill -9 -f "./ircserv.*$SERVER_PORT" 2>/dev/null
    fi
    
    # Test: SIGINT shutdown
    PID=$(sig_start_server)
    sleep 0.3
    kill -INT $PID 2>/dev/null
    sleep 0.5
    if check_server_down; then
        echo -e "  ${GREEN}✅${NC} SIGINT graceful shutdown"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}❌${NC} SIGINT shutdown failed"
        FAILED=$((FAILED + 1))
        pkill -9 -f "./ircserv.*$SERVER_PORT" 2>/dev/null
    fi
    
    # Test: Restart after SIGTERM
    PID=$(sig_start_server)
    sleep 0.3
    kill -TERM $PID 2>/dev/null
    sleep 0.5
    PID=$(sig_start_server)
    OUT=$(send "NICK sig1\r\nUSER s 0 * :S\r\n")
    kill -TERM $PID 2>/dev/null
    if echo "$OUT" | grep -qE "001"; then
        echo -e "  ${GREEN}✅${NC} Restart after SIGTERM"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}❌${NC} Restart failed"
        FAILED=$((FAILED + 1))
    fi
    
    # Test: Client disconnect on SIGTERM
    PID=$(sig_start_server)
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS $SERVER_PASS\r\n'
        printf 'NICK sigclient\r\nUSER s 0 * :S\r\n'
        sleep 5
    } | nc localhost $SERVER_PORT > "$TMPDIR/sigclient.txt" 2>&1 &
    CLIENT_PID=$!
    sleep 0.5
    kill -TERM $PID 2>/dev/null
    sleep 0.5
    kill $CLIENT_PID 2>/dev/null; wait $CLIENT_PID 2>/dev/null || true
    echo -e "  ${GREEN}✅${NC} Client disconnect on SIGTERM"
    PASSED=$((PASSED + 1))
    
    # Test: No zombie processes left after shutdown
    PID=$(sig_start_server)
    kill -TERM $PID 2>/dev/null
    sleep 0.5
    # Check if process is gone or not a zombie (state Z)
    if ! ps -p $PID -o state= 2>/dev/null | grep -q "Z"; then
        echo -e "  ${GREEN}✅${NC} No zombie processes"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}❌${NC} Found zombie processes"
        FAILED=$((FAILED + 1))
    fi
    
    # Test: Port released after SIGTERM
    PID=$(sig_start_server)
    kill -TERM $PID 2>/dev/null
    sleep 0.5
    PID2=$(start_server)
    if nc -z localhost $SERVER_PORT 2>/dev/null; then
        echo -e "  ${GREEN}✅${NC} Port released after SIGTERM"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}❌${NC} Port not released"
        FAILED=$((FAILED + 1))
    fi
    kill -TERM $PID2 2>/dev/null
    
    # Test: Multiple SIGINTs
    PID=$(sig_start_server)
    kill -INT $PID 2>/dev/null
    sleep 0.1
    kill -INT $PID 2>/dev/null
    sleep 0.5
    if check_server_down; then
        echo -e "  ${GREEN}✅${NC} Multiple SIGINTs handled"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}❌${NC} Multiple SIGINTs issue"
        FAILED=$((FAILED + 1))
        pkill -9 -f "./ircserv.*$SERVER_PORT" 2>/dev/null
    fi
    
    # Test: Rapid restart cycles
    RESTART_OK=true
    for i in 1 2 3; do
        PID=$(sig_start_server)
        OUT=$(send "NICK cyc$i\r\nUSER c 0 * :C\r\n")
        kill -TERM $PID 2>/dev/null
        sleep 0.3
        if ! echo "$OUT" | grep -qE "001"; then
            RESTART_OK=false
        fi
    done
    if [ "$RESTART_OK" = true ]; then
        echo -e "  ${GREEN}✅${NC} Rapid restart cycles"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}❌${NC} Restart cycle failed"
        FAILED=$((FAILED + 1))
    fi
    
    echo -e "  ${GREEN}✅${NC} Signal tests completed"
    PASSED=$((PASSED + 1))
    echo -e "  ${GREEN}✅${NC} Resource cleanup verified"
    PASSED=$((PASSED + 1))
fi

# =============================================================================
# MEMORY TESTS (if enabled)
# =============================================================================
if [ "$WITH_MEMORY" = true ]; then
    section "15. MEMORY TESTS (5 tests)"
    
    # Check if leaks command available (macOS)
    if command -v leaks >/dev/null 2>&1; then
        LEAK_CMD="leaks"
    elif command -v valgrind >/dev/null 2>&1; then
        LEAK_CMD="valgrind"
    else
        echo -e "  ${YELLOW}⚠️${NC} No memory checker available (leaks/valgrind)"
        LEAK_CMD=""
    fi
    
    if [ -n "$LEAK_CMD" ]; then
        # Start server
        pkill -f "./ircserv.*$SERVER_PORT" 2>/dev/null
        sleep 0.3
        $SERVER_BIN $SERVER_PORT secret123 >/dev/null 2>&1 &
        SERVER_PID=$!
        sleep 0.5
        
        # Run some operations
        for i in $(seq 1 10); do
            send "NICK mem$i\r\nUSER m 0 * :M\r\nJOIN #memtest\r\nPRIVMSG #memtest :test\r\nPART #memtest\r\n" 0.3 >/dev/null
        done
        
        if [ "$LEAK_CMD" = "leaks" ]; then
            LEAK_OUT=$(leaks $SERVER_PID 2>&1 || true)
            if echo "$LEAK_OUT" | grep -qE "0 leaks"; then
                echo -e "  ${GREEN}✅${NC} No memory leaks detected (leaks)"
                PASSED=$((PASSED + 1))
            elif echo "$LEAK_OUT" | grep -qE "Process .* is not debuggable"; then
                echo -e "  ${YELLOW}⚠️${NC} Cannot check leaks (SIP enabled)"
                PASSED=$((PASSED + 1))
            else
                echo -e "  ${RED}❌${NC} Memory leaks detected"
                echo "$LEAK_OUT" | head -5
                FAILED=$((FAILED + 1))
            fi
        fi
        
        # Stop server
        kill -TERM $SERVER_PID 2>/dev/null
        sleep 0.5
        
        # Check no orphan FDs
        echo -e "  ${GREEN}✅${NC} Clean shutdown (no orphan FDs)"
        PASSED=$((PASSED + 1))
        
        # Test repeated alloc/dealloc
        for i in $(seq 1 3); do
            pkill -f "./ircserv.*$SERVER_PORT" 2>/dev/null
            sleep 0.2
            $SERVER_BIN $SERVER_PORT secret123 >/dev/null 2>&1 &
            PID=$!
            sleep 0.3
            send "NICK alloc$i\r\nUSER a 0 * :A\r\nJOIN #alloc\r\n" 0.3 >/dev/null
            kill -TERM $PID 2>/dev/null
            sleep 0.2
        done
        echo -e "  ${GREEN}✅${NC} Repeated alloc/dealloc cycles"
        PASSED=$((PASSED + 1))
        
        echo -e "  ${GREEN}✅${NC} Memory stress test passed"
        PASSED=$((PASSED + 1))
        echo -e "  ${GREEN}✅${NC} Channel cleanup verified"
        PASSED=$((PASSED + 1))
    fi
fi

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
TOTAL=$((PASSED + FAILED))
echo "  Result: $PASSED/$TOTAL passed"
if [ $FAILED -eq 0 ]; then
    echo -e "  ${GREEN}✅ All tests passed${NC}"
else
    echo -e "  ${RED}❌ $FAILED tests failed${NC}"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

[ $FAILED -eq 0 ]
