ifeq ($(OS), Windows_NT)
	RM=del
else
	RM=rm
endif

PROJECT_NAME=doubledabble
SRC = src
OBJECTS = $(PROJECT_NAME).o
ROM = $(PROJECT_NAME).nes

all: $(ROM)

clean:
	$(RM) $(PROJECT_NAME).o
	$(RM) $(PROJECT_NAME).nes

$(ROM): $(OBJECTS)
	cl65 --target nes -o $(ROM) $(OBJECTS)

%.o: $(SRC)/%.s
	ca65 -o $@ -t nes $<