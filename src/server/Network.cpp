/**
 * @file Network.cpp
 * @brief Socket initialization and client connection acceptance
 * 
 * This file handles low-level network operations:
 * 
 * initSocket():
 *   1. Create TCP socket (AF_INET + SOCK_STREAM)
 *   2. Set SO_REUSEADDR to allow quick server restart
 *   3. Bind to specified port on all interfaces (INADDR_ANY)
 *   4. Start listening with backlog queue
 *   5. Set non-blocking mode for async I/O
 * 
 * acceptClient():
 *   1. Accept incoming connection
 *   2. Create Client object and add to _clients map
 *   3. Add fd to poll array with POLLIN events
 * 
 * Poll management:
 *   - addPollFd() - Add new fd to poll array
 *   - updatePollEvents() - Change events (POLLIN/POLLOUT) for fd
 */

#include "Server.hpp"
#include <iostream>
#include <cstring>
#include <unistd.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <cerrno>

static const int LISTEN_BACKLOG = 10;

// ============================================================================
// POLL MANAGEMENT
// ============================================================================

void Server::addPollFd(int fd, short events) {
    struct pollfd pfd;
    pfd.fd = fd;
    pfd.events = events;
    pfd.revents = 0;
    _pollfds.push_back(pfd);
}

void Server::updatePollEvents(int fd, short events) {
    for (size_t i = 0; i < _pollfds.size(); ++i) {
        if (_pollfds[i].fd == fd) {
            _pollfds[i].events = events;
            return;
        }
    }
}

// ============================================================================
// SOCKET INITIALIZATION
// ============================================================================

void Server::initSocket() {
    // Create TCP socket (AF_INET=IPv4, SOCK_STREAM=TCP)
    _serverFd = socket(AF_INET, SOCK_STREAM, 0);
    if (_serverFd < 0)
        throw std::runtime_error("socket() failed: " + std::string(strerror(errno)));

    // SO_REUSEADDR: fast restart without "Address already in use"
    int opt = 1;
    if (setsockopt(_serverFd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0)
        throw std::runtime_error("setsockopt() failed: " + std::string(strerror(errno)));

    // Configure address: any interface, specified port
    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_port = htons(_port);
    addr.sin_addr.s_addr = htonl(INADDR_ANY);

    // Bind to address
    if (bind(_serverFd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        close(_serverFd);
        throw std::runtime_error("bind() failed: " + std::string(strerror(errno)));
    }

    // Start listening
    if (listen(_serverFd, LISTEN_BACKLOG) < 0) {
        close(_serverFd);
        throw std::runtime_error("listen() failed: " + std::string(strerror(errno)));
    }

    setNonBlocking(_serverFd);
}

void Server::setNonBlocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags < 0)
        throw std::runtime_error("fcntl(F_GETFL) failed: " + std::string(strerror(errno)));
    
    if (fcntl(fd, F_SETFL, flags | O_NONBLOCK) < 0)
        throw std::runtime_error("fcntl(F_SETFL) failed: " + std::string(strerror(errno)));
}

// ============================================================================
// CLIENT ACCEPT
// ============================================================================

void Server::acceptClient() {
    struct sockaddr_in client_addr;
    socklen_t addr_len = sizeof(client_addr);

    int new_fd = accept(_serverFd, (struct sockaddr *)&client_addr, &addr_len);
    if (new_fd < 0) {
        std::cerr << "accept() failed: " << strerror(errno) << std::endl;
        return;
    }

    // Check for duplicates (safety)
    if (_clients.count(new_fd)) {
        std::cerr << "Warning: FD " << new_fd << " duplicate!" << std::endl;
        delete _clients[new_fd];
        _clients.erase(new_fd);
    }

    try {
        setNonBlocking(new_fd);
        _clients[new_fd] = new Client(new_fd);
        addPollFd(new_fd, POLLIN);
        std::cout << "Client connected: fd " << new_fd << std::endl;
    } catch (const std::exception &e) {
        std::cerr << "Error setting up client: " << e.what() << std::endl;
        close(new_fd);
    }
}
