#pruebas en memoria, sin postgresql
#make -C pruebas: compilar y probar
#make -C pruebas programa: menu

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
