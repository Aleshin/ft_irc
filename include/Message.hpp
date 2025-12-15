#ifndef MESSAGE_HPP
#define MESSAGE_HPP

#include <string>
#include <vector>
#include <sstream>

// ============================================================================
// IRC Numeric Reply Codes (RFC 2812)
// 
// Servers use 3-digit numeric codes for responses:
//   001-004: Welcome sequence after successful registration
//   3xx: Channel information (topic, names, modes)
//   4xx: Errors (no such nick, not on channel, etc.)
// ============================================================================

// Welcome sequence (sent after successful PASS + NICK + USER)
#define RPL_WELCOME          1    // :server 001 nick :Welcome to IRC...
#define RPL_YOURHOST         2    // :server 002 nick :Your host is...
#define RPL_CREATED          3    // :server 003 nick :Server created...
#define RPL_MYINFO           4    // :server 004 nick servername version modes

// Channel information
#define RPL_NOTOPIC          331  // No topic set on channel
#define RPL_TOPIC            332  // Channel topic text
#define RPL_INVITING         341  // Confirms INVITE was sent
#define RPL_NAMREPLY         353  // List of users in channel (@ = operator)
#define RPL_ENDOFNAMES       366  // End of NAMES list
#define RPL_CHANNELMODEIS    324  // Current channel modes

// Error responses
#define ERR_NOSUCHNICK       401  // Target nickname not found
#define ERR_NOSUCHCHANNEL    403  // Target channel not found
#define ERR_CANNOTSENDTOCHAN 404  // Not allowed to send to channel
#define ERR_UNKNOWNCOMMAND   421  // Command not recognized
#define ERR_NONICKNAMEGIVEN  431  // NICK command without nickname
#define ERR_ERRONEUSNICKNAME 432  // Invalid nickname characters
#define ERR_NICKNAMEINUSE    433  // Nickname already taken
#define ERR_USERNOTINCHANNEL 441  // Target user not in channel (KICK)
#define ERR_NOTONCHANNEL     442  // You're not in that channel
#define ERR_USERONCHANNEL    443  // User already in channel (INVITE)
#define ERR_NOTREGISTERED    451  // Must register before this command
#define ERR_NEEDMOREPARAMS   461  // Not enough parameters
#define ERR_ALREADYREGISTRED 462  // Can't re-register
#define ERR_PASSWDMISMATCH   464  // Wrong server password
#define ERR_CHANNELISFULL    471  // Channel +l limit reached
#define ERR_INVITEONLYCHAN   473  // Channel +i, you're not invited
#define ERR_BADCHANNELKEY    475  // Wrong channel +k password
#define ERR_CHANOPRIVSNEEDED 482  // You're not operator

/**
 * @class Message
 * @brief IRC message parser, builder, and serializer
 *
 * IRC message format (RFC 2812):
 *   [:prefix] COMMAND [param1 param2 ...] [:trailing text]\r\n
 * 
 * Examples:
 *   NICK alice                        - Set nickname
 *   :alice!user@host PRIVMSG #chat :Hello everyone
 *   :server 001 alice :Welcome!       - Numeric reply
 * 
 * Usage:
 *   Parsing:  Message msg = Message::parse(line);
 *   Building: Message::reply(RPL_WELCOME, nick, "Welcome!").serialize();
 *   Fluent:   Message().prefix(p).command(c).param(p).serialize();
 */
class Message {
public:
    // ========================================================================
    // ORTHODOX CANONICAL FORM
    // ========================================================================
    Message();
    Message(const Message& other);
    Message& operator=(const Message& other);
    ~Message();

    // ========================================================================
    // PARSING - Named Constructor
    // ========================================================================
    /**
     * Parse raw IRC line into Message object
     * @param line Raw message without CRLF
     * @return Parsed Message (check isValid())
     */
    static Message parse(const std::string& line);

    // ========================================================================
    // FLUENT BUILDER - Method chaining for custom messages
    // ========================================================================
    Message& prefix(const std::string& p);
    Message& command(const std::string& c);
    Message& param(const std::string& p);
    Message& trailing(const std::string& t);

    // ========================================================================
    // SERIALIZATION - Convert to wire format
    // ========================================================================
    /**
     * Serialize message to IRC protocol format
     * @return Formatted string with CRLF terminator
     */
    std::string serialize() const;

    // ========================================================================
    // FACTORY METHODS - Create common IRC responses
    // ========================================================================
    
    /** 
     * Create numeric reply: :server CODE target [:message] 
     */
    static Message reply(int code, const std::string& target,
                         const std::string& message = "");

    /** 
     * Create numeric reply with params: :server CODE target params [:message] 
     */
    static Message replyParam(int code, const std::string& target,
                              const std::string& param,
                              const std::string& message = "");

    /** 
     * Create user-originated message: :nick!user@host CMD target [:text] 
     */
    static Message fromUser(const std::string& userPrefix,
                            const std::string& cmd,
                            const std::string& target,
                            const std::string& text = "");

    /** 
     * Create user-originated message with 2 params: :nick!user@host CMD param1 param2
     * No trailing (colon prefix), for INVITE etc.
     */
    static Message fromUser2Params(const std::string& userPrefix,
                                   const std::string& cmd,
                                   const std::string& param1,
                                   const std::string& param2);

    // ========================================================================
    // VALIDATORS - Static validation utilities
    // ========================================================================
    static bool isValidNick(const std::string& nick);
    static bool isValidChannel(const std::string& channel);
    static bool isValidUser(const std::string& user);

    // ========================================================================
    // GETTERS
    // ========================================================================
    bool isValid() const;
    const std::string& getPrefix() const;
    const std::string& getCommand() const;
    const std::vector<std::string>& getParams() const;
    const std::string& getTrailing() const;
    size_t getParamCount() const;

    // ========================================================================
    // SERVER CONFIGURATION
    // ========================================================================
    static void setServerName(const std::string& name);
    static const std::string& getServerName();

private:
    // Message data
    std::string _prefix;
    std::string _command;
    std::vector<std::string> _params;
    std::string _trailing;
    bool _valid;

    // Server name for outgoing messages
    static std::string _serverName;

    // Private helpers
    static std::string trim(const std::string& str);
    static std::string formatCode(int code);
};

#endif // MESSAGE_HPP
