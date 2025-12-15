#ifndef MESSAGE_HPP
#define MESSAGE_HPP

#include <string>
#include <vector>
#include <sstream>

// ============================================================================
// IRC Numeric Reply Codes (RFC 2812)
// ============================================================================

// Welcome (001-004)
#define RPL_WELCOME          1
#define RPL_YOURHOST         2
#define RPL_CREATED          3
#define RPL_MYINFO           4

// Channel (300s)
#define RPL_NOTOPIC          331
#define RPL_TOPIC            332
#define RPL_INVITING         341
#define RPL_NAMREPLY         353
#define RPL_ENDOFNAMES       366
#define RPL_CHANNELMODEIS    324

// Errors (400s)
#define ERR_NOSUCHNICK       401
#define ERR_NOSUCHCHANNEL    403
#define ERR_CANNOTSENDTOCHAN 404
#define ERR_UNKNOWNCOMMAND   421
#define ERR_NONICKNAMEGIVEN  431
#define ERR_ERRONEUSNICKNAME 432
#define ERR_NICKNAMEINUSE    433
#define ERR_USERNOTINCHANNEL 441
#define ERR_NOTONCHANNEL     442
#define ERR_USERONCHANNEL    443
#define ERR_NOTREGISTERED    451
#define ERR_NEEDMOREPARAMS   461
#define ERR_ALREADYREGISTRED 462
#define ERR_PASSWDMISMATCH   464
#define ERR_CHANNELISFULL    471
#define ERR_INVITEONLYCHAN   473
#define ERR_BADCHANNELKEY    475
#define ERR_CHANOPRIVSNEEDED 482

/**
 * @class Message
 * @brief Unified IRC message: parsing, building, and serialization
 *
 * This class handles ALL message operations in a clean OOP manner:
 * - Parsing incoming messages (static parse())
 * - Building outgoing messages (fluent builder + factory methods)
 * - Serialization to IRC protocol format
 * - Validation of IRC entities (nick, channel, user)
 *
 * IRC Format (RFC 2812): [:prefix] command [params] [:trailing] CRLF
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
