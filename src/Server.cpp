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
    // Close all client connections
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

// Main entry point
void Server::run() {
    initSocket();
    
    std::cout << "Server listening on port " << _port << std::endl;
    
    // Main event loop
    while (true) {
        int ret = poll(&_pollfds[0], _pollfds.size(), -1);
        if (ret < 0) {
            std::cerr << "poll() error" << std::endl;
            break;
        }
        
        for (size_t i = 0; i < _pollfds.size(); ++i) {
            if (_pollfds[i].revents & POLLIN) {
                if (_pollfds[i].fd == _serverFd) {
                    acceptClient();
                } else {
                    handleClient(i);
                }
            }
            
            if (_pollfds[i].revents & POLLOUT) {
                if (_pollfds[i].fd != _serverFd) {
                    Client* client = _clients[_pollfds[i].fd];
                    if (client)
                        writeToClient(*client);
                }
            }
        }
    }
}

// Network operations (студенты реализуют детально)
void Server::initSocket() {
    // TODO: Students implement socket creation and binding
    (void)_port;
}

void Server::setNonBlocking(int fd) {
    fcntl(fd, F_SETFL, O_NONBLOCK);
}

void Server::acceptClient() {
    // TODO: Students implement client acceptance
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

void Server::removeClient(size_t index) {
    // TODO: Students implement client removal
    (void)index;
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
