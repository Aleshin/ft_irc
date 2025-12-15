#ifndef CLIENT_HPP
#define CLIENT_HPP

#include <string>

/**
 * @class Client
 * @brief Represents a single IRC client connection
 * 
 * Each Client object tracks:
 * - File descriptor (_fd) for the socket connection
 * - Input/output buffers for async I/O
 * - Registration data: nickname, username, realname
 * - State flags: password verified, registered, pending disconnect
 * 
 * Registration sequence:
 *   1. Client connects (new Client created)
 *   2. Client sends PASS command -> hasPassword() = true
 *   3. Client sends NICK command -> nickname set
 *   4. Client sends USER command -> username/realname set
 *   5. All conditions met -> isRegistered() = true, welcome sent
 * 
 * Buffer management:
 *   - Input buffer: accumulates received data until \r\n found
 *   - Output buffer: queues messages to send
 *   - extractLine(): removes and returns one complete IRC line
 * 
 * Graceful disconnect:
 *   - setPendingDisconnect(true) marks client for removal
 *   - Client stays alive until output buffer is flushed
 */
class Client {
public:
    // Orthodox Canonical Form (C++98)
    Client();
    explicit Client(int fd);
    Client(const Client& other);
    Client& operator=(const Client& other);
    ~Client();

    // Getters
    int getFd() const;
    const std::string& getNickname() const;
    const std::string& getUsername() const;
    const std::string& getRealname() const;
    const std::string& getInputBuffer() const;
    std::string& getOutputBuffer();

    const std::string& getOutputBuffer() const;
    bool isRegistered() const;
    bool hasPassword() const;
    bool isPendingDisconnect() const;
    std::string getDisplayNick() const;  // Returns nickname or "*" for IRC replies
    std::string getPrefix() const;        // Returns nick!user@host for IRC messages

    // Setters
    void setNickname(const std::string& nick);
    void setUsername(const std::string& user);
    void setRealname(const std::string& realname);
    void setPassword(bool hasPass);
    void setRegistered(bool registered);
    void setPendingDisconnect(bool pending);
    
    // Buffer operations
    void appendToInput(const std::string& data);
    void appendToOutput(const std::string& data);
    void clearInputBuffer();
    void clearOutputBuffer();
    std::string extractLine();      // Extract complete line from input buffer
    bool hasCompleteLine() const;   // Check if buffer has a complete line

private:
    int         _fd;
    std::string _inputBuffer;
    std::string _outputBuffer;
    std::string _nickname;
    std::string _username;
    std::string _realname;
    bool        _hasPassword;
    bool        _registered;
    bool        _pendingDisconnect;
};

#endif // CLIENT_HPP
