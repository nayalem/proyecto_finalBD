--skiplist--1.0.sql se ejecuta con create extension
\echo Use "CREATE EXTENSION skiplist" para cargar este archivo. \quit

--registrar handler de postgres.cpp
CREATE FUNCTION skiplist_handler(internal)
RETURNS index_am_handler
AS 'MODULE_PATHNAME'
LANGUAGE C;

--crear metodo de acceso
CREATE ACCESS METHOD skiplist TYPE INDEX HANDLER skiplist_handler;
COMMENT ON ACCESS METHOD skiplist IS 'indice Skip List (proyecto BD II)';

--operadores para enteros, 1 a 5 = < <= = >= >
CREATE OPERATOR CLASS int4_skiplist_ops
DEFAULT FOR TYPE int4 USING skiplist AS
    OPERATOR 1 <,
    OPERATOR 2 <=,
    OPERATOR 3 =,
    OPERATOR 4 >=,
    OPERATOR 5 >,
    FUNCTION 1 btint4cmp(int4, int4);

