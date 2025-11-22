#include "Server.hpp"

#include <iostream>
#include <cstring>
#include <cstdio>
#include <cstdlib>
#include <unistd.h>
#include <fcntl.h>
#include <arpa/inet.h>
#include <sys/socket.h>

Server::Server(int port, const std::string &password)
    : _port(port),
      _password(password),
      _serverName("ircserv"),
      _listenFd(-1)
{}

Server::~Server() {
    if (_listenFd >= 0)
        close(_listenFd);

    for (std::map<int, Client*>::iterator it = _clients.begin(); it != _clients.end(); ++it) {
        close(it->first);
        delete it->second;
    }
}

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

void Server::run() {
    initSocket();
    setupPoll();

    std::cout << "Server listening on port " << _port << std::endl;

    while (1) {
        int ret = poll(&_pfds[0], _pfds.size(), -1);
        if (ret < 0) {
            std::perror("poll");
            break;
        }

        for (size_t i = 0; i < _pfds.size(); ++i) {
            pollfd &pfd = _pfds[i];

            if (pfd.fd == _listenFd && (pfd.revents & POLLIN)) {
                acceptClient();
            }
            else if (pfd.fd != _listenFd) {
                handleClientEvent(i);
            }
        }
    }
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

void Server::handleClientEvent(size_t index) {
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

void Server::handleRead(Client &client, int fd, size_t index) {
    char buf[512];
    int n = recv(fd, buf, sizeof(buf), 0);
    if (n <= 0) {
        removeClient(fd, index);
        return;
    }

    client.input.append(buf, n);

    size_t pos;
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

void Server::removeClient(int fd, size_t index) {
    close(fd);
    delete _clients[fd];
    _clients.erase(fd);
    _pfds.erase(_pfds.begin() + index);
}

void Server::processLine(Client &client, const std::string &line) {
    // PASS
    if (line.compare(0, 5, "PASS ") == 0) {
        if (line.substr(5) == _password)
            client.hasPass = true;
        return;
    }

    // NICK
    if (line.compare(0, 5, "NICK ") == 0) {
        client.nickname = line.substr(5);
        client.hasNick = true;
        return;
    }

    // USER
    if (line.compare(0, 5, "USER ") == 0) {
        std::string rest = line.substr(5);
        size_t pos = rest.find(' ');
        if (pos != std::string::npos)
            client.username = rest.substr(0, pos);
        else
            client.username = rest;
        client.hasUser = true;
        return;
    }

    // Other commands will be added here later
}

void Server::tryRegister(Client &client) {
    if (!client.registered &&
        client.hasPass &&
        client.hasNick &&
        client.hasUser)
    {
        client.registered = true;
        sendToClient(
            client,
            ":" + _serverName +
            " 001 " + client.nickname +
            " :Welcome to the minimal IRC server\r\n"
        );
    }
}

void Server::sendToClient(Client &c, const std::string &msg) {
    c.output += msg;
}
