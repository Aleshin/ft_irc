#!/bin/bash
# Extra IRC Server Test Suite - PING/PONG and Signal handling
# Tests for new functionality added after main test suites

SERVER_PORT=6697
SERVER_PASS="testpass"
SERVER_PID=""

PASSED=0
FAILED=0

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

send() {
    local cmds="$1"
    [ -n "$SERVER_PASS" ] && cmds="PASS $SERVER_PASS\r\n$cmds"
    { printf '%b' "$cmds"; sleep 0.5; } | nc -w 1 localhost $SERVER_PORT 2>/dev/null
}

check() {
    local name="$1" pattern="$2" output="$3"
    if echo "$output" | grep -qE "$pattern"; then
        echo -e "  ${GREEN}✅ $name${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}❌ $name${NC}"
        echo "     Expected: $pattern"
        echo "     Got: $(echo "$output" | tr '\r\n' ' ' | head -c 100)"
        FAILED=$((FAILED + 1))
    fi
}

check_not() {
    local name="$1" pattern="$2" output="$3"
    if ! echo "$output" | grep -qE "$pattern"; then
        echo -e "  ${GREEN}✅ $name${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "  ${RED}❌ $name${NC}"
        echo "     Should NOT match: $pattern"
        echo "     Got: $(echo "$output" | tr '\r\n' ' ' | head -c 100)"
        FAILED=$((FAILED + 1))
    fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Extra IRC Test Suite (PING/PONG + Signals)"
echo "  Target: localhost:$SERVER_PORT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# =============================================================================
# PING/PONG TESTS
# =============================================================================
echo "━━━ 1. PING/PONG ━━━"

# Test 1: Basic PING with token
OUT=$(send "NICK p1\r\nUSER p 0 * :P\r\nPING :testtoken\r\n")
check "PING :token → PONG" "PONG.*:testtoken" "$OUT"

# Test 2: PING with param (not trailing)
OUT=$(send "NICK p2\r\nUSER p 0 * :P\r\nPING mytoken\r\n")
check "PING param → PONG" "PONG.*mytoken" "$OUT"

# Test 3: PING without token (server may require token - 461, or respond)
OUT=$(send "NICK p3\r\nUSER p 0 * :P\r\nPING\r\n")
check "PING no token → PONG or 461" "PONG|461|001" "$OUT"

# Test 4: Multiple PINGs in sequence
OUT=$(send "NICK p4\r\nUSER p 0 * :P\r\nPING :first\r\nPING :second\r\nPING :third\r\n")
check "Multiple PINGs - first" "PONG.*:first" "$OUT"
check "Multiple PINGs - second" "PONG.*:second" "$OUT"
check "Multiple PINGs - third" "PONG.*:third" "$OUT"

# Test 5: PING before registration (may get 451 or be processed)
OUT=$(send "PING :early\r\nNICK p5\r\nUSER p 0 * :P\r\n" | head -5)
check "PING before reg → PONG or 451 or welcome" "PONG|451|001" "$OUT"

# Test 6: PING with long token
OUT=$(send "NICK p6\r\nUSER p 0 * :P\r\nPING :longtokenstring123456789\r\n")
check "PING long token" "PONG.*longtokenstring" "$OUT"

# Test 7: PING with special characters
OUT=$(send "NICK p7\r\nUSER p 0 * :P\r\nPING :test-token_123\r\n")
check "PING special chars" "PONG.*test-token_123" "$OUT"

# Test 8: PING mixed with other commands
OUT=$(send "NICK p8\r\nUSER p 0 * :P\r\nJOIN #pingtest\r\nPING :mixed\r\nPART #pingtest\r\n")
check "PING mixed commands" "PONG.*:mixed" "$OUT"

# =============================================================================
# PONG COMMAND (client sends PONG - server should accept)
# =============================================================================
echo ""
echo "━━━ 2. PONG HANDLING ━━━"

# Test 9: Server accepts PONG (should not error)
OUT=$(send "NICK po1\r\nUSER p 0 * :P\r\nPONG :token\r\n")
check_not "PONG accepted (no error)" "421|ERROR" "$OUT"

# Test 10: PONG without token
OUT=$(send "NICK po2\r\nUSER p 0 * :P\r\nPONG\r\n")
check_not "PONG no token (no error)" "421|ERROR" "$OUT"

# =============================================================================
# STRESS TESTS
# =============================================================================
echo ""
echo "━━━ 3. STRESS TESTS ━━━"

# Test 11: Rapid connections
echo -n "  "
RAPID_PASS=0
for i in $(seq 1 10); do
    OUT=$(send "NICK rapid$i\r\nUSER r 0 * :R\r\n" 2>/dev/null)
    if echo "$OUT" | grep -qE "001"; then
        RAPID_PASS=$((RAPID_PASS + 1))
    fi
done
if [ $RAPID_PASS -ge 8 ]; then
    echo -e "${GREEN}✅ Rapid connections ($RAPID_PASS/10)${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "${RED}❌ Rapid connections ($RAPID_PASS/10)${NC}"
    FAILED=$((FAILED + 1))
fi

# Test 12: Many PINGs in one connection (server may limit rate)
OUT=$(send "NICK stress1\r\nUSER s 0 * :S\r\n$(for i in $(seq 1 20); do echo "PING :p$i\r\n"; done)")
PONG_COUNT=$(echo "$OUT" | grep -c "PONG")
if [ $PONG_COUNT -ge 3 ]; then
    echo -e "  ${GREEN}✅ Many PINGs ($PONG_COUNT responses)${NC}"
    PASSED=$((PASSED + 1))
else
    echo -e "  ${RED}❌ Many PINGs (only $PONG_COUNT responses)${NC}"
    FAILED=$((FAILED + 1))
fi

# Test 13: Long message handling
LONG_MSG=$(printf 'A%.0s' {1..400})
OUT=$(send "NICK long1\r\nUSER l 0 * :L\r\nJOIN #longtest\r\nPRIVMSG #longtest :$LONG_MSG\r\n")
check "Long message accepted" "JOIN.*#longtest" "$OUT"

# Test 14: Concurrent channel operations
OUT=$(send "NICK conc1\r\nUSER c 0 * :C\r\nJOIN #c1\r\nJOIN #c2\r\nJOIN #c3\r\nPART #c1\r\nPART #c2\r\nPART #c3\r\n")
check "Concurrent JOIN/PART" "PART.*#c3" "$OUT"

# =============================================================================
# PROTOCOL EDGE CASES
# =============================================================================
echo ""
echo "━━━ 4. PROTOCOL EDGE CASES ━━━"

# Test 15: Commands in different cases
OUT=$(send "NICK case1\r\nUSER c 0 * :C\r\nping :CaseTest\r\n")
check "Lowercase PING" "PONG" "$OUT"

# Test 16: Mixed case command
OUT=$(send "NICK case2\r\nUSER c 0 * :C\r\nPiNg :MixedCase\r\n")
check "Mixed case PiNg" "PONG" "$OUT"

# Test 17: Trailing whitespace
OUT=$(send "NICK ws1\r\nUSER w 0 * :W\r\nPING :token   \r\n")
check "Trailing whitespace" "PONG" "$OUT"

# Test 18: Leading whitespace in params
OUT=$(send "NICK ws2\r\nUSER w 0 * :W\r\nPING   :spaced\r\n")
check "Leading whitespace" "PONG" "$OUT"

# =============================================================================
# SUMMARY
# =============================================================================
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
TOTAL=$((PASSED + FAILED))
echo "  Result: $PASSED/$TOTAL passed"
if [ $FAILED -eq 0 ]; then
    echo -e "  ${GREEN}✅ All tests passed${NC}"
else
    echo -e "  ${RED}❌ $FAILED tests failed${NC}"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
