#include "Server.hpp"
#include "Message.hpp"
#include <iostream>
#include <cstring>
#include <unistd.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>

// Константы
static const size_t BUFFER_SIZE = 1024;
static const int LISTEN_BACKLOG = 10;

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
    // Закрываем всех клиентов
    for (std::map<int, Client*>::iterator it = _clients.begin(); it != _clients.end(); ++it) {
        close(it->first);
        delete it->second;
    }
    _clients.clear();
    
    // Удаляем каналы
    for (std::map<std::string, Channel*>::iterator it = _channels.begin(); it != _channels.end(); ++it) {
        delete it->second;
    }
    _channels.clear();
    
    // Закрываем серверный сокет
    if (_serverFd >= 0) {
        close(_serverFd);
        _serverFd = -1;
    }
    
    _pollfds.clear();
}

// ============================================================================
// POLL MANAGEMENT
// ============================================================================
// poll() мультиплексирует I/O: следит за множеством FD одновременно

void Server::addPollFd(int fd, short events) {
    struct pollfd pfd;
    pfd.fd = fd;
    pfd.events = events;
    pfd.revents = 0;
    _pollfds.push_back(pfd);
}

// Динамическое обновление POLLOUT для управления отправкой
void Server::updatePollEvents(int fd, short events) {
    for (size_t i = 0; i < _pollfds.size(); ++i) {
        if (_pollfds[i].fd == fd) {
            _pollfds[i].events = events;
            return;
        }
    }
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
        
        while (true) {
            int ret = poll(&_pollfds[0], _pollfds.size(), -1);
            if (ret < 0)
                throw std::runtime_error("poll() failed: " + std::string(strerror(errno)));

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

// ============================================================================
// NETWORK INITIALIZATION
// ============================================================================

void Server::initSocket() {
    // Создание TCP сокета (AF_INET=IPv4, SOCK_STREAM=TCP)
    _serverFd = socket(AF_INET, SOCK_STREAM, 0);
    if (_serverFd < 0)
        throw std::runtime_error("socket() failed: " + std::string(strerror(errno)));

    // SO_REUSEADDR: быстрый перезапуск без "Address already in use"
    int opt = 1;
    if (setsockopt(_serverFd, SOL_SOCKET, SO_REUSEADDR, &opt, sizeof(opt)) < 0)
        throw std::runtime_error("setsockopt() failed: " + std::string(strerror(errno)));

    // Настройка адреса: любой интерфейс, указанный порт
    struct sockaddr_in addr;
    addr.sin_family = AF_INET;
    addr.sin_port = htons(_port);
    addr.sin_addr.s_addr = htonl(INADDR_ANY);

    // Привязка к адресу
    if (bind(_serverFd, (struct sockaddr *)&addr, sizeof(addr)) < 0) {
        close(_serverFd);
        throw std::runtime_error("bind() failed: " + std::string(strerror(errno)));
    }

    // Начало прослушивания
    if (listen(_serverFd, LISTEN_BACKLOG) < 0) {
        close(_serverFd);
        throw std::runtime_error("listen() failed: " + std::string(strerror(errno)));
    }

    setNonBlocking(_serverFd);
}

// Неблокирующий режим: read/write возвращаются немедленно (могут вернуть EAGAIN)
void Server::setNonBlocking(int fd) {
    int flags = fcntl(fd, F_GETFL, 0);
    if (flags < 0)
        throw std::runtime_error("fcntl(F_GETFL) failed: " + std::string(strerror(errno)));
    
    if (fcntl(fd, F_SETFL, flags | O_NONBLOCK) < 0)
        throw std::runtime_error("fcntl(F_SETFL) failed: " + std::string(strerror(errno)));
}

// ============================================================================
// CLIENT CONNECTION HANDLING
// ============================================================================

void Server::acceptClient() {
    struct sockaddr_in client_addr;
    socklen_t addr_len = sizeof(client_addr);

    int new_fd = accept(_serverFd, (struct sockaddr *)&client_addr, &addr_len);
    if (new_fd < 0) {
        std::cerr << "accept() failed: " << strerror(errno) << std::endl;
        return;
    }

    // Проверка дубликатов (страховка)
    if (_clients.count(new_fd)) {
        std::cerr << "Warning: FD " << new_fd << " duplicate!" << std::endl;
        delete _clients[new_fd];
        _clients.erase(new_fd);
    }

    try {
        setNonBlocking(new_fd);
        addPollFd(new_fd, POLLIN);
        _clients[new_fd] = new Client(new_fd);
        std::cout << "Client connected: fd " << new_fd << std::endl;
    } catch (const std::exception &e) {
        std::cerr << "Error setting up client: " << e.what() << std::endl;
        close(new_fd);
        if (_clients.count(new_fd)) {
            delete _clients[new_fd];
            _clients.erase(new_fd);
        }
    }
}

void Server::handleClient(size_t index) {
    int fd = _pollfds[index].fd;
    Client* client = _clients[fd];
    if (!client)
        return;

    readFromClient(*client);

    // Process complete IRC commands
    std::string line;
    while (!(line = client->extractLine()).empty()) {
        try {
            processCommand(*client, line);
        } catch (const std::exception& e) {
            std::cerr << "Command error: " << e.what() << std::endl;
        }
    }

    // Try immediate send, fall back to POLLOUT for remaining data
    flushClientOutput(*client);
}

void Server::flushClientOutput(Client& client) {
    if (client.getOutputBuffer().empty())
        return;

    try {
        writeToClient(client);
    } catch (const std::exception& e) {
        std::cerr << "Write error: " << e.what() << std::endl;
        throw;
    }

    // Update poll events based on buffer state
    if (client.getOutputBuffer().empty())
        updatePollEvents(client.getFd(), POLLIN);
    else
        updatePollEvents(client.getFd(), POLLIN | POLLOUT);
}

void Server::readFromClient(Client& client) {
    char buf[BUFFER_SIZE];
    ssize_t n = recv(client.getFd(), buf, sizeof(buf) - 1, 0);

    if (n == 0) {
        // Client closed connection - mark for delayed removal
        // This allows us to send any pending data first
        std::cout << "Client fd " << client.getFd() << " closed connection" << std::endl;
        client.setPendingDisconnect(true);
        return;
    }

    if (n < 0) {
        if (errno == EAGAIN || errno == EWOULDBLOCK)
            return;
        throw std::runtime_error("recv() failed: " + std::string(strerror(errno)));
    }

    client.appendToInput(std::string(buf, n));
}

void Server::writeToClient(Client& client) {
    std::string& out = client.getOutputBuffer();
    if (out.empty())
        return;

    ssize_t n = send(client.getFd(), out.data(), out.size(), 0);

    if (n < 0) {
        if (errno == EAGAIN || errno == EWOULDBLOCK)
            return;
        throw std::runtime_error("send() failed: " + std::string(strerror(errno)));
    }

    out.erase(0, static_cast<size_t>(n));
}

// ============================================================================
// CLIENT CLEANUP
// ============================================================================

void Server::removeClient(int fd) {
    std::cout << "Removing client: fd " << fd << std::endl;

    close(fd);

    if (_clients.count(fd)) {
        delete _clients[fd];
        _clients.erase(fd);
    }

    for (size_t i = 0; i < _pollfds.size(); ++i) {
        if (_pollfds[i].fd == fd) {
            _pollfds.erase(_pollfds.begin() + i);
            break;
        }
    }
}

// ============================================================================
// IRC PROTOCOL - Command Processing
// ============================================================================

void Server::processCommand(Client& client, const std::string& line) {
    Message msg = Message::parse(line);
    if (!msg.isValid())
        return;

    const std::string& cmd = msg.getCommand();
    
    // Dispatch to appropriate handler
    if (cmd == "PASS") {
        handlePass(client, msg);
    } else if (cmd == "NICK") {
        handleNick(client, msg);
    } else if (cmd == "USER") {
        handleUser(client, msg);
    } else if (cmd == "JOIN") {
        handleJoin(client, msg);
    } else if (cmd == "PART") {
        handlePart(client, msg);
    } else if (cmd == "PRIVMSG") {
        handlePrivmsg(client, msg);
    } else if (cmd == "KICK") {
        handleKick(client, msg);
    } else if (cmd == "INVITE") {
        handleInvite(client, msg);
    } else if (cmd == "TOPIC") {
        handleTopic(client, msg);
    } else if (cmd == "MODE") {
        handleMode(client, msg);
    } else if (cmd == "QUIT") {
        std::cout << "Client requested QUIT" << std::endl;
        removeClient(client.getFd());
    } else {
        // Unknown command
        sendToClient(client, Message::replyParam(ERR_UNKNOWNCOMMAND, 
                      client.getDisplayNick(), cmd, "Unknown command").serialize());
    }
}

void Server::handlePass(Client& client, const Message& msg) {
    const std::string& nick = client.getDisplayNick();
    
    if (msg.getParams().empty()) {
        sendToClient(client, Message::replyParam(ERR_NEEDMOREPARAMS, nick, 
                                                  "PASS", "Not enough parameters").serialize());
        return;
    }

    if (client.isRegistered()) {
        sendToClient(client, Message::reply(ERR_ALREADYREGISTRED, nick, 
                                             "You may not reregister").serialize());
        return;
    }

    std::string password = msg.getParams()[0];
    
    if (password != _password) {
        sendToClient(client, Message::reply(ERR_PASSWDMISMATCH, nick, 
                                             "Password incorrect").serialize());
        return;
    }

    client.setPassword(true);
}

void Server::handleNick(Client& client, const Message& msg) {
    const std::string& nick = client.getDisplayNick();
    
    if (msg.getParams().empty()) {
        sendToClient(client, Message::reply(ERR_NONICKNAMEGIVEN, nick, 
                                             "No nickname given").serialize());
        return;
    }

    std::string newNick = msg.getParams()[0];

    if (!Message::isValidNick(newNick)) {
        sendToClient(client, Message::replyParam(ERR_ERRONEUSNICKNAME, nick, 
                                                  newNick, "Erroneous nickname").serialize());
        return;
    }

    if (getClientByNick(newNick) != NULL) {
        sendToClient(client, Message::replyParam(ERR_NICKNAMEINUSE, nick, 
                                                  newNick, "Nickname is already in use").serialize());
        return;
    }

    std::string oldNick = client.getNickname();
    bool wasRegistered = client.isRegistered();
    
    client.setNickname(newNick);
    
    if (wasRegistered) {
        // Notify about nick change: :oldnick!user@host NICK :newnick
        std::string prefix = oldNick + "!" + client.getUsername() + "@localhost";
        sendToClient(client, Message::fromUser(prefix, "NICK", newNick).serialize());
    } else {
        tryRegisterClient(client);
    }
}

void Server::handleUser(Client& client, const Message& msg) {
    const std::string& nick = client.getDisplayNick();
    
    if (msg.getParams().size() < 3) {
        sendToClient(client, Message::replyParam(ERR_NEEDMOREPARAMS, nick, 
                                                  "USER", "Not enough parameters").serialize());
        return;
    }

    if (client.isRegistered()) {
        sendToClient(client, Message::reply(ERR_ALREADYREGISTRED, nick, 
                                             "You may not reregister").serialize());
        return;
    }

    std::string username = msg.getParams()[0];
    std::string realname = msg.getTrailing();

    if (!Message::isValidUser(username))
        return;

    client.setUsername(username);
    client.setRealname(realname);
    tryRegisterClient(client);
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

// ============================================================================
// REGISTRATION HELPERS
// ============================================================================

void Server::tryRegisterClient(Client& client) {
    // All three conditions must be met: password, nickname, and username
    if (!client.hasPassword() || client.getNickname().empty() || 
        client.getUsername().empty() || client.isRegistered())
        return;

    client.setRegistered(true);
    std::cout << "Client " << client.getNickname() << " registered" << std::endl;

    // Send welcome sequence (001-004)
    const std::string& nick = client.getNickname();
    const std::string& user = client.getUsername();

    sendToClient(client, Message::reply(RPL_WELCOME, nick,
        "Welcome to the Internet Relay Network " + nick + "!" + user + "@localhost").serialize());
    
    sendToClient(client, Message::reply(RPL_YOURHOST, nick,
        "Your host is " + _serverName + ", running version 1.0").serialize());
    
    sendToClient(client, Message::reply(RPL_CREATED, nick,
        "This server was created today").serialize());
    
    sendToClient(client, Message::replyParam(RPL_MYINFO, nick,
        _serverName + " 1.0 o itkol", "").serialize());
}

void Server::sendToClient(Client& client, const std::string& message) {
    client.appendToOutput(message);
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
