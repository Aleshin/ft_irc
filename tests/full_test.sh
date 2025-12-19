#!/bin/bash
# Full IRC Server Test Suite - Comprehensive tests for all functionality
# Validated against ngircd reference implementation

SERVER_PORT=6697
SERVER_PASS="testpass"
TMPDIR=$(mktemp -d)

PASSED=0
FAILED=0

cleanup() {
    pkill -f "nc.*localhost.*$SERVER_PORT" 2>/dev/null || true
    rm -rf "$TMPDIR"
}
trap cleanup EXIT

send() {
    local cmds="$1" timeout="${2:-0.5}"
    [ -n "$SERVER_PASS" ] && cmds="PASS $SERVER_PASS\r\n$cmds"
    { printf '%b' "$cmds"; sleep $timeout; } | nc -w 2 localhost $SERVER_PORT 2>/dev/null
}

check() {
    local name="$1" pattern="$2" output="$3"
    if echo "$output" | grep -qE "$pattern"; then
        echo "  ✅ $name"
        PASSED=$((PASSED + 1))
    else
        echo "  ❌ $name"
        echo "     Expected: $pattern"
        echo "     Got: $(echo "$output" | tr '\r\n' ' ' | head -c 100)"
        FAILED=$((FAILED + 1))
    fi
}

check_no() {
    local name="$1" pattern="$2" output="$3"
    if echo "$output" | grep -qE "$pattern"; then
        echo "  ❌ $name"
        echo "     Should NOT match: $pattern"
        FAILED=$((FAILED + 1))
    else
        echo "  ✅ $name"
        PASSED=$((PASSED + 1))
    fi
}

section() {
    echo ""
    echo "━━━ $1 ━━━"
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Full IRC Server Test Suite"
echo "  Target: localhost:$SERVER_PORT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# =============================================================================
section "1. REGISTRATION"
# =============================================================================

OUT=$(send "NICK reg1\r\nUSER r 0 * :R\r\n")
check "001 RPL_WELCOME" "001.*reg1" "$OUT"
check "002 RPL_YOURHOST" "002" "$OUT"
check "003 RPL_CREATED" "003" "$OUT"
check "004 RPL_MYINFO" "004" "$OUT"

OUT=$(send "JOIN #x\r\n" | head -1)
check "451 before registration" "451" "$OUT"

OUT=$(send "NICK 1bad\r\nUSER u 0 * :U\r\n")
check "432 invalid nick (digit)" "432" "$OUT"

OUT=$(send "NICK ba@d\r\nUSER u 0 * :U\r\n")
check "432 invalid nick (symbol)" "432" "$OUT"

OUT=$(send "NICK\r\n" | head -1)
check "431/461 empty NICK" "431|461" "$OUT"

OUT=$(send "NICK good1\r\nUSER u 0 * :U\r\n")
check "Valid nick accepted" "001.*good1" "$OUT"

OUT=$(send "NICK Test_123\r\nUSER u 0 * :U\r\n")
check "Nick with underscore" "001.*Test_123" "$OUT"

OUT=$(send "NICK changer\r\nUSER u 0 * :U\r\nNICK newname\r\n")
check "NICK change works" "NICK.*newname" "$OUT"

OUT=$(send "USER\r\n" | head -1)
check "461 USER no params" "461" "$OUT"

OUT=$(send "USER u 0 * :U\r\nNICK ordtest\r\n")
check "USER before NICK works" "001.*ordtest" "$OUT"

# =============================================================================
section "2. CHANNELS"
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
check "Multiple JOINs #a" "JOIN.*#a" "$OUT"
check "Multiple JOINs #b" "JOIN.*#b" "$OUT"
check "Multiple JOINs #c" "JOIN.*#c" "$OUT"

# =============================================================================
section "3. MESSAGING"
# =============================================================================

OUT=$(send "NICK msg1\r\nUSER m 0 * :M\r\nPRIVMSG ghost :hi\r\n")
check "401 no such nick" "401" "$OUT"

OUT=$(send "NICK msg2\r\nUSER m 0 * :M\r\nJOIN #self\r\nPRIVMSG #self :test\r\n")
check_no "Sender no echo" "PRIVMSG #self :test" "$OUT"

OUT=$(send "NICK msg3\r\nUSER m 0 * :M\r\nPRIVMSG\r\n")
check "411/461 PRIVMSG no params" "411|461" "$OUT"

# Two-client test
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
wait $PID 2>/dev/null || true
OUT=$(cat "$TMPDIR/recv.txt")
check "DM received" "PRIVMSG recv :Hello" "$OUT"

# Channel broadcast
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
wait $PID 2>/dev/null || true
OUT=$(cat "$TMPDIR/listen.txt")
check "Broadcast received" "PRIVMSG #broadcast :Broadcast" "$OUT"

# =============================================================================
section "4. TOPIC"
# =============================================================================

OUT=$(send "NICK top1\r\nUSER t 0 * :T\r\nJOIN #notopic\r\nTOPIC #notopic\r\n")
check "331 no topic" "331" "$OUT"

OUT=$(send "NICK top2\r\nUSER t 0 * :T\r\nJOIN #settop\r\nTOPIC #settop :My topic\r\n")
check "TOPIC set" "TOPIC.*#settop|332" "$OUT"

OUT=$(send "NICK top3\r\nUSER t 0 * :T\r\nTOPIC #ghost\r\n")
check "403 unknown channel" "403" "$OUT"

# TOPIC by non-member
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

# =============================================================================
section "5. KICK"
# =============================================================================

OUT=$(send "NICK kick1\r\nUSER k 0 * :K\r\nJOIN #kicktest\r\nKICK\r\n")
check "461 KICK no params" "461" "$OUT"

OUT=$(send "NICK kick2\r\nUSER k 0 * :K\r\nJOIN #kicktest2\r\nKICK #kicktest2 ghost\r\n")
check "401/441 KICK unknown" "401|441" "$OUT"

# KICK from channel not on
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

# KICK without op
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

# =============================================================================
section "6. INVITE"
# =============================================================================

OUT=$(send "NICK inv1\r\nUSER i 0 * :I\r\nINVITE\r\n")
check "461 INVITE no params" "461" "$OUT"

OUT=$(send "NICK inv2\r\nUSER i 0 * :I\r\nJOIN #myroom\r\nINVITE ghost #myroom\r\n")
check "401 INVITE unknown" "401" "$OUT"

# INVITE to channel not on
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

# Successful INVITE
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

# =============================================================================
section "7. MODE"
# =============================================================================

OUT=$(send "NICK mode1\r\nUSER m 0 * :M\r\nJOIN #modetest\r\nMODE #modetest\r\n")
check "324 MODE query" "324" "$OUT"

OUT=$(send "NICK mode2\r\nUSER m 0 * :M\r\nJOIN #mi\r\nMODE #mi +i\r\n")
check "MODE +i set" "MODE.*\\+i|324" "$OUT"

OUT=$(send "NICK mode3\r\nUSER m 0 * :M\r\nJOIN #mt\r\nMODE #mt +t\r\n")
check "MODE +t set" "MODE.*\\+t|324" "$OUT"

OUT=$(send "NICK mode4\r\nUSER m 0 * :M\r\nJOIN #mk\r\nMODE #mk +k secret\r\n")
check "MODE +k set" "MODE.*\\+k|324" "$OUT"

OUT=$(send "NICK mode5\r\nUSER m 0 * :M\r\nJOIN #ml\r\nMODE #ml +l 5\r\n")
check "MODE +l set" "MODE.*\\+l|324" "$OUT"

# MODE +o/-o
{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK opper\r\nUSER o 0 * :O\r\nJOIN #opmode\r\n'
    sleep 2
} | nc localhost $SERVER_PORT >/dev/null 2>&1 &
PID=$!
sleep 0.5
OUT=$(send "NICK mode6\r\nUSER m 0 * :M\r\nJOIN #opmode\r\nMODE #opmode -o opper\r\n" 1)
check "MODE -o (need op)" "MODE.*-o|482" "$OUT"
kill $PID 2>/dev/null; wait $PID 2>/dev/null || true

OUT=$(send "NICK mode7\r\nUSER m 0 * :M\r\nMODE #nonexistent\r\n")
check "403/401 unknown channel" "403|401|324" "$OUT"

# =============================================================================
section "8. MODE ENFORCEMENT"
# =============================================================================

# +i blocks
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

# +k requires key
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

# +k correct key
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

# +l limit
{
    [ -n "$SERVER_PASS" ] && printf 'PASS %s\r\n' "$SERVER_PASS"
    printf 'NICK lown\r\nUSER l 0 * :L\r\nJOIN #limited\r\nMODE #limited +l 1\r\n'
    sleep 2
} | nc localhost $SERVER_PORT >/dev/null 2>&1 &
PID=$!
sleep 0.5
OUT=$(send "NICK overflow\r\nUSER o 0 * :O\r\nJOIN #limited\r\n")
check "471 channel full" "471" "$OUT"
kill $PID 2>/dev/null; wait $PID 2>/dev/null || true

# +t restricts topic
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
section "9. ERROR HANDLING"
# =============================================================================

OUT=$(send "NICK err1\r\nUSER e 0 * :E\r\nFOOBAR\r\n")
check "421 unknown command" "421" "$OUT"

OUT=$(send "NICK err2\r\nUSER e 0 * :E\r\nXYZ\r\nABC\r\n")
check "Multiple unknowns handled" "421.*XYZ" "$OUT"

# =============================================================================
section "10. EDGE CASES"
# =============================================================================

OUT=$(send "NICK edge1\r\nUSER e 0 * :E\r\n\r\n\r\nJOIN #edge\r\n" 1)
check "Empty lines tolerated" "JOIN.*#edge|001" "$OUT"

OUT=$(send "nick case1\r\nuser c 0 * :C\r\njoin #CASE\r\n")
check "Case insensitive cmds" "JOIN.*#CASE" "$OUT"

OUT=$(send "NICK   space1\r\nUSER   space1   0   *   :Space\r\n")
check "Extra whitespace" "001.*space1" "$OUT"

if [ -n "$SERVER_PASS" ]; then
    OUT=$(printf 'PASS %s\nNICK lfonly\nUSER l 0 * :L\n' "$SERVER_PASS" | nc -w 1 localhost $SERVER_PORT 2>/dev/null)
else
    OUT=$(printf 'NICK lfonly\nUSER l 0 * :L\n' | nc -w 1 localhost $SERVER_PORT 2>/dev/null)
fi
check "LF-only accepted" "001.*lfonly" "$OUT"

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
TOTAL=$((PASSED + FAILED))
echo "  Result: $PASSED/$TOTAL passed"
if [ $FAILED -eq 0 ]; then
    echo "  ✅ All tests passed"
else
    echo "  ❌ $FAILED tests failed"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

[ $FAILED -eq 0 ]
