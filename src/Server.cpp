#include "Server.hpp"
#include "Message.hpp"
#include <iostream>
#include <cstring>
#include <unistd.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <cerrno>
#include <cstdlib>

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

// External signal flag from main.cpp
extern volatile sig_atomic_t g_running;

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
        _clients[new_fd] = new Client(new_fd);
        addPollFd(new_fd, POLLIN);
        std::cout << "Client connected: fd " << new_fd << std::endl;
    } catch (const std::exception &e) {
        std::cerr << "Error setting up client: " << e.what() << std::endl;
        close(new_fd);
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
    while (client->hasCompleteLine()) {
        line = client->extractLine();
        // Skip empty lines (just \r\n)
        if (line.empty())
            continue;
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
    
    while (!out.empty()) {
        ssize_t n = send(client.getFd(), out.data(), out.size(), 0);

        if (n < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK)
                return;  // Would block, try again later
            throw std::runtime_error("send() failed: " + std::string(strerror(errno)));
        }

        if (n == 0)
            return;

        out.erase(0, static_cast<size_t>(n));
    }
}

// ============================================================================
// CLIENT CLEANUP
// ============================================================================

void Server::removeClient(int fd) {
    std::cout << "Removing client: fd " << fd << std::endl;

    // Get client info before deletion
    Client* client = NULL;
    if (_clients.count(fd)) {
        client = _clients[fd];
    }

    // Remove client from all channels and delete empty ones
    if (client && !client->getNickname().empty()) {
        const std::string& nick = client->getNickname();
        std::vector<std::string> emptyChannels;

        for (std::map<std::string, Channel*>::iterator it = _channels.begin(); 
             it != _channels.end(); ++it) {
            Channel* channel = it->second;
            if (channel->hasMember(nick)) {
                // Notify other channel members about quit
                std::string quitMsg = ":" + client->getPrefix() + " QUIT :Connection closed\r\n";
                broadcastToChannel(it->first, quitMsg, nick);
                
                channel->removeMember(nick);  // Also removes from operators
                channel->removeInvited(nick);
                
                if (channel->getMembers().empty())
                    emptyChannels.push_back(it->first);
            }
        }

        // Delete empty channels
        for (size_t i = 0; i < emptyChannels.size(); ++i) {
            delete _channels[emptyChannels[i]];
            _channels.erase(emptyChannels[i]);
        }
    }

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
    } else if (cmd == "PING") {
        handlePing(client, msg);
    } else if (cmd == "PONG") {
        // PONG from client - just acknowledge, no response needed
        // Clients send PONG in response to server PING for keep-alive
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
    
    if (!requireParams(client, msg, 1, "PASS"))
        return;

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
        std::string nickMsg = Message::fromUser(prefix, "NICK", newNick).serialize();
        
        // Send to the client itself
        sendToClient(client, nickMsg);
        
        // Send to all users in common channels and update channel member lists
        std::set<int> notified;
        notified.insert(client.getFd());
        
        for (std::map<std::string, Channel*>::iterator it = _channels.begin();
             it != _channels.end(); ++it) {
            Channel* chan = it->second;
            if (chan->hasMember(oldNick)) {  // Check with OLD nick (channel hasn't been updated yet)
                // Update channel member list: remove old nick, add new nick
                chan->removeMember(oldNick);
                chan->addMember(newNick);
                
                // Also update operator status if applicable
                if (chan->isOperator(oldNick)) {
                    chan->removeOperator(oldNick);
                    chan->addOperator(newNick);
                }
                
                // Notify all members in this channel
                const std::set<std::string>& members = chan->getMembers();
                for (std::set<std::string>::const_iterator mit = members.begin();
                     mit != members.end(); ++mit) {
                    Client* member = getClientByNick(*mit);
                    if (member && notified.find(member->getFd()) == notified.end()) {
                        sendToClient(*member, nickMsg);
                        notified.insert(member->getFd());
                    }
                }
            }
        }
    } else {
        tryRegisterClient(client);
    }
}

void Server::handleUser(Client& client, const Message& msg) {
    const std::string& nick = client.getDisplayNick();
    
    if (!requireParams(client, msg, 3, "USER"))
        return;

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
    const std::string& nick = client.getDisplayNick();
    
    if (!requireRegistered(client))
        return;
    
    if (!requireParams(client, msg, 1, "JOIN"))
        return;
    
    std::string channelName = msg.getParams()[0];
    
    // Validate channel name
    if (!Message::isValidChannel(channelName)) {
        sendToClient(client, Message::replyParam(ERR_NOSUCHCHANNEL, nick,
            channelName, "No such channel").serialize());
        return;
    }
    
    // Get or create channel
    Channel* channel = getChannel(channelName);
    if (!channel) {
        channel = new Channel(channelName);
        _channels[channelName] = channel;
        // First user becomes operator
        channel->addOperator(client.getNickname());
    }
    
    // Check if already on channel
    if (channel->hasMember(client.getNickname()))
        return;
    
    // Check invite-only mode (allow if invited)
    if (channel->isInviteOnly() && !channel->isInvited(nick)) {
        sendToClient(client, Message::replyParam(ERR_INVITEONLYCHAN, nick,
            channelName, "Cannot join channel (+i)").serialize());
        return;
    }
    
    // Check channel key
    if (!channel->getKey().empty()) {
        std::string providedKey = (msg.getParams().size() > 1) ? msg.getParams()[1] : "";
        if (providedKey != channel->getKey()) {
            sendToClient(client, Message::replyParam(ERR_BADCHANNELKEY, nick,
                channelName, "Cannot join channel (+k)").serialize());
            return;
        }
    }
    
    // Check user limit
    if (channel->getUserLimit() > 0 && 
        static_cast<int>(channel->getMembers().size()) >= channel->getUserLimit()) {
        sendToClient(client, Message::replyParam(ERR_CHANNELISFULL, nick,
            channelName, "Cannot join channel (+l)").serialize());
        return;
    }
    
    // Add member to channel and remove from invite list
    channel->addMember(client.getNickname());
    channel->removeInvited(nick);
    
    // Notify all channel members (including the joining user)
    std::string joinMsg = Message::fromUser(client.getPrefix(), "JOIN", channelName).serialize();
    broadcastToChannel(channelName, joinMsg, "");
    
    // Send topic if exists
    if (!channel->getTopic().empty()) {
        sendToClient(client, Message::replyParam(RPL_TOPIC, nick,
            channelName, channel->getTopic()).serialize());
    } else {
        sendToClient(client, Message::replyParam(RPL_NOTOPIC, nick,
            channelName, "No topic is set").serialize());
    }
    
    // Send names list (353 + 366)
    std::string names;
    const std::set<std::string>& members = channel->getMembers();
    for (std::set<std::string>::const_iterator it = members.begin(); 
         it != members.end(); ++it) {
        if (!names.empty()) names += " ";
        if (channel->isOperator(*it)) names += "@";
        names += *it;
    }
    
    // RPL_NAMREPLY: :server 353 nick = #channel :@op user1 user2
    sendToClient(client, Message()
        .prefix(_serverName)
        .command("353")
        .param(nick)
        .param("=")
        .param(channelName)
        .trailing(names)
        .serialize());
    
    // RPL_ENDOFNAMES: :server 366 nick #channel :End of /NAMES list
    sendToClient(client, Message::replyParam(RPL_ENDOFNAMES, nick,
        channelName, "End of /NAMES list").serialize());
}

void Server::handlePart(Client& client, const Message& msg) {
    if (!requireRegistered(client))
        return;
    
    if (!requireParams(client, msg, 1, "PART"))
        return;
    
    std::string channelName = msg.getParams()[0];
    std::string reason = msg.getTrailing().empty() ? client.getNickname() : msg.getTrailing();
    
    Channel* channel = requireChannel(client, channelName);
    if (!channel)
        return;
    
    if (!requireOnChannel(client, channel, channelName))
        return;
    
    // Notify channel and remove member
    std::string partMsg = Message::fromUser(client.getPrefix(), "PART", channelName, reason).serialize();
    broadcastToChannel(channelName, partMsg, "");
    
    channel->removeMember(client.getNickname());
    deleteChannelIfEmpty(channelName);
}

void Server::handlePrivmsg(Client& client, const Message& msg) {
    const std::string& nick = client.getDisplayNick();
    
    if (!requireRegistered(client))
        return;
    
    if (!requireParams(client, msg, 1, "PRIVMSG"))
        return;
    
    std::string target = msg.getParams()[0];
    std::string text = msg.getTrailing();
    
    if (text.empty()) {
        sendToClient(client, Message::replyParam(ERR_NEEDMOREPARAMS, nick,
            "PRIVMSG", "Not enough parameters").serialize());
        return;
    }
    
    std::string privmsg = Message::fromUser(client.getPrefix(), "PRIVMSG", target, text).serialize();
    
    // Check if target is a channel
    if (Message::isValidChannel(target)) {
        Channel* channel = getChannel(target);
        if (!channel) {
            sendToClient(client, Message::replyParam(ERR_NOSUCHCHANNEL, nick,
                target, "No such channel").serialize());
            return;
        }
        
        if (!channel->hasMember(client.getNickname())) {
            sendToClient(client, Message::replyParam(ERR_CANNOTSENDTOCHAN, nick,
                target, "Cannot send to channel").serialize());
            return;
        }
        
        // Send to all except sender
        broadcastToChannel(target, privmsg, client.getNickname());
    } else {
        // Private message to user
        Client* targetClient = getClientByNick(target);
        if (!targetClient) {
            sendToClient(client, Message::replyParam(ERR_NOSUCHNICK, nick,
                target, "No such nick/channel").serialize());
            return;
        }
        
        sendToClient(*targetClient, privmsg);
    }
}

void Server::handleKick(Client& client, const Message& msg) {
    const std::string& nick = client.getNickname();
    
    if (!requireParams(client, msg, 2, "KICK"))
        return;
    
    const std::string& channelName = msg.getParams()[0];
    const std::string& targetNick = msg.getParams()[1];
    std::string reason = msg.getTrailing().empty() ? targetNick : msg.getTrailing();
    
    Channel* channel = requireChannel(client, channelName);
    if (!channel)
        return;
    
    if (!requireOnChannel(client, channel, channelName))
        return;
    
    if (!requireOperator(client, channel, channelName))
        return;
    
    // Check if target is on the channel
    if (!channel->hasMember(targetNick)) {
        sendToClient(client, Message::replyParam(ERR_USERNOTINCHANNEL, nick,
            targetNick + " " + channelName, "They aren't on that channel").serialize());
        return;
    }
    
    // Send KICK message to all channel members
    std::string kickMsg = Message::fromUser(client.getPrefix(), "KICK",
        channelName + " " + targetNick, reason).serialize();
    broadcastToChannel(channelName, kickMsg, "");
    
    // Remove target from channel (removeMember also removes from operators)
    channel->removeMember(targetNick);
    channel->removeInvited(targetNick);
    
    deleteChannelIfEmpty(channelName);
}

void Server::handleInvite(Client& client, const Message& msg) {
    const std::string& nick = client.getNickname();
    
    if (!requireParams(client, msg, 2, "INVITE"))
        return;
    
    const std::string& targetNick = msg.getParams()[0];
    const std::string& channelName = msg.getParams()[1];
    
    Channel* channel = requireChannel(client, channelName);
    if (!channel)
        return;
    
    if (!requireOnChannel(client, channel, channelName))
        return;
    
    // Check if client is operator (required for invite-only channels)
    if (channel->isInviteOnly() && !channel->isOperator(nick)) {
        sendToClient(client, Message::replyParam(ERR_CHANOPRIVSNEEDED, nick,
            channelName, "You're not channel operator").serialize());
        return;
    }
    
    Client* target = getClientByNick(targetNick);
    if (!target) {
        sendToClient(client, Message::replyParam(ERR_NOSUCHNICK, nick,
            targetNick, "No such nick/channel").serialize());
        return;
    }
    
    // Check if target is already on channel
    if (channel->hasMember(targetNick)) {
        sendToClient(client, Message::replyParam(ERR_USERONCHANNEL, nick,
            targetNick + " " + channelName, "is already on channel").serialize());
        return;
    }
    
    // Add to invite list and send notifications
    channel->addInvited(targetNick);
    
    // Send RPL_INVITING to inviter
    sendToClient(client, Message::replyParam(RPL_INVITING, nick,
        channelName, targetNick).serialize());
    
    // Send INVITE notification to target (no trailing colon for channel)
    sendToClient(*target, Message::fromUser2Params(client.getPrefix(), "INVITE",
        targetNick, channelName).serialize());
}

void Server::handleTopic(Client& client, const Message& msg) {
    const std::string& nick = client.getNickname();
    
    if (!requireParams(client, msg, 1, "TOPIC"))
        return;
    
    const std::string& channelName = msg.getParams()[0];
    
    Channel* channel = requireChannel(client, channelName);
    if (!channel)
        return;
    
    if (!requireOnChannel(client, channel, channelName))
        return;
    
    // If no trailing - get topic (query mode)
    if (msg.getTrailing().empty() && msg.getParamCount() == 1) {
        if (channel->getTopic().empty()) {
            sendToClient(client, Message::replyParam(RPL_NOTOPIC, nick,
                channelName, "No topic is set").serialize());
        } else {
            sendToClient(client, Message::replyParam(RPL_TOPIC, nick,
                channelName, channel->getTopic()).serialize());
        }
        return;
    }
    
    // Setting topic - check permissions if +t
    if (channel->isTopicRestricted() && !channel->isOperator(nick)) {
        sendToClient(client, Message::replyParam(ERR_CHANOPRIVSNEEDED, nick,
            channelName, "You're not channel operator").serialize());
        return;
    }
    
    // Set the topic
    channel->setTopic(msg.getTrailing());
    
    // Broadcast to channel
    std::string topicMsg = Message::fromUser(client.getPrefix(), "TOPIC",
        channelName, channel->getTopic()).serialize();
    broadcastToChannel(channelName, topicMsg, "");
}

void Server::handleMode(Client& client, const Message& msg) {
    const std::string& nick = client.getNickname();
    
    if (!requireParams(client, msg, 1, "MODE"))
        return;
    
    const std::string& target = msg.getParams()[0];
    
    // Skip user modes (not required by subject)
    if (!Message::isValidChannel(target))
        return;
    
    Channel* channel = requireChannel(client, target);
    if (!channel)
        return;
    
    // If no mode string - query current modes
    if (msg.getParamCount() == 1) {
        std::string modes = "+";
        std::string modeParams;
        if (channel->isInviteOnly()) modes += "i";
        if (channel->isTopicRestricted()) modes += "t";
        if (!channel->getKey().empty()) {
            modes += "k";
            modeParams += " " + channel->getKey();
        }
        if (channel->getUserLimit() > 0) {
            modes += "l";
            std::ostringstream oss;
            oss << channel->getUserLimit();
            modeParams += " " + oss.str();
        }
        if (modes == "+") modes = "";
        sendToClient(client, Message::replyParam(RPL_CHANNELMODEIS, nick,
            target, modes + modeParams).serialize());
        return;
    }
    
    if (!requireOnChannel(client, channel, target))
        return;
    
    if (!requireOperator(client, channel, target))
        return;
    
    // Parse mode string and apply changes
    const std::string& modeStr = msg.getParams()[1];
    bool adding = true;
    size_t paramIdx = 2;
    std::string addModes, removeModes;
    std::string addParams, removeParams;
    
    for (size_t i = 0; i < modeStr.length(); ++i) {
        char c = modeStr[i];
        
        if (c == '+') { adding = true; continue; }
        if (c == '-') { adding = false; continue; }
        
        switch (c) {
            case 'i':
                channel->setInviteOnly(adding);
                (adding ? addModes : removeModes) += 'i';
                break;
                
            case 't':
                channel->setTopicRestricted(adding);
                (adding ? addModes : removeModes) += 't';
                break;
                
            case 'k':
                if (adding && paramIdx < msg.getParamCount()) {
                    channel->setKey(msg.getParams()[paramIdx]);
                    addModes += 'k';
                    addParams += " " + msg.getParams()[paramIdx++];
                } else if (!adding) {
                    channel->setKey("");
                    removeModes += 'k';
                }
                break;
                
            case 'o':
                if (paramIdx < msg.getParamCount()) {
                    const std::string& targetNick = msg.getParams()[paramIdx++];
                    if (channel->hasMember(targetNick)) {
                        if (adding) {
                            channel->addOperator(targetNick);
                            addModes += 'o';
                            addParams += " " + targetNick;
                        } else {
                            channel->removeOperator(targetNick);
                            removeModes += 'o';
                            removeParams += " " + targetNick;
                        }
                    }
                }
                break;
                
            case 'l':
                if (adding && paramIdx < msg.getParamCount()) {
                    int limit = std::atoi(msg.getParams()[paramIdx].c_str());
                    if (limit > 0) {
                        channel->setUserLimit(limit);
                        addModes += 'l';
                        addParams += " " + msg.getParams()[paramIdx];
                    }
                    ++paramIdx;
                } else if (!adding) {
                    channel->setUserLimit(0);
                    removeModes += 'l';
                }
                break;
        }
    }
    
    // Build formatted mode string: +modes-modes params
    std::string appliedModes;
    if (!addModes.empty()) appliedModes += "+" + addModes;
    if (!removeModes.empty()) appliedModes += "-" + removeModes;
    
    if (!appliedModes.empty()) {
        std::string modeMsg = Message::fromUser(client.getPrefix(), "MODE",
            target + " " + appliedModes + addParams + removeParams, "").serialize();
        broadcastToChannel(target, modeMsg, "");
    }
}

void Server::handlePing(Client& client, const Message& msg) {
    // PING requires a token to echo back
    std::string token;
    if (!msg.getParams().empty()) {
        token = msg.getParams()[0];
    } else if (!msg.getTrailing().empty()) {
        token = msg.getTrailing();
    } else {
        token = _serverName;
    }
    
    // Reply with PONG
    sendToClient(client, ":" + _serverName + " PONG " + _serverName + " :" + token + "\r\n");
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
    // Immediately try to flush output buffer
    try {
        flushClientOutput(client);
    } catch (...) {
        // Ignore errors, will be handled in main loop
    }
}

void Server::broadcastToChannel(const std::string& channelName,
                                 const std::string& message,
                                 const std::string& excludeNick) {
    Channel* channel = getChannel(channelName);
    if (!channel)
        return;
    
    const std::set<std::string>& members = channel->getMembers();
    for (std::set<std::string>::const_iterator it = members.begin();
         it != members.end(); ++it) {
        if (*it == excludeNick)
            continue;
        
        Client* client = getClientByNick(*it);
        if (client)
            sendToClient(*client, message);
    }
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

// ============================================================================
// VALIDATION HELPERS (reduce code duplication)
// ============================================================================

bool Server::requireRegistered(Client& client) {
    if (client.isRegistered())
        return true;
    sendToClient(client, Message::reply(ERR_NOTREGISTERED, client.getDisplayNick(),
        "You have not registered").serialize());
    return false;
}

bool Server::requireParams(Client& client, const Message& msg, size_t count, const std::string& cmd) {
    if (msg.getParamCount() >= count)
        return true;
    sendToClient(client, Message::replyParam(ERR_NEEDMOREPARAMS, client.getDisplayNick(),
        cmd, "Not enough parameters").serialize());
    return false;
}

Channel* Server::requireChannel(Client& client, const std::string& name) {
    Channel* channel = getChannel(name);
    if (!channel) {
        sendToClient(client, Message::replyParam(ERR_NOSUCHCHANNEL, client.getDisplayNick(),
            name, "No such channel").serialize());
    }
    return channel;
}

bool Server::requireOnChannel(Client& client, Channel* channel, const std::string& name) {
    if (channel->hasMember(client.getNickname()))
        return true;
    sendToClient(client, Message::replyParam(ERR_NOTONCHANNEL, client.getDisplayNick(),
        name, "You're not on that channel").serialize());
    return false;
}

bool Server::requireOperator(Client& client, Channel* channel, const std::string& name) {
    if (channel->isOperator(client.getNickname()))
        return true;
    sendToClient(client, Message::replyParam(ERR_CHANOPRIVSNEEDED, client.getDisplayNick(),
        name, "You're not channel operator").serialize());
    return false;
}

void Server::deleteChannelIfEmpty(const std::string& name) {
    Channel* channel = getChannel(name);
    if (channel && channel->getMembers().empty()) {
        delete channel;
        _channels.erase(name);
    }
}
