/**
 * @file CmdRegistration.cpp
 * @brief Client registration commands: PASS, NICK, USER
 * 
 * This file implements the IRC client registration sequence.
 * A client must complete registration before using other commands:
 * 1. PASS <password>  - Authenticate with server password
 * 2. NICK <nickname>  - Set unique nickname
 * 3. USER <user> ...  - Provide username and realname
 * 
 * After all three, tryRegisterClient() sends the welcome sequence (001-004).
 */

#include "Server.hpp"
#include "Message.hpp"
#include <iostream>

// ============================================================================
// PASS COMMAND
// ============================================================================

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

// ============================================================================
// NICK COMMAND
// ============================================================================

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
            if (chan->hasMember(oldNick)) {
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

// ============================================================================
// USER COMMAND
// ============================================================================

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

// ============================================================================
// REGISTRATION COMPLETION
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
