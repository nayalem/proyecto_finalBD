#compilar extension con pgxs
#make: crear skiplist.so
#make install: instalar en postgresql

MODULE_big = skiplist
OBJS = paginas.o operaciones.o postgres.o

EXTENSION = skiplist
DATA = skiplist--1.0.sql

#c++ sin excepciones
PG_CXXFLAGS = -std=c++20 -fno-exceptions
SHLIB_LINK += -lstdc++

PG_CONFIG ?= pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

#sin jit, sin clang
override with_llvm = no

$(OBJS): skiplist.h
