#ifndef SERVER_HPP
#define SERVER_HPP

#include <string>
#include <vector>
#include <map>
#include <poll.h>
#include <netinet/in.h>

#include "Client.hpp"

class Server {
public:
    Server(int port, const std::string &password);
    ~Server();

    void run();

private:
    // Core loop helpers
    void initSocket();
    void setupPoll();
    void acceptClient();
    void handleClientEvent(size_t index);
    void handleRead(Client &client, int fd, size_t index);
    void handleWrite(Client &client, pollfd &pfd);
    void removeClient(int fd, size_t index);

    // Command handling
    void processLine(Client &client, const std::string &line);
    void tryRegister(Client &client);

    // Internal helpers
    void setNonBlocking(int fd);
    void sendToClient(Client &c, const std::string &msg);

private:
    int                     _port;
    std::string             _password;
    std::string             _serverName;

    int                     _listenFd;
    std::vector<pollfd>     _pfds;
    std::map<int, Client*>  _clients;
};

#endif // SERVER_HPP
