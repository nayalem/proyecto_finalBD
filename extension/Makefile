# Compila la extensión con la herramienta de PostgreSQL (PGXS).
#   make            compila los .cpp  ->  skiplist.so
#   make install    copia la extensión a PostgreSQL

MODULE_big = skiplist
OBJS = paginas.o operaciones.o postgres.o

EXTENSION = skiplist
DATA = skiplist--1.0.sql

# C++ sin excepciones (PostgreSQL maneja los errores a su manera)
PG_CXXFLAGS = -std=c++20 -fno-exceptions
SHLIB_LINK += -lstdc++

PG_CONFIG ?= pg_config
PGXS := $(shell $(PG_CONFIG) --pgxs)
include $(PGXS)

# No generamos código para el JIT (así no hace falta clang)
override with_llvm = no

$(OBJS): skiplist.h
