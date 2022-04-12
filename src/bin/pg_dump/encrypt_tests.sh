#!/bin/sh
INSTDIR=/home/postgres/build
export LD_LIBRARY_PATH=$INSTDIR/lib:$LD_LIBRARY_PATH
export PATH=$INSTDIR/bin:$PATH

DATADIR=/home/postgres/pgdata_folder

rm -rf $DATADIR/*S

pkill -9 -e postgres

initdb -D $DATADIR

pg_ctl -D $DATADIR -l logfile start

psql postgres -c "CREATE TABLE t2 (
				a	integer,
				b	integer,
				c	integer
)"

psql postgres -c "CREATE TABLE t3 (
				a	integer,
				b	integer,
				c	integer,
				id	integer
)"

psql postgres -c "CREATE TABLE t4 (
				id	integer
)"

psql postgres -c "CREATE TABLE t12 (
				id	integer,
				fio	varchar(40),
				salary	integer,
				adress	varchar(100)
)"


pg_dump -t t2 --encrypt-columns "a,b,c" --encrypt "func_name" #хранимая функция везде учитывать передаваемые параметры + перегрузки функции
pg_dump -t t3 --encrypt-columns "a,b" --encrypt "CREATE FUNCTION lorem ipsum" #фунцкия объявляется тут
pg_dump -t t4 --encrypt-columns "id"
pg_dump -t t12 --encrypt "star.sql" #--encrypt по отдельности шифрует ВСЕ столбцы, а --encrypt_columns - предупреждение - отдельно от encrypt ничего не делает

