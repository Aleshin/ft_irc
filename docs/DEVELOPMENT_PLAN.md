# План Разработки FT_IRC

> Последнее обновление: 14 декабря 2025

## 📊 Текущее Состояние: 80% → Фаза 4 Завершена ✅

---

## ✅ ЗАВЕРШЁННЫЕ ФАЗЫ

### 🏆 Фаза 4: Каналы и Сообщения (14 декабря 2025)
- ✅ handleJoin() - создание/присоединение к каналу с проверками +i/+k/+l
- ✅ handlePart() - выход из канала с удалением пустых каналов
- ✅ handlePrivmsg() - сообщения в каналы и личные сообщения
- ✅ broadcastToChannel() - рассылка всем участникам
- ✅ Первый пользователь становится оператором (@)
- ✅ NAMES list (353 + 366)
- ✅ **17/17 тестов проходят**

**Тег:** `v0.4.0`

### 🏆 Фаза 3: Регистрация Клиентов (13 декабря 2025)
- ✅ handlePass() - проверка пароля сервера
- ✅ handleNick() - полная логика с nick collision
- ✅ handleUser() - полная логика регистрации
- ✅ tryRegisterClient() - завершение регистрации
- ✅ sendToClient() - реальная отправка ответов
- ✅ Welcome sequence (001-004)
- ✅ **14/14 тестов проходят**

**Тег:** `v0.3.0`  
**Документация:** [PHASE3_COMPLETED.md](PHASE3_COMPLETED.md)

### 🏆 Фаза 2: IRC Парсинг (13 декабря 2025)
- ✅ Message::parse() - полный парсинг IRC команд по RFC 2812
- ✅ Message::serialize() - сериализация в wire format
- ✅ Message::reply/replyParam/fromUser - фабричные методы
- ✅ Numeric codes (28 констант)

**Тег:** `v0.2.0`  
**Документация:** [PHASE2_COMPLETED.md](PHASE2_COMPLETED.md)

### 🏆 Фаза 1: Сетевая Инфраструктура (13 декабря 2025)
- ✅ Архитектура классов (Server, Client, Channel, Message)
- ✅ Полный сетевой стек с poll() - неблокирующий I/O
- ✅ **7/7 тестов проходят**

**Тег:** `v0.1.0`  
**Документация:** [PHASE1_COMPLETED.md](PHASE1_COMPLETED.md)

---

## 🔄 ФАЗА 5: Операторские Команды (СЛЕДУЮЩАЯ)

**Статус:** 🔄 Готова к началу  
**Ветка:** `phase5`  
**Зависимости:** Фаза 4 ✅

### Задачи:
- [ ] handleKick() - исключение пользователя из канала
- [ ] handleInvite() - приглашение в канал (для +i)
- [ ] handleTopic() - установка/просмотр темы канала
- [ ] handleMode() - режимы канала:
  - [ ] +i/-i - Invite-only
  - [ ] +t/-t - Topic restricted (только операторы)
  - [ ] +k/-k - Channel key (пароль)
  - [ ] +o/-o - Give/take operator privilege
  - [ ] +l/-l - User limit

### Numeric Codes для Фазы 5:
```
RPL_INVITING         341   // :server 341 inviter nick #channel
RPL_TOPIC            332   // :server 332 nick #channel :Topic text
RPL_NOTOPIC          331   // :server 331 nick #channel :No topic is set
RPL_CHANNELMODEIS    324   // :server 324 nick #channel +modes

ERR_USERNOTINCHANNEL 441   // :server 441 nick user #channel :They aren't on that channel
ERR_CHANOPRIVSNEEDED 482   // :server 482 nick #channel :You're not channel operator
ERR_USERONCHANNEL    443   // :server 443 nick user #channel :is already on channel
ERR_UNKNOWNMODE      472   // :server 472 char :is unknown mode char to me
```

### Критерии завершения:
- [ ] Оператор может кикать пользователей
- [ ] Оператор может приглашать в +i каналы
- [ ] Оператор может менять топик в +t каналах
- [ ] Все режимы работают корректно
- [ ] Все тесты phase5 проходят

---

## 📁 Архитектура Проекта

```
ft_irc/
├── include/ (Server.hpp, Client.hpp, Channel.hpp, Message.hpp)
├── src/ (main.cpp, Server.cpp, Client.cpp, Channel.cpp, Message.cpp)
├── tests/ (check_system.sh, phase1-4_tests.sh)
└── docs/ (DEVELOPMENT_PLAN.md, PHASE1-3_COMPLETED.md)
```

**Всего:** 4 класса, ~2000+ строк кода, 31 тест

---

## 📅 Прогресс

| Фаза | Статус | Тег | Тесты |
|------|--------|-----|-------|
| Фаза 1: Сеть | ✅ | v0.1.0 | 7/7 |
| Фаза 2: Парсинг | ✅ | v0.2.0 | - |
| Фаза 3: Регистрация | ✅ | v0.3.0 | 14/14 |
| Фаза 4: Каналы | ✅ | v0.4.0 | 17/17 |
| Фаза 5: Операторы | �� | - | 0/? |

---

**Версия документа:** 2.0
