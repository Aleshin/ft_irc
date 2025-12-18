/**
 * @file IO.cpp
 * @brief Client I/O: reading, writing, buffering, and disconnection
 * 
 * This file handles data flow between server and clients:
 * 
 * readFromClient():
 *   - Reads data into client's input buffer
 *   - Non-blocking: returns immediately if no data
 *   - Detects client disconnect (recv returns 0)
 * 
 * handleClient():
 *   - Extracts complete lines (ending with \r\n) from buffer
 *   - Passes each line to processCommand() for IRC processing
 * 
 * writeToClient() / flushClientOutput():
 *   - Sends pending data from output buffer (one send() per call)
 *   - Event-driven: POLLOUT triggers send when kernel ready
 * 
 * removeClient():
 *   - Notifies channel members about disconnect (QUIT message)
 *   - Removes from all channels and cleans up empty channels
 *   - Closes socket and frees memory
 */

#include "Server.hpp"
#include <iostream>
#include <cstring>
#include <unistd.h>
#include <sys/socket.h>
#include <cerrno>

static const size_t BUFFER_SIZE = 1024;

// ============================================================================
// CLIENT I/O HANDLING
// ============================================================================

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
}

void Server::readFromClient(Client& client) {
    char buf[BUFFER_SIZE];
    ssize_t n = recv(client.getFd(), buf, sizeof(buf) - 1, 0);

    if (n == 0) {
        // Client closed connection - mark for delayed removal
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
    
    // Send once per call - event-driven pattern
    ssize_t n = send(client.getFd(), out.data(), out.size(), 0);

    if (n < 0) {
        if (errno == EAGAIN || errno == EWOULDBLOCK)
            return;  // Kernel buffer full, wait for POLLOUT
        throw std::runtime_error("send() failed: " + std::string(strerror(errno)));
    }

    if (n > 0)
        out.erase(0, static_cast<size_t>(n));
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

// ============================================================================
// CLIENT REMOVAL
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
