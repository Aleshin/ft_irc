#include "Channel.hpp"

// Orthodox Canonical Form
Channel::Channel()
    : _name(),
      _topic(),
      _members(),
      _operators(),
      _inviteOnly(false),
      _topicRestricted(true),
      _key(),
      _userLimit(0) {}

Channel::Channel(const std::string& name)
    : _name(name),
      _topic(),
      _members(),
      _operators(),
      _inviteOnly(false),
      _topicRestricted(true),
      _key(),
      _userLimit(0) {}

Channel::Channel(const Channel& other)
    : _name(other._name),
      _topic(other._topic),
      _members(other._members),
      _operators(other._operators),
      _inviteOnly(other._inviteOnly),
      _topicRestricted(other._topicRestricted),
      _key(other._key),
      _userLimit(other._userLimit) {}

Channel& Channel::operator=(const Channel& other) {
    if (this != &other) {
        _name = other._name;
        _topic = other._topic;
        _members = other._members;
        _operators = other._operators;
        _inviteOnly = other._inviteOnly;
        _topicRestricted = other._topicRestricted;
        _key = other._key;
        _userLimit = other._userLimit;
    }
    return *this;
}

Channel::~Channel() {}

// Getters
const std::string& Channel::getName() const { return _name; }
const std::string& Channel::getTopic() const { return _topic; }
const std::set<std::string>& Channel::getMembers() const { return _members; }
const std::set<std::string>& Channel::getOperators() const { return _operators; }
bool Channel::isInviteOnly() const { return _inviteOnly; }
bool Channel::isTopicRestricted() const { return _topicRestricted; }
const std::string& Channel::getKey() const { return _key; }
int Channel::getUserLimit() const { return _userLimit; }

// Setters
void Channel::setTopic(const std::string& topic) { _topic = topic; }
void Channel::setInviteOnly(bool inviteOnly) { _inviteOnly = inviteOnly; }
void Channel::setTopicRestricted(bool restricted) { _topicRestricted = restricted; }
void Channel::setKey(const std::string& key) { _key = key; }
void Channel::setUserLimit(int limit) { _userLimit = limit; }

// Member management
void Channel::addMember(const std::string& nickname) {
    _members.insert(nickname);
}

void Channel::removeMember(const std::string& nickname) {
    _members.erase(nickname);
    _operators.erase(nickname);  // Remove from operators too
}

bool Channel::hasMember(const std::string& nickname) const {
    return _members.find(nickname) != _members.end();
}

// Operator management
void Channel::addOperator(const std::string& nickname) {
    _operators.insert(nickname);
}

void Channel::removeOperator(const std::string& nickname) {
    _operators.erase(nickname);
}

bool Channel::isOperator(const std::string& nickname) const {
    return _operators.find(nickname) != _operators.end();
}
