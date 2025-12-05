#ifndef NUMERICS_HPP
#define NUMERICS_HPP

// IRC Numeric Reply Codes (RFC 2812)
// Используйте эти константы для отправки правильных ответов клиентам

// === Success Replies (001-399) ===

// Connection Registration
#define RPL_WELCOME          "001"  // "Welcome to the Internet Relay Network <nick>!<user>@<host>"
#define RPL_YOURHOST         "002"  // "Your host is <servername>, running version <ver>"
#define RPL_CREATED          "003"  // "This server was created <date>"
#define RPL_MYINFO           "004"  // "<servername> <version> <available user modes> <available channel modes>"

// Channel Information
#define RPL_NOTOPIC          "331"  // "<channel> :No topic is set"
#define RPL_TOPIC            "332"  // "<channel> :<topic>"
#define RPL_NAMREPLY         "353"  // "= <channel> :<nick> [<nick>...]"
#define RPL_ENDOFNAMES       "366"  // "<channel> :End of /NAMES list"

// === Error Replies (400-599) ===

// Client/Server Errors
#define ERR_NOSUCHNICK       "401"  // "<nickname> :No such nick/channel"
#define ERR_NOSUCHCHANNEL    "403"  // "<channel name> :No such channel"
#define ERR_CANNOTSENDTOCHAN "404"  // "<channel name> :Cannot send to channel"
#define ERR_NORECIPIENT      "411"  // ":No recipient given (<command>)"
#define ERR_NOTEXTTOSEND     "412"  // ":No text to send"
#define ERR_UNKNOWNCOMMAND   "421"  // "<command> :Unknown command"

// Registration Errors
#define ERR_NONICKNAMEGIVEN  "431"  // ":No nickname given"
#define ERR_ERRONEUSNICKNAME "432"  // "<nick> :Erroneous nickname"
#define ERR_NICKNAMEINUSE    "433"  // "<nick> :Nickname is already in use"

// Channel Errors
#define ERR_NOTONCHANNEL     "442"  // "<channel> :You're not on that channel"
#define ERR_USERONCHANNEL    "443"  // "<user> <channel> :is already on channel"
#define ERR_NEEDMOREPARAMS   "461"  // "<command> :Not enough parameters"
#define ERR_ALREADYREGISTRED "462"  // ":You may not reregister"
#define ERR_PASSWDMISMATCH   "464"  // ":Password incorrect"
#define ERR_CHANNELISFULL    "471"  // "<channel> :Cannot join channel (+l)"
#define ERR_INVITEONLYCHAN   "473"  // "<channel> :Cannot join channel (+i)"
#define ERR_BADCHANNELKEY    "475"  // "<channel> :Cannot join channel (+k)"

// Privilege Errors
#define ERR_CHANOPRIVSNEEDED "482"  // "<channel> :You're not channel operator"

#endif // NUMERICS_HPP
