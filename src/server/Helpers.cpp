/**
 * @file Helpers.cpp
 * @brief Utility functions: sending, broadcasting, lookups, validation
 * 
 * Message sending:
 *   - sendToClient() - Queue message and enable POLLOUT
 *   - broadcastToChannel() - Send to all channel members (except one)
 * 
 * Lookup helpers:
 *   - getChannel() - Find channel by name
 *   - getClientByNick() - Find client by nickname
 * 
 * Validation helpers (reduce code duplication):
 *   - requireRegistered() - Check if client completed registration
 *   - requireParams() - Check minimum parameter count
 *   - requireChannel() - Find channel or send error
 *   - requireOnChannel() - Check if client is channel member
 *   - requireOperator() - Check if client is channel operator
 * 
 * deleteChannelIfEmpty():
 *   - Remove channel when last member leaves
 */

#include "Server.hpp"
#include "Message.hpp"

// ============================================================================
// SEND HELPERS
// ============================================================================

void Server::sendToClient(Client& client, const std::string& message) {
    bool wasEmpty = client.getOutputBuffer().empty();
    client.appendToOutput(message);
    
    // If buffer was empty, enable POLLOUT to trigger send
    if (wasEmpty && !client.getOutputBuffer().empty())
        updatePollEvents(client.getFd(), POLLIN | POLLOUT);
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

// ============================================================================
// GETTERS
// ============================================================================

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
// VALIDATION HELPERS
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
