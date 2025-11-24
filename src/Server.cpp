#include "Server.hpp"

#include <iostream>
#include <cstdio>
#include <cstdlib>
#include <poll.h>
#include <unistd.h>

Server::Server(int port, const std::string &password)
    : _port(port),
      _password(password),
      _serverName("ircserv"),
      _listenFd(-1)
{}

Server::~Server() {
    if (_listenFd >= 0)
        close(_listenFd);

    for (std::map<int, Client*>::iterator it = _clients.begin();
         it != _clients.end(); ++it)
    {
        close(it->first);
        delete it->second;
    }
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

        for (std::size_t i = 0; i < _pfds.size(); ++i) {
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
