matching: main.c imageUtil.c
#	gcc -w -o matching main.c imageUtil.c -lm
#	gcc -w -O2 -o matching main.c imageUtil.c -lm
#	gcc -w -O2 -fopenmp -o matching main.c imageUtil.c -lm
	gcc -w -O2 -Xpreprocessor -fopenmp -o matching main.c imageUtil.c -lm -I/opt/homebrew/opt/libomp/include -L/opt/homebrew/opt/libomp/lib -lomp
#	gcc -w -O3 -fopenmp -o matching main.c imageUtil.c -lm
#	gcc -w -O3 -fopenmp -o matching main.c imageUtil.c -lm -mtune=native

clean:
	$(RM) matching
