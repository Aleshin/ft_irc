/**
 * @file CmdChannel.cpp
 * @brief Channel commands: JOIN, PART, TOPIC, PRIVMSG
 * 
 * JOIN #channel [key]  - Join a channel (create if doesn't exist)
 *   - First user becomes operator (@)
 *   - Checks: invite-only (+i), key (+k), user limit (+l)
 * 
 * PART #channel [:reason]  - Leave a channel
 * 
 * TOPIC #channel [:newtopic]  - Get or set channel topic
 *   - Setting requires operator status if +t mode is set
 * 
 * PRIVMSG <target> :<text>  - Send message to channel or user
 */

#include "Server.hpp"
#include "Message.hpp"

// ============================================================================
// JOIN COMMAND
// ============================================================================

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

// ============================================================================
// PART COMMAND
// ============================================================================

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

// ============================================================================
// TOPIC COMMAND
// ============================================================================

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

// ============================================================================
// PRIVMSG COMMAND
// ============================================================================

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
