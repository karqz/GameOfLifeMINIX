.PHONY: clean

all: game_of_life_bl swapper_bl

game_of_life_bl: game_of_life_bl.s
	nasm -f bin game_of_life_bl.s -o game_of_life_bl

swapper_bl: swapper_bl.s 
	nasm -f bin swapper_bl.s -o swapper_bl

clean:
	rm game_of_life_bl swapper_bl