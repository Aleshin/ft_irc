# FT_IRC - IRC Server Implementation

> 42 School Project: Implementing an IRC (Internet Relay Chat) server in C++98

## 📊 Статус: 100% ЗАВЕРШЕНО ✅

| Компонент | Статус |
|-----------|--------|
| Makefile | ✅ |
| Сетевой стек | ✅ |
| IRC протокол | ✅ |
| Операторские команды | ✅ |
| Режимы каналов | ✅ |
| PING/PONG | ✅ |
| Сигналы | ✅ |
| **Тесты: 92/92** | ✅ |

---

## 🚀 Быстрый старт

```bash
# Сборка
make

# Запуск сервера
./ircserv 6667 mypassword

# Подключение через nc
nc localhost 6667
PASS mypassword
NICK mynick
USER myuser 0 * :My Real Name

# Подключение через irssi
irssi -c localhost -p 6667 -w mypassword
```

---

## 📋 Реализованные команды

### Регистрация
| Команда | Описание |
|---------|----------|
| `PASS` | Установка пароля сервера |
| `NICK` | Установка/смена никнейма |
| `USER` | Регистрация пользователя |
| `QUIT` | Отключение от сервера |

### Каналы
| Команда | Описание |
|---------|----------|
| `JOIN` | Присоединение к каналу |
| `PART` | Выход из канала |
| `TOPIC` | Просмотр/установка темы |

### Сообщения
| Команда | Описание |
|---------|----------|
| `PRIVMSG` | Личные сообщения и в канал |

### Операторские
| Команда | Описание |
|---------|----------|
| `KICK` | Исключение из канала |
| `INVITE` | Приглашение в канал |
| `MODE` | Установка режимов |

### Режимы каналов
| Режим | Описание |
|-------|----------|
| `+i` | Invite-only (только по приглашению) |
| `+t` | Topic restricted (топик только для операторов) |
| `+k` | Channel key (пароль на канал) |
| `+o` | Operator privilege (права оператора) |
| `+l` | User limit (лимит пользователей) |

### Дополнительно
| Команда | Описание |
|---------|----------|
| `PING` | Keep-alive запрос |
| `PONG` | Keep-alive ответ |

---

## 🧪 Тестирование

```bash
# Запустить все тесты (92 проверки)
./tests/comprehensive_test.sh
```

---

## 📁 Структура проекта

```
ft_irc/
├── Makefile                    # Сборка: all, clean, fclean, re
├── ircserv                     # Исполняемый файл
│
├── include/                    # Заголовочные файлы (4 класса)
│   ├── Server.hpp              # Главный класс сервера
│   ├── Client.hpp              # Клиентское соединение
│   ├── Channel.hpp             # IRC канал
│   └── Message.hpp             # IRC сообщение + парсинг + коды ответов
│
├── src/                        # Исходные файлы
│   ├── main.cpp                # Точка входа + обработка сигналов
│   ├── Client.cpp              # Реализация Client
│   ├── Channel.cpp             # Реализация Channel
│   ├── Message.cpp             # Парсинг/сериализация IRC
│   │
│   └── server/                 # Реализация Server (разбит на модули)
│       ├── Core.cpp            # Конструкторы, деструктор, run()
│       ├── Network.cpp         # Socket, poll, accept
│       ├── IO.cpp              # Чтение/запись клиентов
│       ├── Dispatch.cpp        # Маршрутизация команд
│       ├── CmdRegistration.cpp # PASS, NICK, USER
│       ├── CmdChannel.cpp      # JOIN, PART, TOPIC, PRIVMSG
│       ├── CmdOperator.cpp     # KICK, INVITE
│       ├── CmdMode.cpp         # MODE i/t/k/o/l
│       └── Helpers.cpp         # Вспомогательные функции
│
├── tests/
│   └── comprehensive_test.sh   # 92 теста
│
└── docs/
    ├── ARCHITECTURE.md         # Архитектура проекта
    └── evaluation.md           # Критерии оценки
```

---

## 🏗️ Архитектура

### 4 класса (чистый ООП):

```
┌─────────────────────────────────────────────────────────────┐
│                          Server                             │
│  - Управляет сетью (socket, poll, accept)                  │
│  - Хранит клиентов и каналы                                │
│  - Обрабатывает IRC команды                                │
└─────────────────────────────────────────────────────────────┘
         │ contains                         │ contains
         ▼                                  ▼
┌─────────────────────┐          ┌─────────────────────┐
│       Client        │          │       Channel       │
│  - File descriptor  │          │  - Имя канала       │
│  - Буферы I/O       │          │  - Участники        │
│  - Ник, юзернейм    │          │  - Операторы        │
│  - Статус регистр.  │          │  - Режимы (+i,+t..) │
└─────────────────────┘          └─────────────────────┘

┌─────────────────────────────────────────────────────────────┐
│                        Message                              │
│  - Парсинг IRC сообщений                                   │
│  - Построение ответов сервера                              │
│  - Валидация (ник, канал)                                  │
│  - IRC numeric codes (001, 401, 433, ...)                  │
└─────────────────────────────────────────────────────────────┘
```

### Поток данных:

```
IRC клиент  →  socket  →  poll(POLLIN)  →  recv()
                                              ↓
                                   Client.inputBuffer
                                              ↓
                                     extractLine()
                                              ↓
                                   Message::parse()
                                              ↓
                               processCommand() → handleXXX()
                                              ↓
                                   Client.outputBuffer
                                              ↓
poll(POLLOUT)  →  send()  →  IRC клиент
```

---

## ⚙️ Технические детали

### Соответствие Subject

- ✅ **Makefile**: `$(NAME)`, `all`, `clean`, `fclean`, `re`
- ✅ **Флаги**: `c++ -Wall -Wextra -Werror -std=c++98`
- ✅ **Имя**: `ircserv`
- ✅ **Запуск**: `./ircserv <port> <password>`

### C++98

- ✅ STL: `std::map`, `std::vector`, `std::set`, `std::string`
- ✅ Без внешних библиотек
- ✅ Без Boost

### Сетевой стек

- ✅ Единственный `poll()` для всего I/O
- ✅ `O_NONBLOCK` на всех сокетах
- ✅ `SO_REUSEADDR` для быстрого перезапуска
- ✅ Без `fork()`

### Сигналы

- ✅ SIGINT → graceful shutdown
- ✅ SIGTERM → graceful shutdown
- ✅ Корректное освобождение ресурсов

---

## � Документация

- [ARCHITECTURE.md](docs/ARCHITECTURE.md) - Подробная архитектура
- [evaluation.md](docs/evaluation.md) - Критерии оценки

---

## 🎯 Готовность к сдаче: 100%

Проект полностью соответствует требованиям Subject 42 School и готов к защите.
