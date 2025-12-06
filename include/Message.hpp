#ifndef MESSAGE_HPP
#define MESSAGE_HPP

#include <string>
#include <vector>

// IRC numeric reply codes (RFC 2812)
#define RPL_WELCOME          "001"
#define RPL_TOPIC            "332"
#define RPL_NAMREPLY         "353"
#define RPL_ENDOFNAMES       "366"

#define ERR_NOSUCHNICK       "401"
#define ERR_NOSUCHCHANNEL    "403"
#define ERR_CANNOTSENDTOCHAN "404"
#define ERR_UNKNOWNCOMMAND   "421"
#define ERR_NONICKNAMEGIVEN  "431"
#define ERR_ERRONEUSNICKNAME "432"
#define ERR_NICKNAMEINUSE    "433"
#define ERR_NOTONCHANNEL     "442"
#define ERR_NEEDMOREPARAMS   "461"
#define ERR_PASSWDMISMATCH   "464"
#define ERR_CHANNELISFULL    "471"
#define ERR_INVITEONLYCHAN   "473"
#define ERR_BADCHANNELKEY    "475"
#define ERR_CHANOPRIVSNEEDED "482"

/**
 * @class Message
 * @brief IRC message parser and builder
 * 
 * Handles parsing of incoming IRC messages and building of outgoing responses.
 * Follows IRC protocol specification (RFC 2812).
 */
class Message {
public:
    // Orthodox Canonical Form (C++98)
    Message();
    Message(const Message& other);
    Message& operator=(const Message& other);
    ~Message();

    // Parsing
    static Message parse(const std::string& rawMessage);
    
    // Building responses
    static std::string buildWelcome(const std::string& serverName, const std::string& nick);
    static std::string buildJoin(const std::string& prefix, const std::string& channel);
    static std::string buildPart(const std::string& prefix, const std::string& channel);
    static std::string buildPrivmsg(const std::string& prefix, const std::string& target, const std::string& text);
    static std::string buildNumericReply(const std::string& serverName, const std::string& code, 
                                         const std::string& target, const std::string& message);
    
    // Validation utilities
    static bool isValidNickname(const std::string& nick);
    static bool isValidChannelName(const std::string& channel);
    
    // Getters
    const std::string& getPrefix() const;
    const std::string& getCommand() const;
    const std::vector<std::string>& getParams() const;

private:
    std::string              _prefix;   // Optional prefix (e.g., "nick!user@host")
    std::string              _command;  // IRC command (e.g., "PRIVMSG", "JOIN")
    std::vector<std::string> _params;   // Command parameters
};

#endif // MESSAGE_HPP
