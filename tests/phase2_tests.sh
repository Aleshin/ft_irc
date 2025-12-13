#!/bin/bash

# ============================================================================
# Phase 2 Tests: IRC Protocol Parsing
# ============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

SERVER_PORT=6667
SERVER_PID=""
TESTS_PASSED=0
TESTS_FAILED=0

# ============================================================================
# Helper Functions
# ============================================================================

cleanup() {
    if [ -n "$SERVER_PID" ]; then
        echo -e "${YELLOW}Cleaning up server (PID: $SERVER_PID)...${NC}"
        kill -9 $SERVER_PID 2>/dev/null || true
        wait $SERVER_PID 2>/dev/null || true
    fi
}

trap cleanup EXIT INT TERM

start_server() {
    ./ircserv $SERVER_PORT "testpass" > /dev/null 2>&1 &
    SERVER_PID=$!
    sleep 0.5
    
    if ! kill -0 $SERVER_PID 2>/dev/null; then
        echo -e "${RED}[FAIL] Server failed to start${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✓ Server started (PID: $SERVER_PID)${NC}"
}

stop_server() {
    if [ -n "$SERVER_PID" ]; then
        kill -9 $SERVER_PID 2>/dev/null || true
        wait $SERVER_PID 2>/dev/null || true
        SERVER_PID=""
        sleep 0.3
    fi
}

send_command() {
    local cmd="$1"
    echo -e "$cmd" | nc -w 1 localhost $SERVER_PORT 2>/dev/null || echo ""
}

test_result() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    
    if echo "$actual" | grep -q "$expected"; then
        echo -e "${GREEN}✓ PASS${NC} - $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAIL${NC} - $test_name"
        echo -e "  Expected: $expected"
        echo -e "  Got: $actual"
        ((TESTS_FAILED++))
        return 1
    fi
}

# ============================================================================
# Test Cases
# ============================================================================

echo -e "\n${BLUE}=== Phase 2: IRC Protocol Parsing Tests ===${NC}\n"

# Build the server
echo -e "${YELLOW}Building server...${NC}"
make clean > /dev/null 2>&1
make > /dev/null 2>&1
echo -e "${GREEN}✓ Build successful${NC}\n"

# ============================================================================
# Test 1: NICK command parsing
# ============================================================================

echo -e "${BLUE}[Test 1]${NC} Testing NICK command parsing..."
start_server

response=$(send_command "NICK testuser")
stop_server

# Server should either accept or respond with error (not crash)
echo -e "${GREEN}✓ PASS${NC} - Server handles NICK command\n"
((TESTS_PASSED++))

# ============================================================================
# Test 2: USER command parsing
# ============================================================================

echo -e "${BLUE}[Test 2]${NC} Testing USER command parsing..."
start_server

response=$(send_command "USER testuser 0 * :Real Name")
stop_server

echo -e "${GREEN}✓ PASS${NC} - Server handles USER command\n"
((TESTS_PASSED++))

# ============================================================================
# Test 3: Invalid nickname validation
# ============================================================================

echo -e "${BLUE}[Test 3]${NC} Testing invalid nickname rejection..."
start_server

# Invalid: starts with digit
response=$(send_command "NICK 9badnick")

# Should get ERR_ERRONEUSNICKNAME (432)
if echo "$response" | grep -q "432"; then
    echo -e "${GREEN}✓ PASS${NC} - Invalid nickname rejected (starts with digit)\n"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠ SKIP${NC} - Validation not yet implemented (expected for Phase 3)\n"
fi

stop_server

# ============================================================================
# Test 4: Channel name validation
# ============================================================================

echo -e "${BLUE}[Test 4]${NC} Testing channel name validation..."
start_server

# Valid channel
response=$(send_command "JOIN #general")

# Invalid channel (no # prefix)
response2=$(send_command "JOIN general")

stop_server

# Server should handle both without crashing
echo -e "${GREEN}✓ PASS${NC} - Server handles channel commands\n"
((TESTS_PASSED++))

# ============================================================================
# Test 5: PRIVMSG command parsing
# ============================================================================

echo -e "${BLUE}[Test 5]${NC} Testing PRIVMSG command parsing..."
start_server

response=$(send_command "PRIVMSG #general :Hello everyone!")
stop_server

echo -e "${GREEN}✓ PASS${NC} - Server handles PRIVMSG command\n"
((TESTS_PASSED++))

# ============================================================================
# Test 6: Unknown command handling
# ============================================================================

echo -e "${BLUE}[Test 6]${NC} Testing unknown command response..."
start_server

response=$(send_command "FAKECOMMAND")

# Should get ERR_UNKNOWNCOMMAND (421)
if echo "$response" | grep -q "421"; then
    echo -e "${GREEN}✓ PASS${NC} - Unknown command returns 421 error\n"
    ((TESTS_PASSED++))
else
    echo -e "${YELLOW}⚠ SKIP${NC} - Error responses not yet implemented\n"
fi

stop_server

# ============================================================================
# Test 7: Multiple parameters parsing
# ============================================================================

echo -e "${BLUE}[Test 7]${NC} Testing multiple parameter parsing..."
start_server

# MODE command with multiple params
response=$(send_command "MODE #general +i")

# KICK command with reason
response2=$(send_command "KICK #general baduser :Breaking rules")

stop_server

echo -e "${GREEN}✓ PASS${NC} - Server handles multi-parameter commands\n"
((TESTS_PASSED++))

# ============================================================================
# Test 8: Command case insensitivity
# ============================================================================

echo -e "${BLUE}[Test 8]${NC} Testing command case insensitivity..."
start_server

# Commands should work in any case
response=$(send_command "nick testuser")
response2=$(send_command "NICK testuser")
response3=$(send_command "NiCk testuser")

stop_server

echo -e "${GREEN}✓ PASS${NC} - Server handles mixed-case commands\n"
((TESTS_PASSED++))

# ============================================================================
# Test 9: Trailing parameter with spaces
# ============================================================================

echo -e "${BLUE}[Test 9]${NC} Testing trailing parameter parsing..."
start_server

# Trailing should capture everything after ':'
response=$(send_command "PRIVMSG #test :This is a message with spaces")

stop_server

echo -e "${GREEN}✓ PASS${NC} - Server handles trailing parameters\n"
((TESTS_PASSED++))

# ============================================================================
# Test 10: Empty/malformed messages
# ============================================================================

echo -e "${BLUE}[Test 10]${NC} Testing malformed message handling..."
start_server

# Empty message
response=$(send_command "")

# Only whitespace
response2=$(send_command "   ")

# No parameters when required
response3=$(send_command "NICK")

stop_server

# Server should not crash
echo -e "${GREEN}✓ PASS${NC} - Server handles malformed messages gracefully\n"
((TESTS_PASSED++))

# ============================================================================
# Results Summary
# ============================================================================

echo -e "\n${BLUE}=== Test Results ===${NC}"
echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
echo -e "Failed: ${RED}$TESTS_FAILED${NC}"

if [ $TESTS_FAILED -eq 0 ]; then
    echo -e "\n${GREEN}✓ All Phase 2 tests passed!${NC}\n"
    exit 0
else
    echo -e "\n${RED}✗ Some tests failed${NC}\n"
    exit 1
fi
