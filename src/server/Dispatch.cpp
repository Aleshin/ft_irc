/**
 * @file Dispatch.cpp
 * @brief Command routing: parse message and dispatch to handler
 * 
 * processCommand():
 *   1. Parse raw IRC line into Message object
 *   2. Route to appropriate handler based on command:
 *      - Registration: PASS, NICK, USER
 *      - Channels: JOIN, PART, TOPIC, PRIVMSG  
 *      - Operators: KICK, INVITE, MODE
 *      - Utility: PING, PONG, QUIT
 *   3. Unknown commands get ERR_UNKNOWNCOMMAND (421) response
 * 
 * handlePing():
 *   - Responds with PONG to keep connection alive
 *   - IRC clients send PING periodically
 */

#include "Server.hpp"
#include "Message.hpp"
#include <iostream>

// ============================================================================
// COMMAND DISPATCH
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
    } else if (cmd == "QUIT") {
        std::cout << "Client requested QUIT" << std::endl;
        removeClient(client.getFd());
    } else {
        // Unknown command
        sendToClient(client, Message::replyParam(ERR_UNKNOWNCOMMAND, 
                      client.getDisplayNick(), cmd, "Unknown command").serialize());
    }
}

// ============================================================================
// PING HANDLER
// ============================================================================

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
