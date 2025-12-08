#include "Client.hpp"

// Orthodox Canonical Form
Client::Client() 
    : _fd(-1),
      _inputBuffer(),
      _outputBuffer(),
      _nickname(),
      _username(),
      _hasPassword(false),
      _hasNickname(false),
      _hasUsername(false),
      _registered(false) {}

Client::Client(int fd)
    : _fd(fd),
      _inputBuffer(),
      _outputBuffer(),
      _nickname(),
      _username(),
      _hasPassword(false),
      _hasNickname(false),
      _hasUsername(false),
      _registered(false) {}

Client::Client(const Client& other)
    : _fd(other._fd),
      _inputBuffer(other._inputBuffer),
      _outputBuffer(other._outputBuffer),
      _nickname(other._nickname),
      _username(other._username),
      _hasPassword(other._hasPassword),
      _hasNickname(other._hasNickname),
      _hasUsername(other._hasUsername),
      _registered(other._registered) {}

Client& Client::operator=(const Client& other) {
    if (this != &other) {
        _fd = other._fd;
        _inputBuffer = other._inputBuffer;
        _outputBuffer = other._outputBuffer;
        _nickname = other._nickname;
        _username = other._username;
        _hasPassword = other._hasPassword;
        _hasNickname = other._hasNickname;
        _hasUsername = other._hasUsername;
        _registered = other._registered;
    }
    return *this;
}

Client::~Client() {}

// Getters
int Client::getFd() const { return _fd; }
const std::string& Client::getNickname() const { return _nickname; }
const std::string& Client::getUsername() const { return _username; }
const std::string& Client::getInputBuffer() const { return _inputBuffer; }
const std::string& Client::getOutputBuffer() const { return _outputBuffer; }
std::string& Client::getOutputBuffer() { return _outputBuffer; }

bool Client::isRegistered() const { return _registered; }
bool Client::hasPassword() const { return _hasPassword; }
bool Client::hasNickname() const { return _hasNickname; }
bool Client::hasUsername() const { return _hasUsername; }

// Setters
void Client::setNickname(const std::string& nick) {
    _nickname = nick;
    _hasNickname = true;
}

void Client::setUsername(const std::string& user) {
    _username = user;
    _hasUsername = true;
}

void Client::setPassword(bool hasPass) {
    _hasPassword = hasPass;
}

void Client::setRegistered(bool registered) {
    _registered = registered;
}

// Buffer operations
void Client::appendToInput(const std::string& data) {
    _inputBuffer += data;
}

void Client::appendToOutput(const std::string& data) {
    _outputBuffer += data;
}

void Client::clearInputBuffer() {
    _inputBuffer.clear();
}

void Client::clearOutputBuffer() {
    _outputBuffer.clear();
}

std::string Client::extractLine() {
    std::string::size_type pos = _inputBuffer.find('\n');
    if (pos == std::string::npos)
        return "";
    
    std::string line = _inputBuffer.substr(0, pos);
    _inputBuffer.erase(0, pos + 1);
    
    // Remove \r if present
    if (!line.empty() && line[line.size() - 1] == '\r')
        line.erase(line.size() - 1);
    
    return line;
}
