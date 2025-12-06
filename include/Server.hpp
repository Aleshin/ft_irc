#ifndef SERVER_HPP
#define SERVER_HPP

#include <string>
#include <vector>
#include <map>
#include <poll.h>

#include "Client.hpp"
#include "Channel.hpp"
#include "Message.hpp"

/**
 * @class Server
 * @brief Main IRC server class
 * 
 * Manages network I/O, client connections, channels, and IRC command processing.
 * Uses poll() for non-blocking I/O multiplexing.
 */
class Server {
public:
    // Orthodox Canonical Form (C++98)
    Server();
    Server(int port, const std::string& password);
    Server(const Server& other);
    Server& operator=(const Server& other);
    ~Server();

    // Main entry point
    void run();

private:
    // Network operations (students implement)
    void initSocket();
    void setNonBlocking(int fd);
    void acceptClient();
    void handleClient(size_t index);
    void readFromClient(Client& client, size_t index);
    void writeToClient(Client& client);
    void removeClient(size_t index);

    // IRC protocol (students implement)
    void processCommand(Client& client, const std::string& line);
    void handlePass(Client& client, const Message& msg);
    void handleNick(Client& client, const Message& msg);
    void handleUser(Client& client, const Message& msg);
    void handleJoin(Client& client, const Message& msg);
    void handlePart(Client& client, const Message& msg);
    void handlePrivmsg(Client& client, const Message& msg);
    void handleKick(Client& client, const Message& msg);
    void handleInvite(Client& client, const Message& msg);
    void handleTopic(Client& client, const Message& msg);
    void handleMode(Client& client, const Message& msg);

    // Helpers
    void tryRegisterClient(Client& client);
    void sendToClient(Client& client, const std::string& message);
    void broadcastToChannel(const std::string& channelName, 
                           const std::string& message, 
                           const std::string& excludeNick);
    Channel* getChannel(const std::string& name);
    Client* getClientByNick(const std::string& nickname);

private:
    int                     _port;
    std::string             _password;
    std::string             _serverName;
    int                     _serverFd;
    std::vector<pollfd>     _pollfds;
    std::map<int, Client*>  _clients;
    std::map<std::string, Channel*> _channels;
};

#endif // SERVER_HPP
