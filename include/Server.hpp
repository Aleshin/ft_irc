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
 * @brief Main IRC server - coordinates all components
 * 
 * The Server class is the central hub of the IRC server:
 * - Manages the TCP socket and accepts new connections
 * - Uses poll() for non-blocking I/O multiplexing
 * - Stores all clients in _clients map (key = file descriptor)
 * - Stores all channels in _channels map (key = channel name)
 * - Dispatches IRC commands to appropriate handlers
 * 
 * Architecture:
 *   Server contains: Client* (many), Channel* (many)
 *   Server uses: Message (for parsing/building IRC messages)
 * 
 * File organization (src/server/):
 *   Core.cpp          - Lifecycle (constructor, destructor, run)
 *   Network.cpp       - Socket setup and client acceptance
 *   IO.cpp            - Reading and writing data
 *   Dispatch.cpp      - Command routing
 *   CmdRegistration.cpp - PASS, NICK, USER
 *   CmdChannel.cpp    - JOIN, PART, TOPIC, PRIVMSG
 *   CmdOperator.cpp   - KICK, INVITE
 *   CmdMode.cpp       - MODE
 *   Helpers.cpp       - Utility functions
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
    // Network operations
    void initSocket();
    void setNonBlocking(int fd);
    void acceptClient();
    void handleClient(size_t index);
    void readFromClient(Client& client);
    void writeToClient(Client& client);
    void flushClientOutput(Client& client);
    void removeClient(int fd);


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
    void handlePing(Client& client, const Message& msg);

    // Helpers
    void tryRegisterClient(Client& client);
    void addPollFd(int fd, short events);
    void updatePollEvents(int fd, short events);
    void sendToClient(Client& client, const std::string& message);
    void broadcastToChannel(const std::string& channelName, 
                           const std::string& message, 
                           const std::string& excludeNick);
    Channel* getChannel(const std::string& name);
    Client* getClientByNick(const std::string& nickname);
    void cleanup();
    
    // Validation helpers (reduce code duplication)
    bool requireRegistered(Client& client);
    bool requireParams(Client& client, const Message& msg, size_t count, const std::string& cmd);
    Channel* requireChannel(Client& client, const std::string& name);
    bool requireOnChannel(Client& client, Channel* channel, const std::string& name);
    bool requireOperator(Client& client, Channel* channel, const std::string& name);
    void deleteChannelIfEmpty(const std::string& name);

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
