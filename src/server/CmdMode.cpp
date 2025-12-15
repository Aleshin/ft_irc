/**
 * @file CmdMode.cpp
 * @brief MODE command: channel modes i, t, k, o, l
 * 
 * MODE #channel            - Query current channel modes
 * MODE #channel <modes>    - Set/unset modes (requires operator)
 * 
 * Supported modes:
 *   +i  invite-only    - Only invited users can join
 *   +t  topic-protect  - Only operators can change topic  
 *   +k  key (password) - Require password to join: +k <key>
 *   +o  operator       - Grant/revoke operator: +o <nick>
 *   +l  limit          - Max users in channel: +l <count>
 * 
 * Examples:
 *   MODE #chat +it           - Set invite-only and topic-protect
 *   MODE #chat +k secret     - Set channel password
 *   MODE #chat +o alice      - Make alice an operator
 *   MODE #chat -o+l bob 50   - Remove bob's op, set limit to 50
 */

#include "Server.hpp"
#include "Message.hpp"
#include <cstdlib>
#include <sstream>

// ============================================================================
// MODE COMMAND
// ============================================================================

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
