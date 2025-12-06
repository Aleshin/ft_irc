#include "Message.hpp"

// Orthodox Canonical Form implementation
Message::Message() : _prefix(), _command(), _params() {}

Message::Message(const Message& other) 
    : _prefix(other._prefix), 
      _command(other._command), 
      _params(other._params) {}

Message& Message::operator=(const Message& other) {
    if (this != &other) {
        _prefix = other._prefix;
        _command = other._command;
        _params = other._params;
    }
    return *this;
}

Message::~Message() {}

// Getters
const std::string& Message::getPrefix() const { return _prefix; }
const std::string& Message::getCommand() const { return _command; }
const std::vector<std::string>& Message::getParams() const { return _params; }

// Parsing (студенты реализуют)
Message Message::parse(const std::string& rawMessage) {
    (void)rawMessage; // Suppress unused warning
    Message msg;
    // TODO: Parse IRC message format
    // Format: [:prefix] <command> [params] [:trailing]
    return msg;
}

// Building responses (студенты реализуют)
std::string Message::buildWelcome(const std::string& serverName, const std::string& nick) {
    (void)serverName;
    (void)nick;
    // TODO: Build welcome message
    // Format: :server 001 nick :Welcome message
    return "";
}

std::string Message::buildJoin(const std::string& prefix, const std::string& channel) {
    (void)prefix;
    (void)channel;
    // TODO: Build JOIN message
    // Format: :prefix JOIN :channel
    return "";
}

std::string Message::buildPart(const std::string& prefix, const std::string& channel) {
    (void)prefix;
    (void)channel;
    // TODO: Build PART message
    // Format: :prefix PART :channel
    return "";
}

std::string Message::buildPrivmsg(const std::string& prefix, const std::string& target, const std::string& text) {
    (void)prefix;
    (void)target;
    (void)text;
    // TODO: Build PRIVMSG
    // Format: :prefix PRIVMSG target :text
    return "";
}

std::string Message::buildNumericReply(const std::string& serverName, const std::string& code,
                                       const std::string& target, const std::string& message) {
    (void)serverName;
    (void)code;
    (void)target;
    (void)message;
    // TODO: Build numeric reply
    // Format: :server code target :message
    return "";
}

// Validation (студенты реализуют)
bool Message::isValidNickname(const std::string& nick) {
    (void)nick;
    // TODO: Validate nickname (RFC 2812)
    // Length: 1-9 characters
    // First char: letter
    // Other chars: letters, digits, special chars
    return true;
}

bool Message::isValidChannelName(const std::string& channel) {
    (void)channel;
    // TODO: Validate channel name (RFC 2812)
    // Must start with '#' or '&'
    // Length: 1-50 characters
    return true;
}
