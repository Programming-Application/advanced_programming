UNAME_S := $(shell uname -s)

ifeq ($(UNAME_S),Darwin)
  # macOS: Apple Clang needs Xpreprocessor + Homebrew libomp
  OMP_CFLAGS  := -Xpreprocessor -fopenmp -I$(shell brew --prefix libomp)/include
  OMP_LDFLAGS := -L$(shell brew --prefix libomp)/lib -lomp
else
  # Linux / WSL: gcc supports -fopenmp natively
  OMP_CFLAGS  := -fopenmp
  OMP_LDFLAGS := -fopenmp
endif

matching: main.c imageUtil.c
	gcc -w -O2 $(OMP_CFLAGS) -o matching main.c imageUtil.c -lm $(OMP_LDFLAGS)
#	gcc -w -O1 $(OMP_CFLAGS) -o matching main.c imageUtil.c -lm $(OMP_LDFLAGS)
#	gcc -w -O3 $(OMP_CFLAGS) -o matching main.c imageUtil.c -lm $(OMP_LDFLAGS)
#	gcc -w -O3 $(OMP_CFLAGS) -o matching main.c imageUtil.c -lm $(OMP_LDFLAGS) -funroll-all-loops -funroll-loops -funsafe-loop-optimizations
#	gcc -w -O3 $(OMP_CFLAGS) -o matching main.c imageUtil.c -lm $(OMP_LDFLAGS) -mtune=native
#	gcc -w -Ofast $(OMP_CFLAGS) -o matching main.c imageUtil.c -lm $(OMP_LDFLAGS) -mtune=native -mfpmath=both
#	icc -w -fast -o matching main.c imageUtil.c -lm -mtune=native
#	icc -w -fast -o matching main.c imageUtil.c -lm

clean:
	$(RM) matching
