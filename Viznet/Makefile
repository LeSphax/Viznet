# Compiler
CC = g++

# Compiler flags
CFLAGS = -std=c++17 -I./metal-cpp/

# Linker flags 
LFLAGS = -framework Foundation -framework QuartzCore -framework Metal

# Source files
SRCS = $(wildcard *.cpp)

# Object files 
OBJS = $(SRCS:.cpp=.o)

# Output executable
OUT = main

all: $(OBJS)
		$(CC) $(CFLAGS) -o $(OUT) $(OBJS) $(LFLAGS)

.cpp.o:
		$(CC) $(CFLAGS) -c $<  -o $@

.PHONY: clean
clean:
		rm -f *.o $(OUT)
