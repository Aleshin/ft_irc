1. Программа не должна крашиться, вылетать по нехватке памяти и пр. Нужно проверять все ответы на успех
2. Должен быть Makefile без ненужных релинков. В нем должны быть правила $(NAME), all, clean, fclean and re.
3. Компилировать над с флагами c++ -Wall -Wextra -Werror -std=c++98
4. Везде надо максимально использовать концепции и возможности С++
5. Внешние библиотеки и Boost libraries запрещены
6. Название программы должно быть ircserv
7. Файлы в проекте: Makefile, *.{h, hpp}, *.cpp, *.tpp, *.ipp,
an optional configuration file
8. Аргументы: port: The listening port, password: The connection password
9. Внешние функции:
Everything in C++ 98.
socket, close, setsockopt, getsockname,
getprotobyname, gethostbyname, getaddrinfo,
freeaddrinfo, bind, connect, listen, accept,
htons, htonl, ntohs, ntohl, inet_addr, inet_ntoa,
inet_ntop, send, recv, signal, sigaction,
sigemptyset, sigfillset, sigaddset, sigdelset,
sigismember, lseek, fstat, fcntl, poll (or
equivalent)
10. IRC-клиент не надо, межсерверное взаимодействие не надо
11. Вместо poll() можно использовать select(), kqueue(), or
epoll()
12. Сервер должен выдерживать много клиентов
13. Fork запрещен, операции ввода-вывода должны быть неблокирующими
14. Только один poll должен использоваться для read,
write, listen и пр. Работать надо только через него