# Интерфейсы для Параллельной Разработки

> Описание всех классов и методов для независимой работы над модулями

## 📋 Обзор

Проект состоит из **4 основных классов** с четким разделением ответственности. Каждый класс можно разрабатывать независимо, следуя предоставленным интерфейсам.

## 🏗️ Архитектура классов

```
┌─────────────────────────────────────────────────────────┐
│                       Server                            │
│  - Сетевой уровень (socket, poll, accept)             │
│  - Event loop                                          │
│  - Диспетчеризация команд                              │
│  - Управление Client и Channel                         │
└──────────────┬──────────────────────┬───────────────────┘
               │                      │
       ┌───────▼──────┐      ┌────────▼──────┐
       │    Client    │      │    Channel    │
       │  - fd        │      │  - members    │
       │  - buffers   │      │  - operators  │
       │  - nickname  │      │  - modes      │
       │  - username  │      │  - topic      │
       └──────────────┘      └───────────────┘
               │
               │ использует
               │
       ┌───────▼──────────────────┐
       │       Message            │
       │  - parse()               │
       │  - build*()              │
       │  - IRC numeric codes     │
       └──────────────────────────┘
```

## 📦 1. Класс Client

**Файлы:** `include/Client.hpp`, `src/Client.cpp`  
**Статус:** ✅ **ПОЛНОСТЬЮ РЕАЛИЗОВАН**

### Назначение
Хранение состояния IRC клиента: соединение, регистрационные данные, буферы I/O.

### Интерфейс

#### Конструкторы (Orthodox Canonical Form)
```cpp
Client();                          // Конструктор по умолчанию
explicit Client(int fd);           // Конструктор с file descriptor
Client(const Client& other);       // Конструктор копирования
Client& operator=(const Client&);  // Оператор присваивания
~Client();                         // Деструктор
```

#### Геттеры
```cpp
int getFd() const;                      // Получить file descriptor
const std::string& getNickname() const; // Получить nickname
const std::string& getUsername() const; // Получить username
const std::string& getInputBuffer() const;  // Буфер входящих данных
const std::string& getOutputBuffer() const; // Буфер исходящих данных
bool isRegistered() const;              // Завершена ли регистрация
bool hasPassword() const;               // Введен ли пароль (PASS)
bool hasNickname() const;               // Установлен ли nickname (NICK)
bool hasUsername() const;               // Установлен ли username (USER)
```

#### Сеттеры
```cpp
void setNickname(const std::string& nick);  // Установить nickname
void setUsername(const std::string& user);  // Установить username
void setPassword(bool hasPass);             // Отметить ввод пароля
void setRegistered(bool registered);        // Отметить регистрацию
```

#### Работа с буферами
```cpp
void appendToInput(const std::string& data);  // Добавить в буфер ввода
void appendToOutput(const std::string& data); // Добавить в буфер вывода
void clearInputBuffer();                      // Очистить буфер ввода
void clearOutputBuffer();                     // Очистить буфер вывода
std::string extractLine();                    // Извлечь полную строку (до \r\n)
```

### Пример использования
```cpp
// Создание клиента при accept()
int clientFd = accept(serverFd, NULL, NULL);
Client* client = new Client(clientFd);

// Чтение данных
char buffer[512];
int n = recv(clientFd, buffer, 512, 0);
client->appendToInput(std::string(buffer, n));

// Извлечение команд
while (true) {
    std::string line = client->extractLine();
    if (line.empty()) break;
    processCommand(*client, line);  // Обработка команды
}

// Регистрация клиента
if (client->hasPassword() && client->hasNickname() && client->hasUsername()) {
    client->setRegistered(true);
    // Отправить приветствие
}
```

### Состояние регистрации
Клиент должен пройти 3 этапа для полной регистрации:

```
┌──────────┐     ┌──────────┐     ┌──────────┐     ┌─────────────┐
│   PASS   │ ──► │   NICK   │ ──► │   USER   │ ──► │ REGISTERED  │
└──────────┘     └──────────┘     └──────────┘     └─────────────┘
hasPassword=true hasNickname=true hasUsername=true  isRegistered=true
```

---

## 📦 2. Класс Channel

**Файлы:** `include/Channel.hpp`, `src/Channel.cpp`  
**Статус:** ✅ **ПОЛНОСТЬЮ РЕАЛИЗОВАН**

### Назначение
Управление состоянием IRC канала: участники, операторы, топик, режимы.

### Интерфейс

#### Конструкторы (Orthodox Canonical Form)
```cpp
Channel();                           // Конструктор по умолчанию
explicit Channel(const std::string& name);  // Конструктор с именем
Channel(const Channel& other);       // Конструктор копирования
Channel& operator=(const Channel&);  // Оператор присваивания
~Channel();                          // Деструктор
```

#### Геттеры
```cpp
const std::string& getName() const;              // Имя канала (например, "#general")
const std::string& getTopic() const;             // Топик канала
const std::set<std::string>& getMembers() const; // Все участники
const std::set<std::string>& getOperators() const; // Операторы
bool isInviteOnly() const;                       // Режим +i
bool isTopicRestricted() const;                  // Режим +t
const std::string& getKey() const;               // Ключ (пароль) +k
int getUserLimit() const;                        // Лимит пользователей +l
```

#### Сеттеры
```cpp
void setTopic(const std::string& topic);     // Установить топик
void setInviteOnly(bool inviteOnly);         // Режим +i (invite-only)
void setTopicRestricted(bool restricted);    // Режим +t (только op меняет топик)
void setKey(const std::string& key);         // Режим +k (пароль)
void setUserLimit(int limit);                // Режим +l (лимит пользователей)
```

#### Управление участниками
```cpp
void addMember(const std::string& nickname);      // Добавить участника
void removeMember(const std::string& nickname);   // Удалить участника
bool hasMember(const std::string& nickname) const; // Проверить участника
```

#### Управление операторами
```cpp
void addOperator(const std::string& nickname);      // Сделать оператором
void removeOperator(const std::string& nickname);   // Снять права оператора
bool isOperator(const std::string& nickname) const; // Проверить права
```

### Пример использования
```cpp
// Создание канала
Channel* channel = new Channel("#general");

// Первый участник становится оператором
channel->addMember("alice");
channel->addOperator("alice");

// Установка параметров
channel->setTopic("Welcome to #general!");
channel->setInviteOnly(true);    // +i
channel->setTopicRestricted(true); // +t
channel->setKey("secret123");     // +k secret123

// Добавление участников
channel->addMember("bob");

// Проверки
if (channel->isOperator("alice")) {
    // alice может менять топик
    channel->setTopic("New topic");
}

if (channel->hasMember("bob")) {
    // bob в канале
}
```

### Режимы канала (Channel Modes)

| Режим | Описание | Параметр |
|-------|----------|----------|
| `+i` | Invite-only - только по приглашению | нет |
| `+t` | Topic restricted - топик меняют только операторы | нет |
| `+k` | Key - пароль для входа | `<key>` |
| `+o` | Operator - права оператора | `<nickname>` |
| `+l` | Limit - лимит пользователей | `<number>` |

**Примеры команд:**
```irc
MODE #general +i          // Включить invite-only
MODE #general +k secret   // Установить пароль
MODE #general +o bob      // Дать bob права оператора
MODE #general +l 10       // Лимит 10 пользователей
MODE #general -i          // Выключить invite-only
```

---

## 📦 3. Класс Message

**Файлы:** `include/Message.hpp`, `src/Message.cpp`  
**Статус:** ⚠️ **ИНТЕРФЕЙС ГОТОВ, РЕАЛИЗАЦИЯ ДЛЯ СТУДЕНТОВ**

### Назначение
Парсинг и построение IRC сообщений, валидация, IRC numeric codes.

### Формат IRC сообщений
```
[:prefix] COMMAND [param1] [param2] ... [:trailing parameter]\r\n
```

**Примеры:**
```irc
NICK john
USER john 0 * :John Doe
JOIN #general
PRIVMSG #general :Hello everyone!
:alice!alice@host PRIVMSG #general :Hi there!
```

### Интерфейс

#### Конструкторы (Orthodox Canonical Form)
```cpp
Message();                         // Конструктор по умолчанию
Message(const Message& other);     // Конструктор копирования
Message& operator=(const Message&); // Оператор присваивания
~Message();                        // Деструктор
```

#### Геттеры
```cpp
const std::string& getPrefix() const;   // Prefix (например, "nick!user@host")
const std::string& getCommand() const;  // Команда (NICK, JOIN, и т.д.)
const std::vector<std::string>& getParams() const; // Параметры
```

#### Статические методы парсинга (TODO: Реализовать)
```cpp
static Message parse(const std::string& raw);  // Парсинг IRC сообщения
```

**Алгоритм парсинга:**
1. Если строка начинается с `:`, извлечь prefix до первого пробела
2. Извлечь command (следующее слово)
3. Извлечь параметры:
   - Если параметр начинается с `:`, остаток строки = один параметр (trailing)
   - Иначе параметры разделены пробелами

**Пример реализации:**
```cpp
Message Message::parse(const std::string& raw) {
    Message msg;
    std::string line = raw;
    
    // 1. Prefix
    if (!line.empty() && line[0] == ':') {
        size_t space = line.find(' ');
        msg._prefix = line.substr(1, space - 1);
        line = line.substr(space + 1);
    }
    
    // 2. Command
    size_t space = line.find(' ');
    if (space == std::string::npos) {
        msg._command = line;
        return msg;
    }
    msg._command = line.substr(0, space);
    line = line.substr(space + 1);
    
    // 3. Parameters
    while (!line.empty()) {
        if (line[0] == ':') {
            msg._params.push_back(line.substr(1));
            break;
        }
        size_t space = line.find(' ');
        if (space == std::string::npos) {
            msg._params.push_back(line);
            break;
        }
        msg._params.push_back(line.substr(0, space));
        line = line.substr(space + 1);
    }
    
    return msg;
}
```

#### Статические методы построения ответов (TODO: Реализовать)
```cpp
static std::string buildWelcome(const std::string& nick);
static std::string buildJoin(const std::string& nick, const std::string& channel);
static std::string buildPart(const std::string& nick, const std::string& channel);
static std::string buildPrivmsg(const std::string& from, const std::string& to, 
                                const std::string& text);
static std::string buildNumericReply(int code, const std::string& target, 
                                     const std::string& message);
```

**Примеры:**
```cpp
// Приветствие
Message::buildWelcome("john");
// :server 001 john :Welcome to the IRC Network

// JOIN уведомление
Message::buildJoin("john", "#general");
// :john JOIN #general

// PRIVMSG
Message::buildPrivmsg("alice", "#general", "Hello!");
// :alice PRIVMSG #general :Hello!

// Numeric reply
Message::buildNumericReply(332, "john", "#general :Channel topic");
// :server 332 john #general :Channel topic
```

#### Валидация (TODO: Реализовать)
```cpp
static bool isValidNickname(const std::string& nick);
static bool isValidChannelName(const std::string& channel);
```

**Правила валидации:**
- **Nickname:** 
  - Длина 1-9 символов
  - Начинается с буквы
  - Содержит буквы, цифры, `-`, `_`, `[`, `]`, `{`, `}`, `\`, `|`
  - Не может начинаться с цифры или `-`

- **Channel name:**
  - Начинается с `#` или `&`
  - Длина 1-50 символов (без `#`)
  - Не содержит пробелов, запятых, `\x07` (bell)

### IRC Numeric Reply Codes
```cpp
// Success
#define RPL_WELCOME          001  // "Welcome to the IRC Network"
#define RPL_TOPIC            332  // "<channel> :<topic>"
#define RPL_NAMREPLY         353  // "<channel> :<nicknames>"

// Errors
#define ERR_NOSUCHNICK       401  // "<nickname> :No such nick/channel"
#define ERR_NOSUCHCHANNEL    403  // "<channel> :No such channel"
#define ERR_CANNOTSENDTOCHAN 404  // "<channel> :Cannot send to channel"
#define ERR_UNKNOWNCOMMAND   421  // "<command> :Unknown command"
#define ERR_NONICKNAMEGIVEN  431  // ":No nickname given"
#define ERR_ERRONEUSNICKNAME 432  // "<nick> :Erroneous nickname"
#define ERR_NICKNAMEINUSE    433  // "<nick> :Nickname is already in use"
#define ERR_NOTONCHANNEL     442  // "<channel> :You're not on that channel"
#define ERR_NOTREGISTERED    451  // ":You have not registered"
#define ERR_NEEDMOREPARAMS   461  // "<command> :Not enough parameters"
#define ERR_ALREADYREGISTRED 462  // ":You may not reregister"
#define ERR_PASSWDMISMATCH   464  // ":Password incorrect"
#define ERR_CHANNELISFULL    471  // "<channel> :Cannot join channel (+l)"
#define ERR_INVITEONLYCHAN   473  // "<channel> :Cannot join channel (+i)"
#define ERR_BADCHANNELKEY    475  // "<channel> :Cannot join channel (+k)"
#define ERR_CHANOPRIVSNEEDED 482  // "<channel> :You're not channel operator"
```

---

## 📦 4. Класс Server

**Файлы:** `include/Server.hpp`, `src/Server.cpp`  
**Статус:** ⚠️ **ИНТЕРФЕЙС ГОТОВ, РЕАЛИЗАЦИЯ ДЛЯ СТУДЕНТОВ**

### Назначение
Главный класс: сетевой уровень, event loop, диспетчеризация команд, управление клиентами и каналами.

### Интерфейс
```cpp
// src/CommandParser.cpp - студент реализует
IRCMessage CommandParser::parse(const std::string& rawMessage) {
    IRCMessage msg;
    // TODO: парсинг prefix, command, params
    return msg;
}
```

### 2. MessageBuilder (обязательный)
**Файл:** `include/MessageBuilder.hpp`  
**Методы:** 
- `buildWelcome()` - построение welcome сообщения
- `buildJoin()` - построение JOIN сообщения
- `buildPrivmsg()` - построение PRIVMSG
- `buildError()` - построение сообщения об ошибке

**Задача:** Генерация правильно отформатированных IRC ответов

**Пример разработки:**
```cpp
// src/MessageBuilder.cpp - студент реализует
std::string MessageBuilder::buildWelcome(const std::string& serverName, 
                                          const std::string& nick) {
    // TODO: создать строку формата ":server 001 nick :Welcome..."
    return "";
}
```

### 3. Utils (обязательный)
**Файл:** `include/Utils.hpp`  
**Методы:**
- `split()` - разделение строки
- `trim()` - удаление пробелов
- `toUpper()` - верхний регистр
- `isValidNickname()` - валидация nickname
- `isValidChannelName()` - валидация имени канала

**Задача:** Вспомогательные функции общего назначения

### 4. Numerics.hpp (справочный)
**Файл:** `include/Numerics.hpp`  
**Содержит:** Определения констант IRC numeric codes  
**Использование:** 
```cpp
#include "Numerics.hpp"
// Используем константы вместо magic numbers
std::string error = buildError(server, nick, ERR_NOSUCHNICK, "No such nick");
```

### 5. IRCCommand (опциональный, для масштабирования)
**Файл:** `include/IRCCommand.hpp`  
**Паттерн:** Command Pattern - абстрактный базовый класс  
**Метод:** `virtual void execute(Server&, Client&, const IRCMessage&) = 0`

**Назначение:** Инкапсуляция логики каждой IRC команды в отдельный класс

**Пример использования:**
```cpp
// Создаём класс для команды JOIN
class JoinCommand : public IRCCommand {
public:
    void execute(Server& server, Client& client, const IRCMessage& msg) {
        // Логика команды JOIN
        std::string channel = msg.params[0];
        // ... добавление в канал, отправка ответов ...
    }
};

// В коде сервера
IRCCommand* joinCmd = new JoinCommand();
joinCmd->execute(server, client, parsedMessage);
```

**Преимущества:**
- Каждая команда = отдельный класс (Single Responsibility)
- Легко добавлять новые команды без изменения Server
- Удобно для тестирования команд по отдельности

**Альтернатива:** Простой if-else в `Server::processLine()`

### 6. CommandDispatcher (опциональный, для масштабирования)
**Файл:** `include/CommandDispatcher.hpp`  
**Паттерн:** Registry/Dispatcher для централизованной маршрутизации  
**Методы:**
- `registerCommand(name, IRCCommand*)` - регистрация обработчика
- `dispatch(Server&, Client&, IRCMessage&)` - вызов нужного обработчика

**Назначение:** Избежать длинного if-else/switch, централизовать диспетчеризацию

**Пример использования:**
```cpp
// Инициализация диспетчера
CommandDispatcher dispatcher;
dispatcher.registerCommand("JOIN", new JoinCommand());
dispatcher.registerCommand("PART", new PartCommand());
dispatcher.registerCommand("KICK", new KickCommand());

// В Server::processLine()
IRCMessage msg = CommandParser::parse(line);
if (!dispatcher.dispatch(*this, client, msg)) {
    // Команда не найдена - отправить ERR_UNKNOWNCOMMAND
}
```

**Преимущества:**
- Нет длинного if-else/switch
- Легко добавлять/удалять команды
- Четкая регистрация всех доступных команд

**Альтернатива:** Использовать `std::map<std::string, function_pointer>` или простой if-else

## 📝 Принципы Независимой Разработки

### Разделение Задач

#### Разработчик 1: Парсинг и Валидация
- Реализовать `CommandParser::parse()`
- Реализовать функции валидации в `Utils`
- Написать тесты для парсинга

#### Разработчик 2: Построение Сообщений
- Реализовать методы `MessageBuilder`
- Добавить новые методы по мере необходимости
- Написать тесты для форматирования

#### Разработчик 3: Команды Пользователей (простой подход)
- Добавить обработку команд в `ServerCommands.cpp`
- JOIN, PART, PRIVMSG, NOTICE
- Использовать if-else или парсер (если готов)

#### Разработчик 4: Команды Каналов (простой подход)
- TOPIC, NAMES, KICK, INVITE, MODE
- Работать с `_channels` в Server
- Использовать Channel структуру

#### Разработчик 5: Command Pattern (опциональный, для масштабирования)
- Создать классы-наследники IRCCommand для каждой команды
- Инкапсулировать логику команд
- Интегрировать с CommandDispatcher

#### Разработчик 6: CommandDispatcher (опциональный, для масштабирования)
- Реализовать registerCommand() и dispatch()
- Создать централизованный реестр команд
- Заменить if-else в processLine() на диспетчер

## 🔄 Как Добавить Новую Команду

1. **Использовать парсер** (если готов):
```cpp
void Server::processLine(Client &client, const std::string &line) {
    IRCMessage msg = CommandParser::parse(line);
    if (msg.command == "MYCOMMAND") {
        // обработка команды
    }
}
```

2. **Построить ответ** (если MessageBuilder готов):
```cpp
std::string response = MessageBuilder::buildWelcome(_serverName, client.nickname);
sendToClient(client, response);
```

3. **Работать с каналами**:
```cpp
if (_channels.find("#test") == _channels.end()) {
    _channels["#test"] = new Channel("#test");
}
_channels["#test"]->members.insert(client.nickname);
```

## ✅ Что Гарантируется

- Проект компилируется с пустыми интерфейсами
- Все заголовочные файлы имеют защиту от повторного включения
- Структуры данных (Client, Channel) готовы к использованию
- Сервер запускается и принимает соединения
- Базовая регистрация (PASS/NICK/USER) работает

## ⚠️ Что НЕ Реализовано (Задачи для Студентов)

- Парсинг IRC сообщений (CommandParser)
- Построение IRC ответов (MessageBuilder)
- Вспомогательные функции (Utils)
- Обработка команд каналов (JOIN, PART и т.д.)
- Отправка сообщений (PRIVMSG, NOTICE)
- Управление операторами и режимами
- Команды KICK, INVITE, TOPIC, MODE

## 📊 Текущее Состояние

```
✅ Готово:
- Сетевой слой (poll, accept, read, write)
- Базовые структуры (Client, Channel)
- Простейшая регистрация (PASS/NICK/USER)
- Интерфейсы для расширения

⏳ К Реализации:
- Парсинг IRC протокола
- Построение IRC сообщений
- Вспомогательные функции
- Все команды IRC (кроме PASS/NICK/USER)
```

## 🎯 Начало Работы

1. Выберите задачу (парсинг, построение сообщений, команды)
2. Реализуйте соответствующий интерфейс
3. Тестируйте независимо
4. Интегрируйте через общие интерфейсы

**Пример теста:**
```bash
# Запустить сервер
./ircserv 6667 password

# Подключиться
nc localhost 6667
PASS password
NICK testuser
USER testuser 0 * :Test User
# После регистрации увидите welcome message
```
