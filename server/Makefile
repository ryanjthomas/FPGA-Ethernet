.DEFAULT_GOAL := cfitsio
CC=g++                                                                                                               
#LD=G++                                                                                                               
CFLAGS=-t -g -O0 -std=c++0x -D_FILE_OFFSET_BITS=64 -fmax-errors=5 -Wall -pthread
OBJDIR=./obj
SRCDIR=./src
MAINDIR=./main
INCDIR=./include
INCLUDE=-Iinclude -I$(INCDIR)
SRC=$(wildcard $(SRCDIR)/*.cpp)
OBJS=$(SRC:.cpp=.o)
OBJS:= $(subst $(SRCDIR),$(OBJDIR),$(OBJS))

MAIN=write_config read_data write_data send_command write_firmware take_image

all: depend $(MAIN)

debug: CFLAGS += -DDEBUG
debug: clean all

cfitsio: CFLAGS += -DCFITSIO_INSTALLED -lcfitsio
cfitsio: all

nocfitsio: all

$(MAIN): $(OBJS)  depend
	$(CXX) $(INCLUDE) $(CFLAGS) -c $(MAINDIR)/$@.cpp -o $(OBJDIR)/$@.o
	$(CXX)  $(OBJS) $(INCLUDE) $(CFLAGS) $(LIBS) $(LIBFLAGS) $(OBJDIR)/$@.o -o $@.exe

$(OBJDIR)/%.o: $(SRCDIR)/%.cpp | obj
	$(CXX) $(INCLUDE) $(CFLAGS) -c $< -o $@

clean:
	rm -f $(OBJS) $(MAIN)
	rm -f $(OBJDIR)/*.o

depend: .depend

.depend: $(SRC)
	rm -f ./.depend
	$(CC) $(CFLAGS) $(INCLUDE) -MM $^ > ./.depend;

include .depend

obj:
	mkdir -p $@

# DO NOT DELETE 
