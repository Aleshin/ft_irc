#ifndef SERVER_HPP
#define SERVER_HPP

#include <string>
#include <vector>
#include <map>
#include <cstddef>   // std::size_t
#include <poll.h>    // pollfd

#include "Client.hpp"
#include "Channel.hpp"

class Server {
public:
    Server(int port, const std::string &password);
    ~Server();

    void run();  // main event loop

private:
    // Low-level networking / event loop
    void initSocket();
    void setupPoll();
    void acceptClient();
    void handleClientEvent(std::size_t index);
    void handleRead(Client &client, int fd, std::size_t index);
    void handleWrite(Client &client, pollfd &pfd);
    void removeClient(int fd, std::size_t index);
    void setNonBlocking(int fd);

    // IRC protocol logic
    void processLine(Client &client, const std::string &line);
    void tryRegister(Client &client);
    void sendToClient(Client &c, const std::string &msg);

private:
    int                     _port;
    std::string             _password;
    std::string             _serverName;

    int                     _listenFd;
    std::vector<pollfd>     _pfds;
    std::map<int, Client*>  _clients;
    std::map<std::string, Channel*> _channels;  // Каналы (ключ = имя канала)
};

#endif // SERVER_HPP
