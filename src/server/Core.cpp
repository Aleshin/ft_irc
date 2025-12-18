/**
 * @file Core.cpp
 * @brief Server lifecycle: constructors, destructor, cleanup, main event loop
 * 
 * This file contains the core Server class implementation:
 * - Orthodox Canonical Form (constructors, destructor, assignment operator)
 * - cleanup() - Release all resources (clients, channels, sockets)
 * - run() - Main event loop using poll() for I/O multiplexing
 * 
 * The run() loop:
 * 1. poll() waits for events on all file descriptors
 * 2. Accept new connections on server socket
 * 3. Read data from clients with POLLIN
 * 4. Write pending data to clients with POLLOUT
 * 5. Remove disconnected clients after their output is flushed
 */

#include "Server.hpp"
#include <iostream>
#include <cstring>
#include <unistd.h>
#include <cerrno>
#include <csignal>

// External signal flag from main.cpp
extern volatile sig_atomic_t g_running;

// ============================================================================
// ORTHODOX CANONICAL FORM
// ============================================================================

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

// ============================================================================
// RESOURCE MANAGEMENT
// ============================================================================

void Server::cleanup() {
    // Close all clients
    for (std::map<int, Client*>::iterator it = _clients.begin(); it != _clients.end(); ++it) {
        close(it->first);
        delete it->second;
    }
    _clients.clear();
    
    // Delete channels
    for (std::map<std::string, Channel*>::iterator it = _channels.begin(); it != _channels.end(); ++it) {
        delete it->second;
    }
    _channels.clear();
    
    // Close server socket
    if (_serverFd >= 0) {
        close(_serverFd);
        _serverFd = -1;
    }
    
    _pollfds.clear();
}

// ============================================================================
// MAIN EVENT LOOP
// ============================================================================

void Server::run() {
    try {
        initSocket();
        addPollFd(_serverFd, POLLIN);
        std::cout << "Server listening on port " << _port << std::endl;

        std::vector<int> fdsToRemove;
        
        while (g_running) {
            int ret = poll(&_pollfds[0], _pollfds.size(), 1000);  // 1 sec timeout for signal check
            if (ret < 0) {
                if (errno == EINTR)
                    continue;  // Interrupted by signal, check g_running
                throw std::runtime_error("poll() failed: " + std::string(strerror(errno)));
            }
            if (ret == 0)
                continue;  // Timeout, check g_running

            for (size_t i = _pollfds.size(); i > 0; --i) {
                size_t index = i - 1;
                int fd = _pollfds[index].fd;
                short revents = _pollfds[index].revents;
                
                if (fd == _serverFd) {
                    if (revents & POLLIN)
                        acceptClient();
                    continue;
                }

                Client* client = _clients.count(fd) ? _clients[fd] : NULL;
                if (!client)
                    continue;

                // Handle write first (send pending data before reading more)
                if (revents & POLLOUT) {
                    try {
                        flushClientOutput(*client);
                    } catch (...) {
                        fdsToRemove.push_back(fd);
                        continue;
                    }
                }

                // Handle read (skip if pending disconnect)
                if ((revents & POLLIN) && !client->isPendingDisconnect()) {
                    try {
                        handleClient(index);
                    } catch (const std::exception &e) {
                        std::cerr << "Error on fd " << fd << ": " << e.what() << std::endl;
                        fdsToRemove.push_back(fd);
                        continue;
                    }
                }

                // Check if client should be removed
                if (client->isPendingDisconnect() && client->getOutputBuffer().empty())
                    fdsToRemove.push_back(fd);
            }

            for (size_t i = 0; i < fdsToRemove.size(); ++i)
                removeClient(fdsToRemove[i]);
            fdsToRemove.clear();
        }
    } catch (const std::exception &e) {
        std::cerr << "Fatal error: " << e.what() << std::endl;
    }
    cleanup();
}
