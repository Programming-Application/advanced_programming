CC ?= gcc
LIBOMP_PREFIX := $(shell brew --prefix libomp 2>/dev/null)

ifneq ($(LIBOMP_PREFIX),)
OMP_FLAGS := -Xpreprocessor -fopenmp -I$(LIBOMP_PREFIX)/include -L$(LIBOMP_PREFIX)/lib -lomp
else ifeq ($(shell printf 'int main(){return 0;}' | $(CC) -fopenmp -x c - -o /dev/null 2>/dev/null && echo ok),ok)
OMP_FLAGS := -fopenmp
else
OMP_FLAGS :=
endif

matching: main.c imageUtil.c
	$(CC) -w -O2 $(OMP_FLAGS) -o matching main.c imageUtil.c -lm

clean:
	$(RM) matching
