#include "Client.hpp"

// ============================================================================
// ORTHODOX CANONICAL FORM
// ============================================================================

Client::Client() 
    : _fd(-1),
      _hasPassword(false),
      _registered(false),
      _pendingDisconnect(false) {}

Client::Client(int fd)
    : _fd(fd),
      _hasPassword(false),
      _registered(false),
      _pendingDisconnect(false) {}

Client::Client(const Client& other)
    : _fd(other._fd),
      _inputBuffer(other._inputBuffer),
      _outputBuffer(other._outputBuffer),
      _nickname(other._nickname),
      _username(other._username),
      _realname(other._realname),
      _hasPassword(other._hasPassword),
      _registered(other._registered),
      _pendingDisconnect(other._pendingDisconnect) {}

Client& Client::operator=(const Client& other) {
    if (this != &other) {
        _fd = other._fd;
        _inputBuffer = other._inputBuffer;
        _outputBuffer = other._outputBuffer;
        _nickname = other._nickname;
        _username = other._username;
        _realname = other._realname;
        _hasPassword = other._hasPassword;
        _registered = other._registered;
        _pendingDisconnect = other._pendingDisconnect;
    }
    return *this;
}

Client::~Client() {}

// ============================================================================
// GETTERS
// ============================================================================

int Client::getFd() const { return _fd; }
const std::string& Client::getNickname() const { return _nickname; }
const std::string& Client::getUsername() const { return _username; }
const std::string& Client::getRealname() const { return _realname; }
const std::string& Client::getInputBuffer() const { return _inputBuffer; }
const std::string& Client::getOutputBuffer() const { return _outputBuffer; }
std::string& Client::getOutputBuffer() { return _outputBuffer; }

bool Client::isRegistered() const { return _registered; }
bool Client::hasPassword() const { return _hasPassword; }
bool Client::isPendingDisconnect() const { return _pendingDisconnect; }

std::string Client::getDisplayNick() const {
    return _nickname.empty() ? "*" : _nickname;
}

// ============================================================================
// SETTERS
// ============================================================================

void Client::setNickname(const std::string& nick) { _nickname = nick; }
void Client::setUsername(const std::string& user) { _username = user; }
void Client::setRealname(const std::string& realname) { _realname = realname; }
void Client::setPassword(bool hasPass) { _hasPassword = hasPass; }
void Client::setRegistered(bool registered) { _registered = registered; }
void Client::setPendingDisconnect(bool pending) { _pendingDisconnect = pending; }

// ============================================================================
// BUFFER OPERATIONS
// ============================================================================

void Client::appendToInput(const std::string& data) { _inputBuffer += data; }
void Client::appendToOutput(const std::string& data) { _outputBuffer += data; }
void Client::clearInputBuffer() { _inputBuffer.clear(); }
void Client::clearOutputBuffer() { _outputBuffer.clear(); }

std::string Client::extractLine() {
    std::string::size_type pos = _inputBuffer.find('\n');
    if (pos == std::string::npos)
        return "";
    
    std::string line = _inputBuffer.substr(0, pos);
    _inputBuffer.erase(0, pos + 1);
    
    // Remove trailing \r if present (IRC uses \r\n)
    if (!line.empty() && line[line.size() - 1] == '\r')
        line.erase(line.size() - 1);
    
    return line;
}
