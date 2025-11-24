#include "Server.hpp"

#include <string>

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
        std::size_t pos = rest.find(' ');
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
