#include "Server.hpp"

#include <iostream>
#include <cstring>
#include <cstdio>
#include <cstdlib>
#include <unistd.h>
#include <fcntl.h>
#include <arpa/inet.h>
#include <sys/socket.h>

void Server::setNonBlocking(int fd) {
    fcntl(fd, F_SETFL, O_NONBLOCK);
}

void Server::initSocket() {
    _listenFd = socket(AF_INET, SOCK_STREAM, 0);
    if (_listenFd < 0) {
        std::perror("socket");
        std::exit(1);
    }

    int yes = 1;
    setsockopt(_listenFd, SOL_SOCKET, SO_REUSEADDR, &yes, sizeof(yes));

    sockaddr_in addr;
    std::memset(&addr, 0, sizeof(addr));
    addr.sin_family      = AF_INET;
    addr.sin_addr.s_addr = INADDR_ANY;
    addr.sin_port        = htons(_port);

    if (bind(_listenFd, (sockaddr*)&addr, sizeof(addr)) < 0) {
        std::perror("bind");
        std::exit(1);
    }

    if (listen(_listenFd, 10) < 0) {
        std::perror("listen");
        std::exit(1);
    }

    setNonBlocking(_listenFd);
}

void Server::setupPoll() {
    pollfd p;
    p.fd = _listenFd;
    p.events = POLLIN;
    p.revents = 0;
    _pfds.push_back(p);
}

void Server::acceptClient() {
    int fd = accept(_listenFd, NULL, NULL);
    if (fd < 0)
        return;

    setNonBlocking(fd);

    pollfd p;
    p.fd = fd;
    p.events = POLLIN;
    p.revents = 0;
    _pfds.push_back(p);

    _clients[fd] = new Client(fd);

    std::cout << "New client fd=" << fd << std::endl;
}

void Server::handleClientEvent(std::size_t index) {
    pollfd &pfd = _pfds[index];
    int fd = pfd.fd;

    if (pfd.revents & (POLLHUP | POLLERR)) {
        removeClient(fd, index);
        return;
    }

    Client &client = *(_clients[fd]);

    if (pfd.revents & POLLIN)
        handleRead(client, fd, index);

    if (pfd.revents & POLLOUT)
        handleWrite(client, pfd);

    if (!client.output.empty())
        pfd.events = POLLIN | POLLOUT;
}

void Server::handleRead(Client &client, int fd, std::size_t index) {
    char buf[512];
    int n = recv(fd, buf, sizeof(buf), 0);
    if (n <= 0) {
        removeClient(fd, index);
        return;
    }

    client.input.append(buf, n);

    std::size_t pos;
    while ((pos = client.input.find('\n')) != std::string::npos) {
        std::string line = client.input.substr(0, pos);
        if (!line.empty() && line[line.size() - 1] == '\r')
            line.erase(line.size() - 1);

        client.input.erase(0, pos + 1);

        processLine(client, line);
        tryRegister(client);
    }
}

void Server::handleWrite(Client &client, pollfd &pfd) {
    std::string &out = client.output;
    if (out.empty()) {
        pfd.events = POLLIN;
        return;
    }

    int n = send(client.fd, out.c_str(), out.size(), 0);
    if (n > 0)
        out.erase(0, n);

    if (out.empty())
        pfd.events = POLLIN;
}

void Server::removeClient(int fd, std::size_t index) {
    close(fd);
    delete _clients[fd];
    _clients.erase(fd);
    _pfds.erase(_pfds.begin() + index);
}
