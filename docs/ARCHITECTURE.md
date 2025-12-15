# Архитектура FT_IRC

## 📐 Принципы проектирования

1. **Минимализм** - только 4 класса
2. **Каноническая форма C++98** - Orthodox Canonical Form
3. **Разделение ответственности** - каждый класс решает одну задачу
4. **Модульность** - Server разбит на логические файлы

---

## 🏗️ Структура классов

### 1. Server (главный класс)

**Файлы**: 
- `include/Server.hpp` - объявление класса
- `src/server/` - реализация (9 файлов)

**Ответственность**: Управление сервером и координация всех компонентов

**Структура реализации**:
```
src/server/
├── Core.cpp            # Конструкторы, деструктор, run() - главный цикл
├── Network.cpp         # initSocket(), acceptClient(), poll management
├── IO.cpp              # readFromClient(), writeToClient(), removeClient()
├── Dispatch.cpp        # processCommand() - маршрутизация команд
├── CmdRegistration.cpp # handlePass(), handleNick(), handleUser()
├── CmdChannel.cpp      # handleJoin(), handlePart(), handleTopic(), handlePrivmsg()
├── CmdOperator.cpp     # handleKick(), handleInvite()
├── CmdMode.cpp         # handleMode() - все режимы i/t/k/o/l
└── Helpers.cpp         # sendToClient(), broadcastToChannel(), require*()
```

**Поля**:
```cpp
int _port;                              // Порт сервера
std::string _password;                  // Пароль подключения
std::string _serverName;                // Имя сервера ("ircserv")
int _serverFd;                          // Серверный сокет
std::vector<pollfd> _pollfds;           // Дескрипторы для poll()
std::map<int, Client*> _clients;        // Клиенты (ключ = fd)
std::map<std::string, Channel*> _channels;  // Каналы (ключ = имя)
```

---

### 2. Client (класс клиента)

**Файлы**: `include/Client.hpp`, `src/Client.cpp`

**Ответственность**: Состояние клиентского соединения

**Поля**:
```cpp
int _fd;                    // File descriptor соединения
std::string _inputBuffer;   // Буфер входящих данных
std::string _outputBuffer;  // Буфер исходящих данных
std::string _nickname;      // Никнейм
std::string _username;      // Имя пользователя
std::string _realname;      // Реальное имя (из USER)
bool _hasPassword;          // Пароль введен
bool _registered;           // Регистрация завершена
bool _pendingDisconnect;    // Ожидает отключения
```

---

### 3. Channel (класс канала)

**Файлы**: `include/Channel.hpp`, `src/Channel.cpp`

**Ответственность**: Состояние IRC канала

**Поля**:
```cpp
std::string _name;              // Имя канала (#general)
std::string _topic;             // Топик канала
std::set<std::string> _members; // Участники (nicknames)
std::set<std::string> _operators;  // Операторы канала
std::set<std::string> _invited;    // Приглашенные (для +i)
bool _inviteOnly;               // Режим +i
bool _topicRestricted;          // Режим +t (по умолчанию true)
std::string _key;               // Режим +k (пароль)
int _userLimit;                 // Режим +l (лимит)
```

---

### 4. Message (вспомогательный класс)

**Файлы**: `include/Message.hpp`, `src/Message.cpp`

**Ответственность**: IRC протокол
- Парсинг входящих сообщений
- Построение исходящих ответов
- Валидация (nickname, channel names)
- IRC numeric codes

**Поля**:
```cpp
std::string _prefix;                // Опциональный prefix (:nick!user@host)
std::string _command;               // Команда IRC (NICK, JOIN, ...)
std::vector<std::string> _params;   // Параметры команды
std::string _trailing;              // Текст после : (может содержать пробелы)
bool _valid;                        // Результат парсинга
static std::string _serverName;     // Имя сервера для ответов
```

---

## 🔄 Поток данных

```
┌─────────────────────────────────────────────────────────────┐
│                       IRC Client                            │
└────────────────────────┬────────────────────────────────────┘
                         │ TCP/IP
                         ▼
┌─────────────────────────────────────────────────────────────┐
│                    Server::run()                            │
│                                                             │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  poll() - ожидание событий на всех fd               │   │
│  └────────────────────────┬────────────────────────────┘   │
│                           │                                 │
│                           ├─► POLLIN на serverFd            │
│                           │   └─► acceptClient()            │
│                           │                                 │
│                           ├─► POLLIN на client fd           │
│                           │   └─► recv() → inputBuffer      │
│                           │       └─► extractLine()         │
│                           │           └─► Message::parse()  │
│                           │               └─► handleXXX()   │
│                           │                   └─► Channel   │
│                           │                                 │
│                           └─► POLLOUT на client fd          │
│                               └─► send() ← outputBuffer     │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

---

## 📋 IRC команды

| Команда | Файл | Описание |
|---------|------|----------|
| PASS | CmdRegistration.cpp | Аутентификация паролем |
| NICK | CmdRegistration.cpp | Установка никнейма |
| USER | CmdRegistration.cpp | Регистрация пользователя |
| JOIN | CmdChannel.cpp | Вход в канал |
| PART | CmdChannel.cpp | Выход из канала |
| TOPIC | CmdChannel.cpp | Топик канала |
| PRIVMSG | CmdChannel.cpp | Отправка сообщения |
| KICK | CmdOperator.cpp | Исключение из канала |
| INVITE | CmdOperator.cpp | Приглашение в канал |
| MODE | CmdMode.cpp | Режимы канала |
| PING | Dispatch.cpp | Keep-alive |
| QUIT | Dispatch.cpp | Отключение |

---

## 📊 Итоговая структура

```
ft_irc/
├── include/              # 4 заголовочных файла
│   ├── Server.hpp
│   ├── Client.hpp
│   ├── Channel.hpp
│   └── Message.hpp
│
└── src/                  # 13 файлов реализации
    ├── main.cpp
    ├── Client.cpp
    ├── Channel.cpp
    ├── Message.cpp
    │
    └── server/           # Server разбит на 9 модулей
        ├── Core.cpp
        ├── Network.cpp
        ├── IO.cpp
        ├── Dispatch.cpp
        ├── CmdRegistration.cpp
        ├── CmdChannel.cpp
        ├── CmdOperator.cpp
        ├── CmdMode.cpp
        └── Helpers.cpp

Итого: 4 класса, 17 файлов, модульная архитектура
```

---

## ✨ Преимущества архитектуры

1. **Минимализм** - только 4 класса, каждый с ясной ответственностью
2. **Модульность** - Server разбит на логические файлы по ~100-200 строк
3. **Читаемость** - легко найти нужный код по имени файла
4. **Расширяемость** - новые команды добавляются в соответствующий Cmd*.cpp
5. **Каноничность** - все классы следуют C++98 Orthodox Canonical Form
