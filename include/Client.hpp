#ifndef CLIENT_HPP
#define CLIENT_HPP

#include <string>

/**
 * @class Client
 * @brief Represents an IRC client connection
 * 
 * Manages client state including connection data, registration info,
 * and buffered I/O operations.
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
    std::string extractLine();  // Extract complete line from input buffer

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
