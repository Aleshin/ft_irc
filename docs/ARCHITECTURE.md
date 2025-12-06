# Архитектура FT_IRC

## 📐 Принципы проектирования

Проект построен на четких принципах:
1. **Минимализм** - только необходимые классы (4 класса)
2. **Каноническая форма C++98** - все классы следуют Orthodox Canonical Form
3. **Разделение ответственности** - каждый класс решает одну задачу
4. **Простота** - понятная структура без излишеств

## 🏗️ Структура классов

### 1. Server (главный класс)
**Файлы**: `include/Server.hpp`, `src/Server.cpp`

**Ответственность**: Управление сервером и координация всех компонентов
- Сетевой слой (socket, poll, accept)
- Управление клиентами и каналами
- Диспетчеризация IRC команд

**Ключевые методы**:
- `run()` - главный event loop
- `initSocket()` - инициализация сокета
- `acceptClient()` - принятие новых клиентов
- `handlePass/Nick/User/Join/Part/Privmsg/Kick/Invite/Topic/Mode()` - обработчики команд

**Поля**:
```cpp
int _port;                          // Порт сервера
std::string _password;              // Пароль подключения
int _serverFd;                      // Серверный сокет
std::vector<pollfd> _pollfds;       // Дескрипторы для poll()
std::map<int, Client*> _clients;    // Клиенты (ключ = fd)
std::map<std::string, Channel*> _channels;  // Каналы (ключ = имя)
```

### 2. Client (класс клиента)
**Файлы**: `include/Client.hpp`, `src/Client.cpp`

**Ответственность**: Хранение состояния клиентского соединения
- Данные подключения (fd, буферы ввода/вывода)
- Регистрационные данные (nickname, username)
- Статус регистрации

**Ключевые методы**:
- `getFd/getNickname/getUsername()` - геттеры
- `setNickname/setUsername/setPassword()` - сеттеры
- `appendToInput/appendToOutput()` - работа с буферами
- `extractLine()` - извлечение полной строки из буфера

**Поля**:
```cpp
int _fd;                    // File descriptor соединения
std::string _inputBuffer;   // Буфер входящих данных
std::string _outputBuffer;  // Буфер исходящих данных
std::string _nickname;      // Никнейм
std::string _username;      // Имя пользователя
bool _hasPassword;          // Пароль введен
bool _hasNickname;          // Никнейм установлен
bool _hasUsername;          // Username установлен
bool _registered;           // Регистрация завершена
```

### 3. Channel (класс канала)
**Файлы**: `include/Channel.hpp`, `src/Channel.cpp`

**Ответственность**: Управление состоянием IRC канала
- Участники и операторы
- Топик канала
- Режимы канала (+i, +t, +k, +o, +l)

**Ключевые методы**:
- `getName/getTopic/getMembers/getOperators()` - геттеры
- `setTopic/setInviteOnly/setKey/setUserLimit()` - управление параметрами
- `addMember/removeMember/hasMember()` - управление участниками
- `addOperator/removeOperator/isOperator()` - управление операторами

**Поля**:
```cpp
std::string _name;              // Имя канала (например, "#general")
std::string _topic;             // Топик канала
std::set<std::string> _members; // Участники (nicknames)
std::set<std::string> _operators;  // Операторы канала
bool _inviteOnly;               // Режим +i (invite-only)
bool _topicRestricted;          // Режим +t (только операторы меняют топик)
std::string _key;               // Режим +k (пароль канала)
int _userLimit;                 // Режим +l (лимит пользователей)
```

### 4. Message (вспомогательный класс)
**Файлы**: `include/Message.hpp`, `src/Message.cpp`

**Ответственность**: IRC протокол
- Парсинг IRC сообщений (формат: `[:prefix] COMMAND [params] [:trailing]`)
- Построение ответов сервера
- Валидация (nickname, channel names)
- IRC numeric codes (001, 401, и т.д.)

**Ключевые методы**:
- `parse()` - парсинг входящего сообщения
- `buildWelcome/buildJoin/buildPart/buildPrivmsg()` - построение ответов
- `buildNumericReply()` - построение числовых ответов
- `isValidNickname/isValidChannelName()` - валидация

**Поля**:
```cpp
std::string _prefix;                // Опциональный prefix
std::string _command;               // Команда IRC
std::vector<std::string> _params;   // Параметры команды
```

## 🔄 Поток данных

```
┌─────────────────────────────────────────────────────┐
│                    IRC Client                       │
└──────────────────┬──────────────────────────────────┘
                   │ TCP/IP
                   ▼
┌─────────────────────────────────────────────────────┐
│                   Server::run()                     │
│  ┌────────────────────────────────────────┐        │
│  │  poll() - ожидание событий             │        │
│  └─────────────┬──────────────────────────┘        │
│                │                                     │
│                ├─► POLLIN на serverFd                │
│                │   └─► acceptClient()                │
│                │                                     │
│                ├─► POLLIN на client fd               │
│                │   └─► readFromClient()              │
│                │       └─► Client::appendToInput()   │
│                │           └─► Client::extractLine() │
│                │               └─► processCommand()  │
│                │                   └─► Message::parse()│
│                │                       └─► handleXXX()│
│                │                           └─► Channel│
│                │                                     │
│                └─► POLLOUT на client fd              │
│                    └─► writeToClient()               │
│                        └─► Client::getOutputBuffer() │
└─────────────────────────────────────────────────────┘
```

## 📋 Требования из subject

### Обязательные команды:
- ✅ **PASS** - аутентификация паролем
- ✅ **NICK** - установка никнейма
- ✅ **USER** - установка username
- ✅ **JOIN** - присоединение к каналу
- ✅ **PART** - выход из канала
- ✅ **PRIVMSG** - отправка сообщения
- ✅ **KICK** - исключение пользователя (operator)
- ✅ **INVITE** - приглашение в канал (operator)
- ✅ **TOPIC** - изменение топика (operator)
- ✅ **MODE** - изменение режимов канала (operator)
  - `+i/-i` - Invite-only
  - `+t/-t` - Topic restricted
  - `+k/-k` - Channel key (password)
  - `+o/-o` - Give/take operator privilege
  - `+l/-l` - User limit

### Технические требования:
- ✅ C++98 стандарт
- ✅ Каноническая форма классов
- ✅ poll() для всех I/O операций
- ✅ Неблокирующий I/O
- ✅ Без fork()
- ✅ Множественные клиенты

## 🎓 Что должны реализовать студенты

### 1. Сетевой слой (Server)
- `initSocket()` - создание и bind сокета
- `acceptClient()` - принятие соединений
- `readFromClient()` - чтение данных
- `writeToClient()` - отправка данных
- `removeClient()` - удаление клиента

### 2. IRC протокол (Message)
- `parse()` - парсинг IRC сообщений
- `buildXXX()` - построение ответов
- `isValidXXX()` - валидация

### 3. Команды (Server)
- `handlePass()` - проверка пароля
- `handleNick()` - установка nickname
- `handleUser()` - установка username
- `handleJoin()` - присоединение к каналу
- `handlePart()` - выход из канала
- `handlePrivmsg()` - отправка сообщения
- `handleKick()` - исключение пользователя
- `handleInvite()` - приглашение в канал
- `handleTopic()` - изменение топика
- `handleMode()` - изменение режимов

### 4. Вспомогательные функции
- `tryRegisterClient()` - завершение регистрации
- `broadcastToChannel()` - рассылка по каналу
- `getChannel()` / `getClientByNick()` - поиск

## 📊 Итоговая статистика

```
Структура:
├── include/ (4 файла)
│   ├── Server.hpp      (главный класс)
│   ├── Client.hpp      (клиент)
│   ├── Channel.hpp     (канал)
│   └── Message.hpp     (IRC протокол)
│
└── src/ (5 файлов)
    ├── main.cpp        (точка входа)
    ├── Server.cpp      (реализация сервера)
    ├── Client.cpp      (реализация клиента)
    ├── Channel.cpp     (реализация канала)
    └── Message.cpp     (реализация протокола)

Итого: 4 класса, 9 файлов, чистая архитектура
```

## ✨ Преимущества архитектуры

1. **Минимализм** - только необходимое
2. **Ясность** - сразу видно, за что отвечает каждый класс
3. **Расширяемость** - легко добавлять новые команды
4. **Тестируемость** - каждый класс можно тестировать отдельно
5. **Каноничность** - все классы следуют C++98 Orthodox Canonical Form

