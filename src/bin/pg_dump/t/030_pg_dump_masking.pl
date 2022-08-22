# Copyright (c) 2021-2022, PostgreSQL Global Development Group

use strict;
use warnings;

use PostgreSQL::Test::Cluster;
use PostgreSQL::Test::Utils;
use Test::More;

my $tempdir = PostgreSQL::Test::Utils::tempdir;
my $node = PostgreSQL::Test::Cluster->new('main');
$node->init;
$node->start;

$node->safe_psql("postgres", "CREATE TABLE t0(id int, t text)");
$node->safe_psql("postgres", "CREATE TABLE t1(id int, d timestamp)");
$node->safe_psql("postgres", "CREATE TABLE t2(id int, r real)");
$node->safe_psql("postgres", "CREATE TABLE t3(id int)");

$node->safe_psql("postgres", "INSERT INTO t0 SELECT generate_series(1,3) AS id, md5(random()::text) AS t");
$node->safe_psql("postgres", "INSERT INTO t1 SELECT generate_series(1,3) AS id,
															NOW() + (random() * (interval '90 days')) + '30 days' AS d");
$node->safe_psql("postgres", "INSERT INTO t2 SELECT generate_series(1,3) AS id, random() * 100 AS r");
$node->safe_psql("postgres", "INSERT INTO t3 SELECT generate_series(1,3) AS id");

$node->safe_psql("postgres", "CREATE SCHEMA test_schema");

#masking functions

my %functions = (
	'mask_int' => {
		func_name => 'mask_int',
		code => 'res := -1',
		param_type => 'integer',
		},
	'mask_int_with_schema' => {
		func_name => 'test_schema.mask_int_with_schema',
		code => 'res := -2',
		param_type => 'integer',
		},
	'mask_real' => {
		func_name => 'mask_real',
		code => 'res := -1.5',
		param_type => 'real',
		},
	'mask_text' => {
		func_name => 'mask_text',
		code => 'res := \'*****\'',
		param_type => 'text',
		},
	'mask_timestamp' => {
		func_name => 'mask_timestamp',
		code => 'res := \'1970-01-01 00:00:00\'',
		param_type => 'timestamp',
		},
);

#пока код не работает, зато компилируется!

foreach my $function (sort keys %functions)
{
	my $query = sprintf "CREATE OR REPLACE FUNCTION %s (IN elem %s, OUT res %s) RETURNS %s AS
			\$BODY\$
			BEGIN   				
				%s;
				RETURN;
			END
			\$BODY\$ LANGUAGE plpgsql;", $functions{$function}->{func_name}, $functions{$function}->{param_type},
			$functions{$function}->{param_type}, $functions{$function}->{param_type}, $functions{$function}->{code};
	$node->safe_psql("postgres", $query);
}

my %tests = (
    'test_mask_all_ids' => {
		regexp => qr/^
			\QCOPY public.t0 (id, t) FROM stdin;\E\n
			(-1\s*\w*\n){3}
			\Q\.\E\n
			(.|\n)*
			\QCOPY public.t1 (id, d) FROM stdin;\E\n
			(-1\s*\d{4}-\d{2}-\d{2}\ \d{2}:\d{2}:\d{2}\.\d*\n){3}
			\Q\.\E\n
			(.|\n)*
			\QCOPY public.t2 (id, r) FROM stdin;\E\n
			(-1\s*\d*\.\d*\n){3}
			\Q\.\E\n
			(.|\n)*
			\QCOPY public.t3 (id) FROM stdin;\E\n
			(-1\s*\n){3}
			\Q\.\E
		/xm,
		dump => [
            'pg_dump',
            'postgres',
            '-f', "$tempdir/test_mask_all_ids.sql",
            '--mask-columns', '"id"',
			'--mask-function', 'mask_int']
            },
    'test_mask_some_ids' => {
		regexp => qr/^
            \QCOPY public.t0 (id, t) FROM stdin;\E\n
			(-1\s*\w*\n){3}
			\Q\.\E\n
			(.|\n)*
			\QCOPY public.t1 (id, d) FROM stdin;\E\n
			(-1\s*\d{4}-\d{2}-\d{2}\ \d{2}:\d{2}:\d{2}\.\d*\n){3}
			\Q\.\E\n
			(.|\n)*
			\QCOPY public.t2 (id, r) FROM stdin;\E\n
			1\s*\d*\.\d*\n2\s*\d*\.\d*\n3\s*\d*\.\d*\n
            \Q\.\E\n
			(.|\n)*
			\QCOPY public.t3 (id) FROM stdin;\E\n
			1\s*\n2\s*\n3\s*\n
			\Q\.\E
        /xm,
		dump => [
            'pg_dump',
            'postgres',
            '-f', "$tempdir/test_mask_some_ids.sql",
            '--mask-columns', '"t0.id, t1.id"',
			'--mask-function', 'mask_int']
            },
    'test_mask_different_types' => {
		regexp => qr/^
            \QCOPY public.t0 (id, t) FROM stdin;\E\n
            1\s*\*{5}\n2\s*\*{5}\n3\s*\*{5}\n
            \Q\.\E\n
			(.|\n)*
			\QCOPY public.t1 (id, d) FROM stdin;\E\n
			1\s*\Q1970-01-01 00:00:00\E\n2\s*\Q1970-01-01 00:00:00\E\n3\s*\Q1970-01-01 00:00:00\E\n
            \Q\.\E\n
			(.|\n)*
			\QCOPY public.t2 (id, r) FROM stdin;\E\n
			1\s*\Q-1.5\E\n2\s*\Q-1.5\E\n3\s*\Q-1.5\E\n
            \Q\.\E\n
			(.|\n)*
			\QCOPY public.t3 (id) FROM stdin;\E\n
			1\s*\n2\s*\n3\s*\n
			\Q\.\E
        /xm,
		dump => [
			'pg_dump',
			'postgres',
			'-f', "$tempdir/test_mask_different_types.sql",
			'--mask-columns', 't',
			'--mask-function', 'mask_text',
			'--mask-columns', 'd',
			'--mask-function', 'mask_timestamp',
			'--mask-columns', 'r',
			'--mask-function', 'mask_real']
        },
    'test_mask_ids_with_schema' => {
		regexp => qr/^
			\QCOPY public.t0 (id, t) FROM stdin;\E\n
			(-2\s*\w*\n){3}
			\Q\.\E\n
			(.|\n)*
			\QCOPY public.t1 (id, d) FROM stdin;\E\n
			(-2\s*\d{4}-\d{2}-\d{2}\ \d{2}:\d{2}:\d{2}\.\d*\n){3}
			\Q\.\E\n
			(.|\n)*
			\QCOPY public.t2 (id, r) FROM stdin;\E\n
			(-2\s*\d*\.\d*\n){3}
			\Q\.\E\n
			(.|\n)*
			\QCOPY public.t3 (id) FROM stdin;\E\n
			(-2\s*\n){3}
			\Q\.\E
		/xm,
		dump => [
            'pg_dump',
            'postgres',
            '-f', "$tempdir/test_mask_ids_with_schema.sql",
            '--mask-columns', 'id',
			'--mask-function', 'test_schema.mask_int_with_schema']
            },
	'test_mask_ids_file' => {
		regexp => qr/^
            \QCOPY public.t0 (id, t) FROM stdin;\E\n
            (-3\s*\w*\n){3}
			\Q\.\E
        /xm,
		dump => [
            'pg_dump',
            'postgres',
            '-f', "$tempdir/test_mask_ids_file.sql",
			'-t', 't0',
            '--mask-columns', 'id',
			'--mask-function', "$tempdir/mask_ids.sql"]
            },
	'test_mask_ids_insert' => {
		regexp => qr/^
			(\QINSERT INTO public.t0 (id, t) VALUES (-1, \E\'\w*\'\Q);\E\n){3}
		/xm,
		dump => [
            'pg_dump',
            'postgres',
            '-f', "$tempdir/test_mask_ids_insert.sql",
			'-t', 't0',
			'--column-insert',
            '--mask-columns', 'id',
			'--mask-function', 'mask_int']
            },
);

open my $fileHandle, ">", "$tempdir/mask_ids.sql";
print $fileHandle "CREATE OR REPLACE FUNCTION f_int (IN elem integer, OUT res integer) RETURNS integer AS
			\$BODY\$
			BEGIN  				
				res := -3;
				RETURN;
			END
			\$BODY\$ LANGUAGE plpgsql";
close ($fileHandle);

foreach my $test (sort keys %tests)
{
	$node->command_ok(\@{ $tests{$test}->{dump} },"$test: pg_dump runs");

	my $output_file = slurp_file("$tempdir/${test}.sql");

    ok($output_file =~ $tests{$test}->{regexp}, "$test: should be dumped");
}

done_testing();