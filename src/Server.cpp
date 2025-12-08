#include "Server.hpp"
#include <iostream>
#include <cstring>
#include <unistd.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

// Orthodox Canonical Form
Server::Server()
    : _port(6667),
      _password(),
      _serverName("ircserv"),
      _serverFd(-1),
      _pollfds(),
      _clients(),
      _channels() {}

Server::Server(int port, const std::string& password)
    : _port(port),
      _password(password),
      _serverName("ircserv"),
      _serverFd(-1),
      _pollfds(),
      _clients(),
      _channels() {}

Server::Server(const Server& other)
    : _port(other._port),
      _password(other._password),
      _serverName(other._serverName),
      _serverFd(other._serverFd),
      _pollfds(other._pollfds),
      _clients(other._clients),
      _channels(other._channels) {}

Server& Server::operator=(const Server& other) {
    if (this != &other) {
        _port = other._port;
        _password = other._password;
        _serverName = other._serverName;
        _serverFd = other._serverFd;
        _pollfds = other._pollfds;
        _clients = other._clients;
        _channels = other._channels;
    }
    return *this;
}

Server::~Server() {
    cleanup();
}

void Server::cleanup(){
    for (std::map<int, Client*>::iterator it = _clients.begin(); it != _clients.end(); ++it) {
        close(it->first);
        delete it->second;
    }
    
    // Delete all channels
    for (std::map<std::string, Channel*>::iterator it = _channels.begin(); it != _channels.end(); ++it) {
        delete it->second;
    }
    
    // Close server socket
    if (_serverFd >= 0)
        close(_serverFd);
}

void Server::addPollFd(int fd, short events) {
    struct pollfd pfd;
    pfd.fd = fd;
    pfd.events = events;
    pfd.revents = 0;

    _pollfds.push_back(pfd);
}

// Main entry point
void Server::run() {
    try {
        initSocket();

        addPollFd(_serverFd, POLLIN);
        
        // 10 maximum pending clients
        if (listen(_serverFd, 10) < 0) {
            throw std::runtime_error(
                "listen() failed: " + std::string(strerror(errno))
            );
        }
        std::cout << "Server listening on port " << _port << std::endl;

        // Main event loop
        while (true) {
            int ret = poll(&_pollfds[0], _pollfds.size(), -1);
            if (ret < 0) {
                throw std::runtime_error("poll() failed: " + std::string(strerror(errno)));
            }

            for (size_t i = 0; i < _pollfds.size(); ++i) {
                const int fd = _pollfds[i].fd;

                // Read events
                if (_pollfds[i].revents & POLLIN) {
                    try {
                        if (fd == _serverFd) {
                            acceptClient();     // may throw
                        } else {
                            handleClient(i);    // may throw
                        }
                    } catch (const std::exception &e) {
                        std::cerr << "Error handling POLLIN for fd "
                                  << fd << ": " << e.what() << std::endl;

                        removeClient(fd);       // ensure cleanup
                    }
                }

                // Write events
                if (_pollfds[i].revents & POLLOUT) {
                    if (fd != _serverFd) {
                        try {
                            Client* client = _clients[fd];
                            if (client) {
                                writeToClient(*client);  // may throw
                            }
                        } catch (const std::exception &e) {
                            std::cerr << "Error handling POLLOUT for fd "
                                      << fd << ": " << e.what() << std::endl;

                            removeClient(fd);
                        }
                    }
                }
            }
        }
    }
    catch (const std::exception &e) {
        std::cerr << "Fatal server error: " << e.what() << std::endl;
    }
    // Server shuts down
    cleanup();
}


// Network operations (студенты реализуют детально)
void Server::initSocket() {
    // TODO: Students implement socket creation and binding
    //domain AF_INET for Ipv4 AF_INET6 for Ipv6
    //type SOCK_STREAM for TCP
    //protocol 0
    _serverFd = socket(AF_INET, SOCK_STREAM, 0);
    if (_serverFd < 0)
    {
        throw std::runtime_error("socket() failed: " + std::string(strerror(errno)));
    }
    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_port = htons(_port); //Host To Network Short (Host → сеть, 16 бит)
    addr.sin_addr.s_addr = htonl(INADDR_ANY);
    //to reuse socket address in case of bind error
    // int opt = 1;
    // if (setsockopt(_serverFd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0) {
    //     throw std::runtime_error("setsockopt(SO_REUSEADDR) failed: " +
    //     std::string(strerror(errno)));
    // }

    if (bind(_serverFd, (struct sockaddr *)&addr, sizeof(addr)) < 0)
    {
        throw std::runtime_error("bind() failed: " + std::string(strerror(errno)));
    }
}

void Server::setNonBlocking(int fd) {
    if (fcntl(fd, F_SETFL, O_NONBLOCK) < 0) {
        throw std::runtime_error(
            "fcntl(F_SETFL, O_NONBLOCK) failed: " + std::string(strerror(errno))
        );
    }
}

//only establish connection, no checks yet
void Server::acceptClient() {
    struct sockaddr_in client_addr;
    socklen_t addr_len = sizeof(client_addr);

    int new_fd = accept(_serverFd, (struct sockaddr *)&client_addr, &addr_len);
    if (new_fd < 0) {
        std::cerr << "accept() failed: " << strerror(errno) << std::endl;
        return;
    } 
    
    try {
        // 1. Set non-blocking
        setNonBlocking(new_fd);
    }
    catch (const std::exception &e) {
        std::cerr << "Error: " << e.what() << std::endl;
        close(new_fd);                    // Clean up leaked fd
        return;
    }
    // 2. Add new socket to pollfds
    addPollFd(new_fd, POLLIN);

    // 3. Create and store client Add to clients map (duplicate FD assumed impossible)
    _clients[new_fd] = new Client(new_fd);

    std::cout << "New client connected on fd " << new_fd << std::endl;
}


void Server::handleClient(size_t index) {
    // TODO: Students implement client handling
    (void)index;
}

void Server::readFromClient(Client& client, size_t index) {
    // TODO: Students implement reading from client
    (void)client;
    (void)index;
}

void Server::writeToClient(Client& client) {
    // TODO: Students implement writing to client
    (void)client;
}

void Server::removeClient(int fd) { //TO DO пока одна функция при сбое и при штатном отключении
    close(fd);  // close socket

    // free client object
    if (_clients.count(fd)) {
        delete _clients[fd];
        _clients.erase(fd);
    }

    // remove from poll list
    for (size_t i = 0; i < _pollfds.size(); ++i) {
        if (_pollfds[i].fd == fd) {
            _pollfds.erase(_pollfds.begin() + i);
            break;
        }
    }
    //std::cout << "Client on fd " << fd << " disconnected" << std::endl;
}


// IRC protocol handlers (студенты реализуют)
void Server::processCommand(Client& client, const std::string& line) {
    // TODO: Parse command and dispatch to appropriate handler
    (void)client;
    (void)line;
}

void Server::handlePass(Client& client, const Message& msg) {
    (void)client;
    (void)msg;
}

void Server::handleNick(Client& client, const Message& msg) {
    (void)client;
    (void)msg;
}

void Server::handleUser(Client& client, const Message& msg) {
    (void)client;
    (void)msg;
}

void Server::handleJoin(Client& client, const Message& msg) {
    (void)client;
    (void)msg;
}

void Server::handlePart(Client& client, const Message& msg) {
    (void)client;
    (void)msg;
}

void Server::handlePrivmsg(Client& client, const Message& msg) {
    (void)client;
    (void)msg;
}

void Server::handleKick(Client& client, const Message& msg) {
    (void)client;
    (void)msg;
}

void Server::handleInvite(Client& client, const Message& msg) {
    (void)client;
    (void)msg;
}

void Server::handleTopic(Client& client, const Message& msg) {
    (void)client;
    (void)msg;
}

void Server::handleMode(Client& client, const Message& msg) {
    (void)client;
    (void)msg;
}

// Helper functions (студенты реализуют)
void Server::tryRegisterClient(Client& client) {
    (void)client;
}

void Server::sendToClient(Client& client, const std::string& message) {
    (void)client;
    (void)message;
}

void Server::broadcastToChannel(const std::string& channelName,
                                 const std::string& message,
                                 const std::string& excludeNick) {
    (void)channelName;
    (void)message;
    (void)excludeNick;
}

Channel* Server::getChannel(const std::string& name) {
    std::map<std::string, Channel*>::iterator it = _channels.find(name);
    return (it != _channels.end()) ? it->second : NULL;
}

Client* Server::getClientByNick(const std::string& nickname) {
    for (std::map<int, Client*>::iterator it = _clients.begin(); it != _clients.end(); ++it) {
        if (it->second->getNickname() == nickname)
            return it->second;
    }
    return NULL;
}
