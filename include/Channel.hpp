#ifndef CHANNEL_HPP
#define CHANNEL_HPP

#include <string>
#include <set>

/**
 * @class Channel
 * @brief Represents an IRC channel
 * 
 * Manages channel state including members, operators, topic, and modes.
 * Supports IRC channel modes: +i (invite-only), +t (topic restricted),
 * +k (key/password), +o (operator), +l (user limit).
 */
class Channel {
public:
    // Orthodox Canonical Form (C++98)
    Channel();
    explicit Channel(const std::string& name);
    Channel(const Channel& other);
    Channel& operator=(const Channel& other);
    ~Channel();

    // Getters
    const std::string& getName() const;
    const std::string& getTopic() const;
    const std::set<std::string>& getMembers() const;
    const std::set<std::string>& getOperators() const;
    bool isInviteOnly() const;
    bool isTopicRestricted() const;
    const std::string& getKey() const;
    int getUserLimit() const;

    // Setters
    void setTopic(const std::string& topic);
    void setInviteOnly(bool inviteOnly);
    void setTopicRestricted(bool restricted);
    void setKey(const std::string& key);
    void setUserLimit(int limit);

    // Member management
    void addMember(const std::string& nickname);
    void removeMember(const std::string& nickname);
    bool hasMember(const std::string& nickname) const;

    // Operator management
    void addOperator(const std::string& nickname);
    void removeOperator(const std::string& nickname);
    bool isOperator(const std::string& nickname) const;

    // Invite list management (for +i channels)
    void addInvited(const std::string& nickname);
    void removeInvited(const std::string& nickname);
    bool isInvited(const std::string& nickname) const;

private:
    std::string            _name;
    std::string            _topic;
    std::set<std::string>  _members;
    std::set<std::string>  _operators;
    std::set<std::string>  _invited;
    bool                   _inviteOnly;
    bool                   _topicRestricted;
    std::string            _key;
    int                    _userLimit;
};

#endif // CHANNEL_HPP
