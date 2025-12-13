#include "Message.hpp"
#include <cctype>
#include <algorithm>

// Static member initialization
std::string Message::_serverName = "irc.local";

// ============================================================================
// ORTHODOX CANONICAL FORM
// ============================================================================

Message::Message()
    : _prefix(),
      _command(),
      _params(),
      _trailing(),
      _valid(false) {}

Message::Message(const Message& other)
    : _prefix(other._prefix),
      _command(other._command),
      _params(other._params),
      _trailing(other._trailing),
      _valid(other._valid) {}

Message& Message::operator=(const Message& other) {
    if (this != &other) {
        _prefix = other._prefix;
        _command = other._command;
        _params = other._params;
        _trailing = other._trailing;
        _valid = other._valid;
    }
    return *this;
}

Message::~Message() {}

// ============================================================================
// PARSING - Named Constructor
// ============================================================================

Message Message::parse(const std::string& line) {
    Message msg;

    if (line.empty()) {
        return msg;
    }

    std::string remaining = trim(line);
    size_t pos = 0;

    // 1. Extract prefix (optional, starts with ':')
    if (!remaining.empty() && remaining[0] == ':') {
        pos = remaining.find(' ');
        if (pos == std::string::npos) {
            return msg; // Invalid: prefix without command
        }
        msg._prefix = remaining.substr(1, pos - 1);
        remaining = trim(remaining.substr(pos + 1));
    }

    // 2. Extract command (required)
    pos = remaining.find(' ');
    if (pos == std::string::npos) {
        // Command only, no parameters
        std::transform(remaining.begin(), remaining.end(), 
                      remaining.begin(), ::toupper);
        msg._command = remaining;
        msg._valid = !remaining.empty();
        return msg;
    }

    std::string cmd = remaining.substr(0, pos);
    std::transform(cmd.begin(), cmd.end(), cmd.begin(), ::toupper);
    msg._command = cmd;
    remaining = trim(remaining.substr(pos + 1));

    // 3. Extract parameters
    while (!remaining.empty()) {
        if (remaining[0] == ':') {
            msg._trailing = remaining.substr(1);
            break;
        }

        pos = remaining.find(' ');
        if (pos == std::string::npos) {
            msg._params.push_back(remaining);
            break;
        }

        msg._params.push_back(remaining.substr(0, pos));
        remaining = trim(remaining.substr(pos + 1));
    }

    msg._valid = !msg._command.empty();
    return msg;
}

// ============================================================================
// FLUENT BUILDER
// ============================================================================

Message& Message::prefix(const std::string& p) {
    _prefix = p;
    _valid = true;
    return *this;
}

Message& Message::command(const std::string& c) {
    _command = c;
    _valid = true;
    return *this;
}

Message& Message::param(const std::string& p) {
    _params.push_back(p);
    return *this;
}

Message& Message::trailing(const std::string& t) {
    _trailing = t;
    return *this;
}

// ============================================================================
// SERIALIZATION
// ============================================================================

std::string Message::serialize() const {
    std::ostringstream oss;

    if (!_prefix.empty()) {
        oss << ":" << _prefix << " ";
    }

    oss << _command;

    for (size_t i = 0; i < _params.size(); ++i) {
        oss << " " << _params[i];
    }

    if (!_trailing.empty()) {
        oss << " :" << _trailing;
    }

    oss << "\r\n";
    return oss.str();
}

// ============================================================================
// FACTORY METHODS
// ============================================================================

Message Message::reply(int code, const std::string& target,
                       const std::string& message) {
    Message msg;
    msg._prefix = _serverName;
    msg._command = formatCode(code);
    msg._params.push_back(target);
    if (!message.empty()) {
        msg._trailing = message;
    }
    msg._valid = true;
    return msg;
}

Message Message::replyParam(int code, const std::string& target,
                            const std::string& param,
                            const std::string& message) {
    Message msg;
    msg._prefix = _serverName;
    msg._command = formatCode(code);
    msg._params.push_back(target);
    if (!param.empty()) {
        msg._params.push_back(param);
    }
    if (!message.empty()) {
        msg._trailing = message;
    }
    msg._valid = true;
    return msg;
}

Message Message::fromUser(const std::string& userPrefix,
                          const std::string& cmd,
                          const std::string& target,
                          const std::string& text) {
    Message msg;
    msg._prefix = userPrefix;
    msg._command = cmd;
    msg._params.push_back(target);
    if (!text.empty()) {
        msg._trailing = text;
    }
    msg._valid = true;
    return msg;
}

// ============================================================================
// VALIDATORS
// ============================================================================

bool Message::isValidNick(const std::string& nick) {
    if (nick.empty() || nick.length() > 9) {
        return false;
    }

    // First char: letter or special
    char first = nick[0];
    bool validFirst = std::isalpha(first) ||
                     first == '[' || first == ']' || first == '\\' ||
                     first == '`' || first == '_' || first == '^' ||
                     first == '{' || first == '|' || first == '}';
    
    if (!validFirst) {
        return false;
    }

    // Rest: alphanumeric, special, or hyphen
    for (size_t i = 1; i < nick.length(); ++i) {
        char c = nick[i];
        bool valid = std::isalnum(c) ||
                    c == '[' || c == ']' || c == '\\' ||
                    c == '`' || c == '_' || c == '^' ||
                    c == '{' || c == '|' || c == '}' || c == '-';
        if (!valid) {
            return false;
        }
    }
    return true;
}

bool Message::isValidChannel(const std::string& channel) {
    if (channel.empty() || channel.length() > 50) {
        return false;
    }

    if (channel[0] != '#' && channel[0] != '&') {
        return false;
    }

    for (size_t i = 1; i < channel.length(); ++i) {
        char c = channel[i];
        if (c == ' ' || c == ',' || c == ':' || 
            c == '\r' || c == '\n' || c == 7) {
            return false;
        }
    }
    return true;
}

bool Message::isValidUser(const std::string& user) {
    if (user.empty()) {
        return false;
    }

    for (size_t i = 0; i < user.length(); ++i) {
        char c = user[i];
        if (c == ' ' || c == '@' || c == '\r' || c == '\n') {
            return false;
        }
    }
    return true;
}

// ============================================================================
// GETTERS
// ============================================================================

bool Message::isValid() const { return _valid; }
const std::string& Message::getPrefix() const { return _prefix; }
const std::string& Message::getCommand() const { return _command; }
const std::vector<std::string>& Message::getParams() const { return _params; }
const std::string& Message::getTrailing() const { return _trailing; }
size_t Message::getParamCount() const { return _params.size(); }

// ============================================================================
// SERVER CONFIGURATION
// ============================================================================

void Message::setServerName(const std::string& name) { _serverName = name; }
const std::string& Message::getServerName() { return _serverName; }

// ============================================================================
// PRIVATE HELPERS
// ============================================================================

std::string Message::trim(const std::string& str) {
    size_t start = 0;
    size_t end = str.length();

    while (start < end && std::isspace(str[start])) ++start;
    while (end > start && std::isspace(str[end - 1])) --end;

    return str.substr(start, end - start);
}

std::string Message::formatCode(int code) {
    std::ostringstream oss;
    if (code < 10) oss << "00";
    else if (code < 100) oss << "0";
    oss << code;
    return oss.str();
}
