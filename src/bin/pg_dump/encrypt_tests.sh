#!/bin/sh
INSTDIR=/home/postgres/build
export LD_LIBRARY_PATH=$INSTDIR/lib:$LD_LIBRARY_PATH
export PATH=$INSTDIR/bin:$PATH

DATADIR=/home/postgres/pgdata_folder

rm -rf $DATADIR/*S

pkill -9 -e postgres

initdb -D $DATADIR

pg_ctl -D $DATADIR -l logfile start

psql postgres -c "DROP TABLE t2"
psql postgres -c "DROP TABLE t3"
psql postgres -c "DROP TABLE t4"
psql postgres -c "DROP TABLE t12"

psql postgres -c "CREATE TABLE t2 (
				a	text,
				b	text,
				c	text,
				id 	integer
)"

psql postgres -c "INSERT INTO t2 VALUES
('test_a_1', 'test_b_1', 'test_c_1', 1),
('test_a_2', 'test_b_2', 'test_c_2', 2),
('test_a_3', 'test_b_3', 'test_c_3', 3);
"

psql postgres -c "CREATE TABLE t3 (
				a	varchar(40),
				b	varchar(40),
				c	varchar(40),
				id	varchar(40)
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
#psql postgres -c "DROP FUNCTION func_name"

#psql postgres -c "CREATE OR REPLACE FUNCTION func_name (IN elem TEXT, OUT res TEXT) RETURNS TEXT AS $BODY$
#			BEGIN  				
#				res := '*****';
#				RETURN;
#			END
#			$BODY$ LANGUAGE plpgsql;
#"


pg_dump -t t2 --encrypt-columns "a,b,c" --encrypt "func_name" #хранимая функция везде учитывать передаваемые параметры + перегрузки функции
#pg_dump -t t3 --encrypt-columns "a,b" --encrypt "CREATE FUNCTION lorem ipsum" #фунцкия объявляется тут
#pg_dump -t t4 --encrypt-columns "id" --encrypt "jumble" #пока что тоже хранимая функция
#pg_dump -t t12 --encrypt "star.sql" #--encrypt по отдельности шифрует ВСЕ столбцы, а --encrypt_columns - предупреждение - отдельно от encrypt ничего не делает

