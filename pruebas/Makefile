# Pruebas de la Skip List en memoria (no necesitan PostgreSQL).
#   make -C pruebas            compila y ejecuta las pruebas automáticas
#   make -C pruebas programa   compila el programa con menú (./pruebas/programa)

CXX      ?= g++
CXXFLAGS ?= -std=c++17 -O2 -Wall

test: test_skiplist
	./test_skiplist

test_skiplist: test_skiplist.cpp ../src/skip_list.h
	$(CXX) $(CXXFLAGS) -I../src -o $@ test_skiplist.cpp

programa: ../src/main.cpp ../src/skip_list.h
	$(CXX) $(CXXFLAGS) -I../src -o $@ ../src/main.cpp

clean:
	rm -f test_skiplist programa

.PHONY: test clean
