#include "Server.hpp"
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
            // poll() ждет события, -1 = бесконечно
            int ret = poll(&_pollfds[0], _pollfds.size(), -1);
            if (ret < 0)
                throw std::runtime_error("poll() failed: " + std::string(strerror(errno)));

            // Обратный цикл для безопасного удаления во время итерации
            for (size_t i = _pollfds.size(); i > 0; --i) {
                size_t index = i - 1;
                const int fd = _pollfds[index].fd;
                const short revents = _pollfds[index].revents;

                if (revents & POLLIN) {
                    try {
                        if (fd == _serverFd)
                            acceptClient();
                        else
                            handleClient(index);
                    } catch (const std::exception &e) {
                        std::cerr << "Error on fd " << fd << ": " << e.what() << std::endl;
                        fdsToRemove.push_back(fd);
                    }
                }

                if (revents & POLLOUT && fd != _serverFd) {
                    try {
                        Client* client = _clients[fd];
                        if (client && !client->getOutputBuffer().empty()) {
                            writeToClient(*client);
                            if (client->getOutputBuffer().empty())
                                updatePollEvents(fd, POLLIN);
                        }
                    } catch (const std::exception &e) {
                        std::cerr << "Error on fd " << fd << ": " << e.what() << std::endl;
                        fdsToRemove.push_back(fd);
                    }
                }
            }

            // Отложенное удаление
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

    // Извлечение и обработка IRC команд (разделитель \r\n)
    while (true) {
        std::string line = client->extractLine();
        if (line.empty())
            break;
        
        try {
            processCommand(*client, line);
        } catch (const std::exception& e) {
            std::cerr << "Command error: " << e.what() << std::endl;
        }
    }

    // Включаем POLLOUT если есть данные для отправки
    if (!client->getOutputBuffer().empty())
        updatePollEvents(fd, POLLIN | POLLOUT);
}

void Server::readFromClient(Client& client) {
    char buf[BUFFER_SIZE];
    ssize_t n = recv(client.getFd(), buf, sizeof(buf) - 1, 0);

    if (n == 0) {
        std::cout << "Client fd " << client.getFd() << " disconnected" << std::endl;
        throw std::runtime_error("client disconnected");
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
// IRC PROTOCOL (заглушки для Фазы 2)
// ============================================================================

void Server::processCommand(Client& client, const std::string& line) {
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

// Helper functions (будут реализованы позже)
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
