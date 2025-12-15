#!/bin/bash
# =============================================================================
# ft_irc Comprehensive Test Suite
# =============================================================================
# 
# DESCRIPTION:
#   Complete test suite for 42 School ft_irc project.
#   Tests all required IRC functionality: registration, channels, messaging,
#   modes, operators, signals, and crash resistance.
#
# USAGE:
#   ./run_tests.sh                    # Run all tests (auto-starts server)
#   ./run_tests.sh --help             # Show this help
#   ./run_tests.sh --no-server        # Don't auto-start server (use running one)
#   ./run_tests.sh --port=6667        # Use custom port
#   ./run_tests.sh --pass=secret      # Use custom password
#   ./run_tests.sh --with-signals     # Include signal handling tests
#   ./run_tests.sh --verbose          # Show server output
#   ./run_tests.sh --quick            # Run only essential tests
#
# EXAMPLES:
#   ./run_tests.sh                              # Standard test run
#   ./run_tests.sh --with-signals               # Full test including signals
#   ./run_tests.sh --no-server --port=6666      # Test external server (e.g., ngircd)
#
# EXIT CODES:
#   0 - All tests passed
#   1 - Some tests failed
#
# =============================================================================

# Disable exit on error - tests should continue even if some commands fail
set +e

# =============================================================================
# CONFIGURATION
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SERVER_BIN="$PROJECT_DIR/ircserv"

# Defaults
SERVER_PORT=6697
SERVER_PASS="testpass"
AUTO_START_SERVER=true
WITH_SIGNALS=false
VERBOSE=false
QUICK_MODE=false
SERVER_PID=""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Counters
PASSED=0
FAILED=0
SKIPPED=0

# Temp directory
TMPDIR=$(mktemp -d)

# =============================================================================
# ARGUMENT PARSING
# =============================================================================

show_help() {
    head -35 "$0" | tail -30 | sed 's/^# //' | sed 's/^#//'
    exit 0
}

for arg in "$@"; do
    case $arg in
        --help|-h)
            show_help
            ;;
        --no-server)
            AUTO_START_SERVER=false
            ;;
        --port=*)
            SERVER_PORT="${arg#*=}"
            ;;
        --pass=*)
            SERVER_PASS="${arg#*=}"
            ;;
        --with-signals)
            WITH_SIGNALS=true
            ;;
        --verbose|-v)
            VERBOSE=true
            ;;
        --quick|-q)
            QUICK_MODE=true
            ;;
        *)
            echo "Unknown option: $arg"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

cleanup() {
    # Kill our server if we started it
    if [ -n "$SERVER_PID" ] && kill -0 "$SERVER_PID" 2>/dev/null; then
        kill -TERM "$SERVER_PID" 2>/dev/null
        wait "$SERVER_PID" 2>/dev/null || true
    fi
    # Cleanup nc processes
    pkill -f "nc.*localhost.*$SERVER_PORT" 2>/dev/null || true
    # Remove temp files
    rm -rf "$TMPDIR"
}

trap cleanup EXIT

die() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    exit 1
}

log() {
    echo -e "${CYAN}[INFO]${NC} $1"
}

send() {
    local cmds="$1" timeout="${2:-0.5}"
    [ -n "$SERVER_PASS" ] && cmds="PASS $SERVER_PASS\r\n$cmds"
    { printf '%b' "$cmds"; sleep "$timeout"; } | nc -w 2 localhost "$SERVER_PORT" 2>/dev/null
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
    log "Building server..."
    if ! make -C "$PROJECT_DIR" >/dev/null 2>&1; then
        die "Failed to build server. Run 'make' manually to see errors."
    fi
    log "Build successful"
}

start_server() {
    # Kill any existing server on our port
    pkill -f "ircserv.*$SERVER_PORT" 2>/dev/null || true
    sleep 0.3
    
    if [ "$VERBOSE" = true ]; then
        "$SERVER_BIN" "$SERVER_PORT" "$SERVER_PASS" &
    else
        "$SERVER_BIN" "$SERVER_PORT" "$SERVER_PASS" >/dev/null 2>&1 &
    fi
    SERVER_PID=$!
    
    # Wait for server to start
    sleep 0.5
    
    # Check if server is running
    if ! kill -0 "$SERVER_PID" 2>/dev/null; then
        die "Server failed to start"
    fi
    
    # Check if port is listening
    if ! nc -z localhost "$SERVER_PORT" 2>/dev/null; then
        die "Server not listening on port $SERVER_PORT"
    fi
    
    log "Server started (PID: $SERVER_PID, Port: $SERVER_PORT)"
}

check_server() {
    if ! nc -z localhost "$SERVER_PORT" 2>/dev/null; then
        die "No server running on port $SERVER_PORT. Start your server first or remove --no-server flag."
    fi
}

# =============================================================================
# HEADER
# =============================================================================

print_header() {
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BOLD}  ft_irc Comprehensive Test Suite${NC}"
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    echo "  Server:    localhost:$SERVER_PORT"
    echo "  Password:  $SERVER_PASS"
    echo "  Signals:   $WITH_SIGNALS"
    echo "  Mode:      $([ "$QUICK_MODE" = true ] && echo "Quick" || echo "Full")"
    echo ""
}

# =============================================================================
# TEST SECTIONS
# =============================================================================

test_registration() {
    section "1. REGISTRATION (12 tests)"
    
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
    
    OUT=$(send "NICK good1\r\nUSER g 0 * :G\r\n")
    check "Valid nick accepted" "001" "$OUT"
    
    OUT=$(send "NICK Test_123\r\nUSER t 0 * :T\r\n")
    check "Nick with underscore/digits" "001" "$OUT"
    
    OUT=$(send "NICK changer\r\nUSER c 0 * :C\r\nNICK newname\r\n")
    check "NICK change works" "NICK.*newname" "$OUT"
    
    OUT=$(send "USER ord 0 * :O\r\nNICK ordtest\r\n")
    check "USER before NICK works" "001" "$OUT"
}

test_channels() {
    section "2. CHANNELS (9 tests)"
    
    OUT=$(send "NICK ch1\r\nUSER c 0 * :C\r\nJOIN #test\r\n")
    check "JOIN echoed" "JOIN.*#test" "$OUT"
    check "353 NAMREPLY" "353" "$OUT"
    check "366 ENDOFNAMES" "366" "$OUT"
    
    OUT=$(send "NICK ch2\r\nUSER c 0 * :C\r\nJOIN #optest\r\n")
    check "First user gets @" "353.*@ch2" "$OUT"
    
    OUT=$(send "NICK ch3\r\nUSER c 0 * :C\r\nJOIN\r\n" | grep -E "461|JOIN")
    check "461 JOIN no params" "461" "$OUT"
    
    OUT=$(send "NICK ch4\r\nUSER c 0 * :C\r\nJOIN badchan\r\n")
    check "403 bad channel name" "403|476" "$OUT"
    
    OUT=$(send "NICK ch5\r\nUSER c 0 * :C\r\nJOIN #parttest\r\nPART #parttest\r\n")
    check "PART echoed" "PART.*#parttest" "$OUT"
    
    OUT=$(send "NICK ch6\r\nUSER c 0 * :C\r\nPART #unknown\r\n")
    check "403/442 PART unknown" "403|442" "$OUT"
    
    OUT=$(send "NICK ch7\r\nUSER c 0 * :C\r\nJOIN #a\r\nJOIN #b\r\nJOIN #c\r\n")
    check "Multiple JOINs work" "JOIN.*#c" "$OUT"
}

test_messaging() {
    section "3. MESSAGING (6 tests)"
    
    OUT=$(send "NICK msg1\r\nUSER m 0 * :M\r\nPRIVMSG nobody :hi\r\n")
    check "401 no such nick" "401" "$OUT"
    
    OUT=$(send "NICK msg2\r\nUSER m 0 * :M\r\nJOIN #echo\r\nPRIVMSG #echo :test\r\n")
    check_not "Sender no echo" "PRIVMSG.*#echo.*:test" "$OUT"
    
    OUT=$(send "NICK msg3\r\nUSER m 0 * :M\r\nPRIVMSG\r\n" | grep -E "411|461")
    check "411/461 PRIVMSG no params" "411|461" "$OUT"
    
    # Two-client DM test
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK recv\r\nUSER r 0 * :R\r\n'
        sleep 1
    } | nc localhost "$SERVER_PORT" > "$TMPDIR/recv.txt" 2>&1 &
    PID=$!
    sleep 0.5
    send "NICK sender\r\nUSER s 0 * :S\r\nPRIVMSG recv :Hello there\r\n" 1 >/dev/null
    sleep 0.5
    kill $PID 2>/dev/null; wait $PID 2>/dev/null || true
    RECV_OUT=$(cat "$TMPDIR/recv.txt")
    check "DM received" "PRIVMSG recv.*Hello" "$RECV_OUT"
    
    # Channel broadcast test
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK listener\r\nUSER l 0 * :L\r\nJOIN #chat\r\n'
        sleep 1
    } | nc localhost "$SERVER_PORT" > "$TMPDIR/listener.txt" 2>&1 &
    PID=$!
    sleep 0.5
    send "NICK talker\r\nUSER t 0 * :T\r\nJOIN #chat\r\nPRIVMSG #chat :Broadcast msg\r\n" 1 >/dev/null
    sleep 0.5
    kill $PID 2>/dev/null; wait $PID 2>/dev/null || true
    LISTEN_OUT=$(cat "$TMPDIR/listener.txt")
    check "Broadcast received" "PRIVMSG #chat.*Broadcast" "$LISTEN_OUT"
    
    # External message to channel with +n
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK chown\r\nUSER c 0 * :C\r\nJOIN #private\r\n'
        sleep 1
    } | nc localhost "$SERVER_PORT" > /dev/null 2>&1 &
    PID=$!
    sleep 0.5
    OUT=$(send "NICK msg4\r\nUSER m 0 * :M\r\nPRIVMSG #private :hi\r\n")
    kill $PID 2>/dev/null; wait $PID 2>/dev/null || true
    check "404 not on channel (+n)" "404|442" "$OUT"
}

test_topic() {
    section "4. TOPIC (5 tests)"
    
    OUT=$(send "NICK top1\r\nUSER t 0 * :T\r\nJOIN #topictest\r\nTOPIC #topictest\r\n")
    check "331 no topic" "331" "$OUT"
    
    OUT=$(send "NICK top2\r\nUSER t 0 * :T\r\nJOIN #settopic\r\nTOPIC #settopic :Hello World\r\n")
    check "TOPIC set" "TOPIC.*Hello World" "$OUT"
    
    OUT=$(send "NICK top3\r\nUSER t 0 * :T\r\nTOPIC #nonexistent\r\n")
    check "403 unknown channel" "403" "$OUT"
    
    # Not on channel
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK topown\r\nUSER t 0 * :T\r\nJOIN #toptarget\r\n'
        sleep 1
    } | nc localhost "$SERVER_PORT" > /dev/null 2>&1 &
    PID=$!
    sleep 0.5
    OUT=$(send "NICK outsider\r\nUSER o 0 * :O\r\nTOPIC #toptarget :hack\r\n")
    kill $PID 2>/dev/null; wait $PID 2>/dev/null || true
    check "442/482 not on channel" "442|482" "$OUT"
    
    OUT=$(send "NICK top4\r\nUSER t 0 * :T\r\nJOIN #querytopic\r\nTOPIC #querytopic :Test\r\nTOPIC #querytopic\r\n")
    check "TOPIC query returns 332" "332.*Test" "$OUT"
}

test_kick() {
    section "5. KICK (5 tests)"
    
    OUT=$(send "NICK kick1\r\nUSER k 0 * :K\r\nJOIN #x\r\nKICK\r\n")
    check "461 KICK no params" "461" "$OUT"
    
    OUT=$(send "NICK kick2\r\nUSER k 0 * :K\r\nJOIN #x\r\nKICK #x nobody\r\n")
    check "401/441 KICK unknown" "401|441" "$OUT"
    
    # Not on channel test
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK chanop\r\nUSER c 0 * :C\r\nJOIN #kicktest\r\n'
        sleep 1
    } | nc localhost "$SERVER_PORT" > /dev/null 2>&1 &
    PID=$!
    sleep 0.5
    OUT=$(send "NICK kicker\r\nUSER k 0 * :K\r\nKICK #kicktest chanop\r\n")
    kill $PID 2>/dev/null; wait $PID 2>/dev/null || true
    check "403/442/482 not on channel" "403|442|482" "$OUT"
    
    # Not operator test
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK theop\r\nUSER t 0 * :T\r\nJOIN #opkick\r\n'
        sleep 1
    } | nc localhost "$SERVER_PORT" > /dev/null 2>&1 &
    PID=$!
    sleep 0.5
    OUT=$(send "NICK noob\r\nUSER n 0 * :N\r\nJOIN #opkick\r\nKICK #opkick theop\r\n")
    kill $PID 2>/dev/null; wait $PID 2>/dev/null || true
    check "482 not operator" "482" "$OUT"
    
    # Successful KICK
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK victim\r\nUSER v 0 * :V\r\n'
        sleep 1.5
    } | nc localhost "$SERVER_PORT" > "$TMPDIR/victim.txt" 2>&1 &
    PID=$!
    sleep 0.3
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK kickop\r\nUSER k 0 * :K\r\nJOIN #kickme\r\n'
        sleep 0.5
        printf 'KICK #kickme victim :bye\r\n'
        sleep 0.5
    } | nc localhost "$SERVER_PORT" > /dev/null 2>&1 &
    PID2=$!
    sleep 0.3
    send "NICK joiner\r\nUSER j 0 * :J\r\nJOIN #kickme\r\nINVITE victim #kickme\r\n" 0.5 >/dev/null
    sleep 0.3
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK victim2\r\nUSER v 0 * :V\r\nJOIN #kickme\r\n'
        sleep 1
    } | nc localhost "$SERVER_PORT" > "$TMPDIR/victim2.txt" 2>&1 &
    PID3=$!
    sleep 0.3
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK kickop2\r\nUSER k 0 * :K\r\nJOIN #kickme\r\nMODE #kickme +o kickop2\r\n'
        sleep 0.3
        printf 'KICK #kickme victim2 :goodbye\r\n'
        sleep 0.5
    } | nc localhost "$SERVER_PORT" > "$TMPDIR/kickop2.txt" 2>&1 &
    PID4=$!
    sleep 1.5
    kill $PID $PID2 $PID3 $PID4 2>/dev/null; wait $PID $PID2 $PID3 $PID4 2>/dev/null || true
    KICK_OUT=$(cat "$TMPDIR/victim2.txt" "$TMPDIR/kickop2.txt" 2>/dev/null)
    check "KICK message sent" "KICK.*#kickme.*victim2" "$KICK_OUT"
}

test_invite() {
    section "6. INVITE (5 tests)"
    
    OUT=$(send "NICK inv1\r\nUSER i 0 * :I\r\nJOIN #x\r\nINVITE\r\n")
    check "461 INVITE no params" "461" "$OUT"
    
    OUT=$(send "NICK inv2\r\nUSER i 0 * :I\r\nJOIN #x\r\nINVITE nobody #x\r\n")
    check "401 INVITE unknown" "401" "$OUT"
    
    # Not on channel
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK target\r\nUSER t 0 * :T\r\n'
        sleep 1
    } | nc localhost "$SERVER_PORT" > /dev/null 2>&1 &
    PID=$!
    sleep 0.3
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK invown\r\nUSER i 0 * :I\r\nJOIN #invtest\r\n'
        sleep 1
    } | nc localhost "$SERVER_PORT" > /dev/null 2>&1 &
    PID2=$!
    sleep 0.5
    OUT=$(send "NICK inviter\r\nUSER i 0 * :I\r\nINVITE target #invtest\r\n")
    kill $PID $PID2 2>/dev/null; wait $PID $PID2 2>/dev/null || true
    check "442/482 INVITE not on chan" "442|482" "$OUT"
    
    # Successful INVITE
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK guest\r\nUSER g 0 * :G\r\n'
        sleep 1
    } | nc localhost "$SERVER_PORT" > /dev/null 2>&1 &
    PID=$!
    sleep 0.5
    OUT=$(send "NICK host\r\nUSER h 0 * :H\r\nJOIN #party\r\nINVITE guest #party\r\n")
    kill $PID 2>/dev/null; wait $PID 2>/dev/null || true
    check "341 INVITE success" "341" "$OUT"
    
    # INVITE notification to target
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK invited\r\nUSER i 0 * :I\r\n'
        sleep 2
    } | nc localhost "$SERVER_PORT" > "$TMPDIR/invited.txt" 2>&1 &
    PID=$!
    sleep 0.5
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK invhost\r\nUSER h 0 * :H\r\nJOIN #secret\r\nMODE #secret +i\r\n'
        sleep 1
        printf 'INVITE invited #secret\r\n'
        sleep 1
    } | nc localhost "$SERVER_PORT" > "$TMPDIR/invhost.txt" 2>&1 &
    PID2=$!
    sleep 4
    kill $PID $PID2 2>/dev/null; wait $PID $PID2 2>/dev/null || true
    INV_OUT=$(cat "$TMPDIR/invited.txt")
    check "INVITE notification sent" "INVITE invited #secret" "$INV_OUT"
}

test_mode() {
    section "7. MODE (10 tests)"
    
    OUT=$(send "NICK mode1\r\nUSER m 0 * :M\r\nJOIN #modetest\r\nMODE #modetest\r\n")
    check "324 MODE query" "324" "$OUT"
    
    OUT=$(send "NICK mode2\r\nUSER m 0 * :M\r\nJOIN #mi\r\nMODE #mi +i\r\n")
    check "MODE +i set" "MODE.*\+.*i" "$OUT"
    
    OUT=$(send "NICK mode3\r\nUSER m 0 * :M\r\nJOIN #mt\r\nMODE #mt +t\r\n")
    check "MODE +t set" "MODE.*\+.*t" "$OUT"
    
    OUT=$(send "NICK mode4\r\nUSER m 0 * :M\r\nJOIN #mk\r\nMODE #mk +k secret\r\n")
    check "MODE +k set" "MODE.*\+.*k" "$OUT"
    
    OUT=$(send "NICK mode5\r\nUSER m 0 * :M\r\nJOIN #ml\r\nMODE #ml +l 10\r\n")
    check "MODE +l set" "MODE.*\+.*l" "$OUT"
    
    OUT=$(send "NICK mode6\r\nUSER m 0 * :M\r\nJOIN #combo\r\nMODE #combo +it\r\n")
    check "MODE +it combo" "MODE.*\+.*i.*t|\+.*t.*i" "$OUT"
    
    OUT=$(send "NICK mode7\r\nUSER m 0 * :M\r\nJOIN #minus\r\nMODE #minus +i\r\nMODE #minus -i\r\n")
    check "MODE -i works" "MODE.*-.*i" "$OUT"
    
    # Non-operator can query
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK opper\r\nUSER o 0 * :O\r\nJOIN #querymode\r\n'
        sleep 1
    } | nc localhost "$SERVER_PORT" > /dev/null 2>&1 &
    PID=$!
    sleep 0.5
    OUT=$(send "NICK mode8\r\nUSER m 0 * :M\r\nJOIN #querymode\r\nMODE #querymode\r\n")
    kill $PID 2>/dev/null; wait $PID 2>/dev/null || true
    check "MODE query by non-op" "324" "$OUT"
    
    OUT=$(send "NICK mode9\r\nUSER m 0 * :M\r\nMODE #unknown\r\n")
    check "403/401 unknown channel" "403|401" "$OUT"
    
    # MODE +o grant
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK opowner\r\nUSER o 0 * :O\r\nJOIN #opgrant\r\n'
        sleep 0.5
        printf 'MODE #opgrant +o oprecv\r\n'
        sleep 1
    } | nc localhost "$SERVER_PORT" > "$TMPDIR/opowner.txt" 2>&1 &
    PID=$!
    sleep 0.3
    OUT=$(send "NICK oprecv\r\nUSER o 0 * :O\r\nJOIN #opgrant\r\n" 1.5)
    sleep 1
    kill $PID 2>/dev/null; wait $PID 2>/dev/null || true
    OP_OUT=$(cat "$TMPDIR/opowner.txt")
    check "MODE +o grant" "MODE.*\+o.*oprecv" "$OP_OUT"
}

test_mode_enforcement() {
    section "8. MODE ENFORCEMENT (5 tests)"
    
    # +i blocks
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK iown\r\nUSER i 0 * :I\r\nJOIN #invonly\r\nMODE #invonly +i\r\n'
        sleep 1
    } | nc localhost "$SERVER_PORT" > /dev/null 2>&1 &
    PID=$!
    sleep 0.5
    OUT=$(send "NICK intruder\r\nUSER i 0 * :I\r\nJOIN #invonly\r\n")
    kill $PID 2>/dev/null; wait $PID 2>/dev/null || true
    check "473 +i blocks" "473" "$OUT"
    
    # +k wrong key
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK kown\r\nUSER k 0 * :K\r\nJOIN #keyed\r\nMODE #keyed +k secret\r\n'
        sleep 1
    } | nc localhost "$SERVER_PORT" > /dev/null 2>&1 &
    PID=$!
    sleep 0.5
    OUT=$(send "NICK wrongkey\r\nUSER w 0 * :W\r\nJOIN #keyed wrong\r\n")
    kill $PID 2>/dev/null; wait $PID 2>/dev/null || true
    check "475 wrong key" "475" "$OUT"
    
    # +k correct key
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK kown2\r\nUSER k 0 * :K\r\nJOIN #keyed2\r\nMODE #keyed2 +k pass123\r\n'
        sleep 1
    } | nc localhost "$SERVER_PORT" > /dev/null 2>&1 &
    PID=$!
    sleep 0.5
    OUT=$(send "NICK rightkey\r\nUSER r 0 * :R\r\nJOIN #keyed2 pass123\r\n")
    kill $PID 2>/dev/null; wait $PID 2>/dev/null || true
    check "+k correct key works" "JOIN.*#keyed2" "$OUT"
    
    # +l limit
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK lown\r\nUSER l 0 * :L\r\nJOIN #limited\r\nMODE #limited +l 1\r\n'
        sleep 1
    } | nc localhost "$SERVER_PORT" > /dev/null 2>&1 &
    PID=$!
    sleep 0.5
    OUT=$(send "NICK overflow\r\nUSER o 0 * :O\r\nJOIN #limited\r\n")
    kill $PID 2>/dev/null; wait $PID 2>/dev/null || true
    check "471 channel full" "471" "$OUT"
    
    # +t blocks topic change by non-op
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK town\r\nUSER t 0 * :T\r\nJOIN #topicprot\r\nMODE #topicprot +t\r\n'
        sleep 1
    } | nc localhost "$SERVER_PORT" > /dev/null 2>&1 &
    PID=$!
    sleep 0.5
    OUT=$(send "NICK pleb\r\nUSER p 0 * :P\r\nJOIN #topicprot\r\nTOPIC #topicprot :hacked\r\n")
    kill $PID 2>/dev/null; wait $PID 2>/dev/null || true
    check "482 +t blocks topic" "482" "$OUT"
}

test_ping_pong() {
    section "9. PING/PONG (10 tests)"
    
    OUT=$(send "NICK p1\r\nUSER p 0 * :P\r\nPING :token123\r\n")
    check "PING :token → PONG" "PONG.*token123" "$OUT"
    
    OUT=$(send "NICK p2\r\nUSER p 0 * :P\r\nPING token456\r\n")
    check "PING param → PONG" "PONG.*token456" "$OUT"
    
    OUT=$(send "NICK p3\r\nUSER p 0 * :P\r\nPING\r\n")
    check "PING no token → response" "PONG" "$OUT"
    
    OUT=$(send "NICK p4\r\nUSER p 0 * :P\r\nPING first\r\nPING second\r\n")
    check "Multiple PINGs - first" "PONG.*first" "$OUT"
    check "Multiple PINGs - second" "PONG.*second" "$OUT"
    
    OUT=$(send "NICK p5\r\nUSER p 0 * :P\r\nPING :longtoken123456789\r\n")
    check "PING long token" "PONG.*longtoken" "$OUT"
    
    OUT=$(send "NICK p6\r\nUSER p 0 * :P\r\nPING :token-with-dash\r\n")
    check "PING special chars" "PONG.*token-with-dash" "$OUT"
    
    OUT=$(send "NICK p7\r\nUSER p 0 * :P\r\nPONG server\r\n")
    check_not "PONG accepted (no error)" "421" "$OUT"
    
    OUT=$(send "NICK p8\r\nUSER p 0 * :P\r\nping lowercase\r\n")
    check "Lowercase ping works" "PONG" "$OUT"
    
    OUT=$(send "NICK p9\r\nUSER p 0 * :P\r\nJOIN #x\r\nPING mid\r\nPART #x\r\n")
    check "PING mixed commands" "PONG.*mid" "$OUT"
}

test_error_handling() {
    section "10. ERROR HANDLING (5 tests)"
    
    OUT=$(send "NICK err1\r\nUSER e 0 * :E\r\nFAKECMD test\r\n")
    check "421 unknown command" "421" "$OUT"
    
    OUT=$(send "NICK err2\r\nUSER e 0 * :E\r\nBLAH\r\nFOO\r\nBAR\r\n")
    check "Multiple unknowns handled" "421.*421" "$OUT"
    
    OUT=$(send "NICK err3\r\nUSER e 0 * :E\r\n\r\n\r\nPING test\r\n")
    check "Empty lines tolerated" "PONG" "$OUT"
    
    OUT=$(send "NICK err4\r\nUSER e 0 * :E\r\njoin #TEST\r\n")
    check "Case insensitive cmds" "JOIN.*#TEST" "$OUT"
    
    OUT=$(send "NICK err5\r\nUSER e 0 * :E\r\nJOIN   #spaces\r\n")
    check "Extra whitespace" "JOIN.*#spaces" "$OUT"
}

test_stress() {
    section "11. STRESS TESTS (5 tests)"
    
    # Rapid connections
    RAPID_OK=0
    for i in $(seq 1 10); do
        if send "NICK rapid$i\r\nUSER r 0 * :R\r\n" 0.3 | grep -q "001"; then
            RAPID_OK=$((RAPID_OK + 1))
        fi
    done
    if [ $RAPID_OK -ge 8 ]; then
        echo -e "  ${GREEN}✅${NC} Rapid connections ($RAPID_OK/10)"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}❌${NC} Rapid connections ($RAPID_OK/10)"
        FAILED=$((FAILED + 1))
    fi
    
    # Many PINGs
    PING_CMD=""
    for i in $(seq 1 20); do PING_CMD="${PING_CMD}PING $i\r\n"; done
    OUT=$(send "NICK stress1\r\nUSER s 0 * :S\r\n$PING_CMD")
    PONG_COUNT=$(echo "$OUT" | grep -c "PONG" || echo 0)
    if [ "$PONG_COUNT" -ge 15 ]; then
        echo -e "  ${GREEN}✅${NC} Many PINGs ($PONG_COUNT responses)"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}❌${NC} Many PINGs (only $PONG_COUNT responses)"
        FAILED=$((FAILED + 1))
    fi
    
    # Long message
    LONG_MSG=$(printf 'A%.0s' {1..400})
    OUT=$(send "NICK long1\r\nUSER l 0 * :L\r\nJOIN #long\r\nPRIVMSG #long :$LONG_MSG\r\nPING done\r\n")
    check "Long message accepted" "PONG.*done" "$OUT"
    
    # Concurrent operations
    OUT=$(send "NICK conc1\r\nUSER c 0 * :C\r\nJOIN #a\r\nPART #a\r\nJOIN #a\r\nPART #a\r\nJOIN #a\r\n")
    check "Concurrent JOIN/PART" "JOIN.*#a" "$OUT"
    
    # Multi-channel
    OUT=$(send "NICK multi1\r\nUSER m 0 * :M\r\nJOIN #m1\r\nJOIN #m2\r\nJOIN #m3\r\nPRIVMSG #m1 :test\r\nPRIVMSG #m2 :test\r\nPING end\r\n")
    check "Multi-channel operations" "PONG.*end" "$OUT"
}

test_advanced() {
    section "12. ADVANCED SCENARIOS (10 tests)"
    
    # Op grant and verify
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK advfound\r\nUSER a 0 * :A\r\nJOIN #adv\r\n'
        sleep 0.5
        printf 'MODE #adv +o advjoin\r\n'
        sleep 1
    } | nc localhost "$SERVER_PORT" > "$TMPDIR/advfound.txt" 2>&1 &
    PID=$!
    sleep 0.3
    OUT=$(send "NICK advjoin\r\nUSER a 0 * :A\r\nJOIN #adv\r\n" 1.5)
    kill $PID 2>/dev/null; wait $PID 2>/dev/null || true
    ADV_OUT=$(cat "$TMPDIR/advfound.txt")
    check "Advanced op grant" "MODE.*\+o.*advjoin" "$ADV_OUT"
    
    # QUIT notification
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK watcher\r\nUSER w 0 * :W\r\nJOIN #quitwatch\r\n'
        sleep 1
    } | nc localhost "$SERVER_PORT" > "$TMPDIR/watcher.txt" 2>&1 &
    PID=$!
    sleep 0.5
    send "NICK quitter\r\nUSER q 0 * :Q\r\nJOIN #quitwatch\r\nQUIT :Goodbye\r\n" 1 >/dev/null
    sleep 0.5
    kill $PID 2>/dev/null; wait $PID 2>/dev/null || true
    WATCH_OUT=$(cat "$TMPDIR/watcher.txt")
    check "QUIT notification" "QUIT.*Goodbye|QUIT.*quitter" "$WATCH_OUT"
    
    # Nick collision
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK collider\r\nUSER c 0 * :C\r\n'
        sleep 1
    } | nc localhost "$SERVER_PORT" > /dev/null 2>&1 &
    PID=$!
    sleep 0.5
    OUT=$(send "NICK collider\r\nUSER c 0 * :C\r\n")
    kill $PID 2>/dev/null; wait $PID 2>/dev/null || true
    check "Nick collision → 433" "433" "$OUT"
    
    # Channel persistence
    send "NICK persist1\r\nUSER p 0 * :P\r\nJOIN #persist\r\nTOPIC #persist :Persisted\r\n" >/dev/null
    OUT=$(send "NICK persist2\r\nUSER p 0 * :P\r\nJOIN #persist\r\nTOPIC #persist\r\n")
    check "Channel operations" "332.*Persisted|TOPIC.*Persisted" "$OUT"
    
    # Kicked user scenario
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK kicked\r\nUSER k 0 * :K\r\n'
        sleep 1.5
    } | nc localhost "$SERVER_PORT" > "$TMPDIR/kicked.txt" 2>&1 &
    PID=$!
    sleep 0.3
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK kickown\r\nUSER k 0 * :K\r\nJOIN #kickscen\r\nINVITE kicked #kickscen\r\n'
        sleep 1
        printf 'KICK #kickscen kicked :test\r\n'
        sleep 1
    } | nc localhost "$SERVER_PORT" > /dev/null 2>&1 &
    PID2=$!
    sleep 0.5
    send "NICK kicked2\r\nUSER k 0 * :K\r\nJOIN #kickscen\r\n" 0.5 >/dev/null
    sleep 1.5
    kill $PID $PID2 2>/dev/null; wait $PID $PID2 2>/dev/null || true
    KICK_OUT=$(cat "$TMPDIR/kicked.txt")
    check "Kicked user scenario" "INVITE|KICK" "$KICK_OUT"
    
    # Nick change in channel
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK observer\r\nUSER o 0 * :O\r\nJOIN #nickchange\r\n'
        sleep 1
    } | nc localhost "$SERVER_PORT" > "$TMPDIR/observer.txt" 2>&1 &
    PID=$!
    sleep 0.5
    send "NICK changer1\r\nUSER c 0 * :C\r\nJOIN #nickchange\r\nNICK changer2\r\n" 1 >/dev/null
    sleep 0.5
    kill $PID 2>/dev/null; wait $PID 2>/dev/null || true
    OBS_OUT=$(cat "$TMPDIR/observer.txt")
    check "Nick change in channel" "NICK.*changer2|changer1.*NICK" "$OBS_OUT"
    
    # Double KICK
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK dblop\r\nUSER d 0 * :D\r\nJOIN #dblkick\r\n'
        sleep 0.5
        printf 'KICK #dblkick dblkick :first\r\n'
        sleep 0.3
        printf 'KICK #dblkick dblkick :second\r\n'
        sleep 0.5
    } | nc localhost "$SERVER_PORT" > "$TMPDIR/dblop.txt" 2>&1 &
    PID=$!
    sleep 0.3
    send "NICK dblkick\r\nUSER d 0 * :D\r\nJOIN #dblkick\r\n" 1.5 >/dev/null
    kill $PID 2>/dev/null; wait $PID 2>/dev/null || true
    DBL_OUT=$(cat "$TMPDIR/dblop.txt")
    check "Double KICK → 441" "441|KICK.*first" "$DBL_OUT"
    
    # MODE +kl combo
    OUT=$(send "NICK mpm1\r\nUSER m 0 * :M\r\nJOIN #mpm\r\nMODE #mpm +kl pass 10\r\n")
    check "MODE +kl with params" "MODE.*\+.*k.*l|\+.*l.*k" "$OUT"
    
    # Already on channel
    {
        [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
        printf 'NICK already\r\nUSER a 0 * :A\r\nJOIN #already\r\n'
        sleep 1
    } | nc localhost "$SERVER_PORT" > /dev/null 2>&1 &
    PID=$!
    sleep 0.5
    OUT=$(send "NICK invdup\r\nUSER i 0 * :I\r\nJOIN #already\r\nINVITE already #already\r\n")
    kill $PID 2>/dev/null; wait $PID 2>/dev/null || true
    check "443 already on channel" "443" "$OUT"
    
    # PART with reason
    OUT=$(send "NICK reason1\r\nUSER r 0 * :R\r\nJOIN #partreason\r\nPART #partreason :Leaving now\r\n")
    check "PART with reason" "PART.*#partreason" "$OUT"
}

test_crash_resistance() {
    section "13. CRASH RESISTANCE (5 tests)"
    
    OUT=$(send "NICK crash1\r\nUSER c 0 * :C\r\n:\r\nPING ok\r\n")
    check "Empty prefix line" "PONG.*ok" "$OUT"
    
    OUT=$(send "NICK crash2\r\nUSER c 0 * :C\r\n:prefix\r\nPING ok2\r\n")
    check "Prefix-only line" "PONG.*ok2" "$OUT"
    
    OUT=$(send "NICK crash3\r\nUSER c 0 * :C\r\nJOIN #a #b #c #d #e\r\nPING ok3\r\n")
    check "Many JOIN params" "PONG.*ok3" "$OUT"
    
    BINARY=$(printf '\x00\x01\x02\x03')
    OUT=$(send "NICK crash4\r\nUSER c 0 * :C\r\nPRIVMSG #x :$BINARY\r\nPING ok4\r\n")
    check "Binary data survives" "PONG.*ok4" "$OUT"
    
    VERYLONG=$(printf 'X%.0s' {1..1000})
    OUT=$(send "NICK crash5\r\nUSER c 0 * :C\r\n$VERYLONG\r\nPING ok5\r\n")
    check "Very long line" "PONG.*ok5" "$OUT"
}

test_signals() {
    section "14. SIGNAL HANDLING (6 tests)"
    
    local SIG_PASSED=0
    local SIG_TOTAL=6
    
    # Helper functions for signal tests
    sig_start_server() {
        pkill -f "ircserv.*$SERVER_PORT" 2>/dev/null || true
        sleep 0.3
        "$SERVER_BIN" "$SERVER_PORT" "$SERVER_PASS" >/dev/null 2>&1 &
        echo $!
        sleep 0.5
    }
    
    sig_check_down() {
        ! nc -z localhost "$SERVER_PORT" 2>/dev/null
    }
    
    # SIGTERM shutdown
    local PID=$(sig_start_server)
    kill -TERM "$PID" 2>/dev/null
    sleep 0.5
    if sig_check_down; then
        echo -e "  ${GREEN}✅${NC} SIGTERM graceful shutdown"
        SIG_PASSED=$((SIG_PASSED + 1))
    else
        echo -e "  ${RED}❌${NC} SIGTERM shutdown failed"
        pkill -9 -f "ircserv.*$SERVER_PORT" 2>/dev/null
    fi
    
    # SIGINT shutdown
    PID=$(sig_start_server)
    kill -INT "$PID" 2>/dev/null
    sleep 0.5
    if sig_check_down; then
        echo -e "  ${GREEN}✅${NC} SIGINT graceful shutdown"
        SIG_PASSED=$((SIG_PASSED + 1))
    else
        echo -e "  ${RED}❌${NC} SIGINT shutdown failed"
        pkill -9 -f "ircserv.*$SERVER_PORT" 2>/dev/null
    fi
    
    # Restart after SIGTERM
    PID=$(sig_start_server)
    kill -TERM "$PID" 2>/dev/null
    sleep 0.5
    PID=$(sig_start_server)
    local SIG_OUT=$({ printf 'PASS %s\r\nNICK sigtest\r\nUSER s 0 * :S\r\n' "$SERVER_PASS"; sleep 0.3; } | nc -w 1 localhost "$SERVER_PORT" 2>/dev/null)
    kill -TERM "$PID" 2>/dev/null
    if echo "$SIG_OUT" | grep -q "001"; then
        echo -e "  ${GREEN}✅${NC} Restart after SIGTERM"
        SIG_PASSED=$((SIG_PASSED + 1))
    else
        echo -e "  ${RED}❌${NC} Restart failed"
    fi
    
    # Port released
    PID=$(sig_start_server)
    kill -TERM "$PID" 2>/dev/null
    sleep 0.5
    PID=$(sig_start_server)
    if nc -z localhost "$SERVER_PORT" 2>/dev/null; then
        echo -e "  ${GREEN}✅${NC} Port released after SIGTERM"
        SIG_PASSED=$((SIG_PASSED + 1))
    else
        echo -e "  ${RED}❌${NC} Port not released"
    fi
    kill -TERM "$PID" 2>/dev/null
    
    # Multiple signals
    PID=$(sig_start_server)
    kill -INT "$PID" 2>/dev/null
    kill -INT "$PID" 2>/dev/null
    sleep 0.5
    if sig_check_down; then
        echo -e "  ${GREEN}✅${NC} Multiple signals handled"
        SIG_PASSED=$((SIG_PASSED + 1))
    else
        echo -e "  ${RED}❌${NC} Multiple signals issue"
        pkill -9 -f "ircserv.*$SERVER_PORT" 2>/dev/null
    fi
    
    # Rapid restart cycles
    local RESTART_OK=true
    for i in 1 2 3; do
        PID=$(sig_start_server)
        SIG_OUT=$({ printf 'PASS %s\r\nNICK cyc%s\r\nUSER c 0 * :C\r\n' "$SERVER_PASS" "$i"; sleep 0.3; } | nc -w 1 localhost "$SERVER_PORT" 2>/dev/null)
        kill -TERM "$PID" 2>/dev/null
        sleep 0.3
        if ! echo "$SIG_OUT" | grep -q "001"; then
            RESTART_OK=false
            break
        fi
    done
    if [ "$RESTART_OK" = true ]; then
        echo -e "  ${GREEN}✅${NC} Rapid restart cycles"
        SIG_PASSED=$((SIG_PASSED + 1))
    else
        echo -e "  ${RED}❌${NC} Restart cycle failed"
    fi
    
    # Update counters
    PASSED=$((PASSED + SIG_PASSED))
    FAILED=$((FAILED + SIG_TOTAL - SIG_PASSED))
    
    # Restart server for any remaining operations
    if [ "$AUTO_START_SERVER" = true ]; then
        start_server
    fi
}

# =============================================================================
# MAIN
# =============================================================================

main() {
    print_header
    
    # Build if needed
    if [ "$AUTO_START_SERVER" = true ]; then
        if [ ! -f "$SERVER_BIN" ]; then
            build_server
        fi
        start_server
    else
        check_server
    fi
    
    # Run tests
    test_registration
    test_channels
    test_messaging
    test_topic
    test_kick
    test_invite
    test_mode
    test_mode_enforcement
    test_ping_pong
    test_error_handling
    
    if [ "$QUICK_MODE" = false ]; then
        test_stress
        test_advanced
        test_crash_resistance
    fi
    
    if [ "$WITH_SIGNALS" = true ]; then
        # Kill our managed server before signal tests
        if [ -n "$SERVER_PID" ]; then
            kill -TERM "$SERVER_PID" 2>/dev/null
            wait "$SERVER_PID" 2>/dev/null || true
            SERVER_PID=""
        fi
        test_signals
    fi
    
    # Print summary
    echo ""
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    TOTAL=$((PASSED + FAILED))
    echo -e "  ${BOLD}Result: $PASSED/$TOTAL passed${NC}"
    if [ $FAILED -eq 0 ]; then
        echo -e "  ${GREEN}${BOLD}✅ All tests passed!${NC}"
    else
        echo -e "  ${RED}${BOLD}❌ $FAILED tests failed${NC}"
    fi
    echo -e "${BOLD}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
    
    [ $FAILED -eq 0 ]
}

main "$@"
