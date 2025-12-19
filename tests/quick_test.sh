#!/bin/bash
# Quick IRC Server Test Suite - Minimal tests for subject requirements
# Validated against ngircd reference implementation

SERVER_PORT=6697
SERVER_PASS="testpass"

PASSED=0
FAILED=0

send() {
    local cmds="$1"
    [ -n "$SERVER_PASS" ] && cmds="PASS $SERVER_PASS\r\n$cmds"
    { printf '%b' "$cmds"; sleep 0.5; } | nc -w 1 localhost $SERVER_PORT 2>/dev/null
}

check() {
    local name="$1" pattern="$2" output="$3"
    if echo "$output" | grep -qE "$pattern"; then
        echo "  ✅ $name"
        PASSED=$((PASSED + 1))
    else
        echo "  ❌ $name"
        echo "     Expected: $pattern"
        echo "     Got: $(echo "$output" | tr '\r\n' ' ' | head -c 80)"
        FAILED=$((FAILED + 1))
    fi
}

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "  Quick IRC Test Suite"
echo "  Target: localhost:$SERVER_PORT"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

# === REGISTRATION ===
echo "Registration"
OUT=$(send "NICK u1\r\nUSER u 0 * :U\r\n")
check "NICK/USER → 001 welcome" "001" "$OUT"

OUT=$(send "PRIVMSG x :hi\r\n" | head -1)
check "Command before reg → 451" "451" "$OUT"

# === CHANNELS ===
echo "Channels"
OUT=$(send "NICK u2\r\nUSER u 0 * :U\r\nJOIN #test\r\n")
check "JOIN → 353 names" "353" "$OUT"

OUT=$(send "NICK u3\r\nUSER u 0 * :U\r\nJOIN #new\r\n")
check "First user is operator" "@u3" "$OUT"

OUT=$(send "NICK u4\r\nUSER u 0 * :U\r\nJOIN #partch\r\nPART #partch :bye\r\n")
check "PART → echo" "PART.*#partch" "$OUT"

# === MESSAGING ===
echo "Messaging"
OUT=$(send "NICK u5\r\nUSER u 0 * :U\r\nPRIVMSG nobody :hi\r\n")
check "PRIVMSG unknown user → 401" "401" "$OUT"

# === TOPIC ===
echo "Topic"
OUT=$(send "NICK u6\r\nUSER u 0 * :U\r\nJOIN #topic\r\nTOPIC #topic :Hello\r\n")
check "TOPIC set → echo or 332" "TOPIC.*#topic|332" "$OUT"

# === KICK ===
echo "Kick"
OUT=$(send "NICK u7\r\nUSER u 0 * :U\r\nJOIN #kick\r\nKICK #kick nobody\r\n")
check "KICK unknown → 401 or 441" "401|441" "$OUT"

# === INVITE ===
echo "Invite"
OUT=$(send "NICK u8\r\nUSER u 0 * :U\r\nJOIN #inv\r\nINVITE nobody #inv\r\n")
check "INVITE unknown → 401" "401" "$OUT"

# === MODE ===
echo "Mode"
OUT=$(send "NICK u9\r\nUSER u 0 * :U\r\nJOIN #mode\r\nMODE #mode\r\n")
check "MODE query → 324" "324" "$OUT"

OUT=$(send "NICK u10\r\nUSER u 0 * :U\r\nJOIN #mode2\r\nMODE #mode2 +i\r\n")
check "MODE +i → set" "MODE.*\\+i|324" "$OUT"

OUT=$(send "NICK u11\r\nUSER u 0 * :U\r\nJOIN #mode3\r\nMODE #mode3 +k secret\r\n")
check "MODE +k → set" "MODE.*\\+k|324" "$OUT"

OUT=$(send "NICK u12\r\nUSER u 0 * :U\r\nJOIN #mode4\r\nMODE #mode4 +l 10\r\n")
check "MODE +l → set" "MODE.*\\+l|324" "$OUT"

# === SUMMARY ===
echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
TOTAL=$((PASSED + FAILED))
echo "  Result: $PASSED/$TOTAL passed"
if [ $FAILED -eq 0 ]; then
    echo "  ✅ All tests passed"
else
    echo "  ❌ $FAILED tests failed"
fi
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

[ $FAILED -eq 0 ]
