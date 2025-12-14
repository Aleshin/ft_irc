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
| **Тесты: 102/102** | ✅ |

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
# Быстрый тест (13 проверок)
IRC_PORT=6667 IRC_PASS=mypassword ./tests/quick_test.sh

# Полный тест (59 проверок)
IRC_PORT=6667 IRC_PASS=mypassword ./tests/full_test.sh

# PING/PONG и стресс-тесты (20 проверок)
IRC_PORT=6667 IRC_PASS=mypassword ./tests/extra_test.sh

# Тест обработки сигналов (10 проверок)
./tests/signal_test.sh
```

### Результаты тестирования

| Тест | ft_irc | ngircd |
|------|--------|--------|
| quick_test.sh | ✅ 13/13 | ✅ 13/13 |
| full_test.sh | ✅ 59/59 | ✅ 59/59 |
| extra_test.sh | ✅ 20/20 | ✅ 20/20 |
| signal_test.sh | ✅ 10/10 | N/A |
| **ИТОГО** | **102/102** | **92/92** |

---

## 📁 Структура проекта

```
ft_irc/
├── Makefile              # Сборка: all, clean, fclean, re
├── ircserv               # Исполняемый файл
│
├── include/
│   ├── Server.hpp        # Главный класс сервера
│   ├── Client.hpp        # Клиентское соединение
│   ├── Channel.hpp       # IRC канал
│   └── Message.hpp       # IRC сообщение и парсинг
│
├── src/
│   ├── main.cpp          # Точка входа + сигналы
│   ├── Server.cpp        # Сетевой стек + команды
│   ├── Client.cpp        # Буферы I/O
│   ├── Channel.cpp       # Управление каналом
│   └── Message.cpp       # Парсинг/сериализация
│
├── tests/
│   ├── quick_test.sh     # Быстрая проверка
│   ├── full_test.sh      # Полное тестирование
│   ├── extra_test.sh     # PING/PONG тесты
│   └── signal_test.sh    # Тест сигналов
│
└── docs/
    ├── DEVELOPMENT_PLAN.md
    ├── ft_irc_extended_subject.md
    └── evaluation.md
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

## 📊 Метрики кода

| Файл | Строки |
|------|--------|
| Server.cpp | 1187 |
| Message.cpp | 305 |
| Client.cpp | 108 |
| Channel.cpp | 107 |
| main.cpp | 47 |
| **Итого src/** | **1754** |
| Server.hpp | 82 |
| Message.hpp | 159 |
| Channel.hpp | 68 |
| Client.hpp | 65 |
| **Итого include/** | **374** |
| **ВСЕГО** | **2128** |

---

## 📚 Документация

- [DEVELOPMENT_PLAN.md](docs/DEVELOPMENT_PLAN.md) - План разработки
- [ft_irc_extended_subject.md](docs/ft_irc_extended_subject.md) - Требования
- [evaluation.md](docs/evaluation.md) - Критерии оценки

---

## 🎯 Готовность к сдаче: 100%

Проект полностью соответствует требованиям Subject 42 School и готов к защите.
