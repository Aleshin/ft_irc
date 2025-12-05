# ft_irc - Минимальный IRC Сервер для Параллельной Разработки

Учебный проект IRC сервера с минимальной инфраструктурой и четкими интерфейсами для параллельной разработки.

## 🎯 Цель Проекта

Создать IRC сервер на C++98 с возможностью параллельной разработки несколькими студентами без конфликтов кода.

## ✅ Что Уже Реализовано

- ✅ **Сетевой слой** - работа с сокетами, poll(), неблокирующий I/O
- ✅ **Базовая структура** - Client, Channel, Server
- ✅ **Простейшая регистрация** - PASS, NICK, USER команды
- ✅ **Интерфейсы** - четкие границы между компонентами

## 📋 Интерфейсы для Реализации

### 1. CommandParser (include/CommandParser.hpp)
Парсинг IRC сообщений в структуру IRCMessage
```cpp
IRCMessage parse(const std::string& rawMessage);
```

### 2. MessageBuilder (include/MessageBuilder.hpp)
Построение IRC ответов сервера
```cpp
std::string buildWelcome(const std::string& server, const std::string& nick);
std::string buildJoin(const std::string& prefix, const std::string& channel);
std::string buildPrivmsg(const std::string& prefix, const std::string& target, const std::string& msg);
std::string buildError(const std::string& server, const std::string& nick, const std::string& code, const std::string& msg);
```

### 3. Utils (include/Utils.hpp)
Вспомогательные функции
```cpp
std::vector<std::string> split(const std::string& str, char delimiter);
std::string trim(const std::string& str);
std::string toUpper(const std::string& str);
bool isValidNickname(const std::string& nick);
bool isValidChannelName(const std::string& channel);
```

### 4. IRC Команды (src/ServerCommands.cpp)
Обработчики команд - добавляются в `processLine()`
- JOIN, PART, KICK
- PRIVMSG, NOTICE
- TOPIC, NAMES, MODE
- INVITE, и т.д.

## 🔧 Структура Данных

### IRCMessage (include/Types.hpp)
```cpp
struct IRCMessage {
    std::string prefix;                  // Опциональный prefix
    std::string command;                 // Команда IRC
    std::vector<std::string> params;     // Параметры команды
};
```

### Channel (include/Channel.hpp)
```cpp
struct Channel {
    std::string name;
    std::string topic;
    std::set<std::string> members;
    std::set<std::string> operators;
    bool inviteOnly;
    bool topicRestricted;
    std::string key;
    int userLimit;
};
```

### Client (include/Client.hpp)
```cpp
struct Client {
    int fd;
    std::string input, output;
    std::string nickname, username;
    bool hasPass, hasNick, hasUser;
    bool registered;
};
```

## 🚀 Быстрый Старт

### Компиляция
```bash
make
```

### Запуск
```bash
./ircserv <port> <password>
./ircserv 6667 mypassword
```

### Подключение для Тестирования
```bash
nc localhost 6667
PASS mypassword
NICK testuser
USER testuser 0 * :Test User
```

После регистрации вы увидите welcome сообщение.

## 📚 Документация

**Главный документ:** [docs/INTERFACES.md](docs/INTERFACES.md) - полное описание интерфейсов и принципов разработки

### Что Там Найдете:
- Описание всех интерфейсов
- Примеры независимой разработки
- Как добавить новую команду
- Разделение задач между разработчиками

## 🔄 Разработка

### Принцип Независимых Модулей

Каждый студент может работать над своей частью:

**Разработчик 1:** Парсинг
- Реализует `CommandParser::parse()`
- Пишет тесты парсинга

**Разработчик 2:** Построение Сообщений
- Реализует методы `MessageBuilder`
- Пишет тесты форматирования

**Разработчик 3:** Команды Пользователей
- JOIN, PART, PRIVMSG, NOTICE

**Разработчик 4:** Управление Каналами
- TOPIC, NAMES, KICK, MODE, INVITE

### Добавление Новой Команды

Пример добавления команды JOIN в `src/ServerCommands.cpp`:

```cpp
void Server::processLine(Client &client, const std::string &line) {
    // ... существующий код PASS, NICK, USER ...
    
    // JOIN
    if (line.compare(0, 5, "JOIN ") == 0) {
        std::string channelName = line.substr(5);
        // TODO: валидация имени канала
        // TODO: создание канала если не существует
        // TODO: добавление клиента в канал
        // TODO: отправка подтверждения
        return;
    }
}
```

## 📊 Текущее Состояние

```
Готово к Использованию:
├── Сетевой уровень       [████████████████████] 100%
├── Структуры данных      [████████████████████] 100%
├── Базовая регистрация   [████████████████████] 100%
└── Интерфейсы            [████████████████████] 100%

Требуется Реализация:
├── CommandParser         [░░░░░░░░░░░░░░░░░░░░]   0%
├── MessageBuilder        [░░░░░░░░░░░░░░░░░░░░]   0%
├── Utils                 [░░░░░░░░░░░░░░░░░░░░]   0%
└── IRC Команды (10+)     [░░░░░░░░░░░░░░░░░░░░]   0%
```

## 🧪 Тестирование

### Базовый Тест
```bash
# Terminal 1
./ircserv 6667 password

# Terminal 2
echo -e "PASS password\nNICK user1\nUSER user1 0 * :User One" | nc localhost 6667
```

Ожидаемый результат: welcome сообщение от сервера

### Тест Множественных Клиентов
```bash
# Terminal 1
./ircserv 6667 password

# Terminal 2
nc localhost 6667
PASS password
NICK user1
USER user1 0 * :User One

# Terminal 3
nc localhost 6667
PASS password
NICK user2
USER user2 0 * :User Two
```

## 📖 Полезные Ссылки

- **RFC 1459** - Original IRC Protocol Specification
- **RFC 2812** - Internet Relay Chat: Client Protocol
- **include/Numerics.hpp** - IRC Numeric Reply Codes

## ⚙️ Требования

- C++98 совместимый компилятор
- POSIX система (Linux, macOS)
- Базовое понимание сокетов и IRC протокола

## 🎓 Учебная Ценность

Проект учит:
- Работе с сетевыми сокетами (poll, non-blocking I/O)
- Проектированию с четкими интерфейсами
- Параллельной разработке без конфликтов
- IRC протоколу (RFC 2812)
- Управлению состоянием в реальном времени

## ✨ Особенности

- **Минимальная инфраструктура** - фокус на бизнес-логике
- **Четкие интерфейсы** - легко разделить работу
- **Компилируется сразу** - можно тестировать по частям
- **Независимые модули** - нет конфликтов при слиянии кода

---

**Начните с чтения [INTERFACES.md](INTERFACES.md) для понимания архитектуры!**
