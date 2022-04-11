#!/bin/sh
INSTDIR=/home/postgres/build
export LD_LIBRARY_PATH=$INSTDIR/lib:$LD_LIBRARY_PATH
export PATH=$INSTDIR/bin:$PATH

DATADIR=/home/postgres/pgdata_folder

rm -rf $DATADIR/*

make -C ./home/postgres/desktop/postgresql/src/bin/pg_dump/clean
make -C ./home/postgres/desktop/postgresql/src/bin/pg_dump/install

pkill -9 -e postgres

initdb -D $DATADIR

pg_ctl -D $DATADIR -l logfile start

psql postgres -c "CREATE TABLE WITH ENCODING 'UTF8'"

pg_dump -t t2 --encrypt_columns "a,b,c" --encrypt "func_name" #хранимая функция везде учитывать передаваемые параметры + перегрузки функции
pg_dump -t t3 --encrypt_columns "a,b" --encrypt "CREATE FUNCTION" #фунцкия объявляется тут
pg_dump -t t4 --encrypt_columns "id" --encrypt "star.sql"
pg_dump -t t12 --encrypt "star.sql" #--encrypt по отдельности шифрует ВСЕ столбцы, а --encrypt_columns - предупреждение - отдельно от encrypt ничего не делает

