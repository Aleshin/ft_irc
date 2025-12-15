NAME      := ircserv
CXX       := c++
CXXFLAGS  := -Wall -Wextra -Werror -std=c++98 -I include

# Clean 4-class architecture: Server, Client, Channel, Message
# Server implementation split into logical modules in src/server/
SRCS      := src/main.cpp \
             src/server/Core.cpp \
             src/server/Network.cpp \
             src/server/IO.cpp \
             src/server/Dispatch.cpp \
             src/server/CmdRegistration.cpp \
             src/server/CmdChannel.cpp \
             src/server/CmdOperator.cpp \
             src/server/CmdMode.cpp \
             src/server/Helpers.cpp \
             src/Client.cpp \
             src/Channel.cpp \
             src/Message.cpp

OBJS      := $(SRCS:.cpp=.o)

all: $(NAME)

$(NAME): $(OBJS)
	$(CXX) $(CXXFLAGS) $(OBJS) -o $(NAME)

%.o: %.cpp
	$(CXX) $(CXXFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS)

fclean: clean
	rm -f $(NAME)

re: fclean all

.PHONY: all clean fclean re
