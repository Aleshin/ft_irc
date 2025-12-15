/**
 * @file CmdOperator.cpp
 * @brief Channel operator commands: KICK, INVITE
 * 
 * KICK #channel <nick> [:reason]  - Remove user from channel
 *   - Requires operator status on the channel
 *   - Notifies all channel members
 * 
 * INVITE <nick> #channel  - Invite user to join channel
 *   - Allows user to bypass +i (invite-only) mode
 *   - Requires operator status for invite-only channels
 */

#include "Server.hpp"
#include "Message.hpp"

// ============================================================================
// KICK COMMAND
// ============================================================================

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

// ============================================================================
// INVITE COMMAND
// ============================================================================

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
