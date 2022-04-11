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

$node->safe_psql("postgres", "CREATE SCHEMA t_schm");

#masking functions

$node->safe_psql("postgres", "CREATE OR REPLACE FUNCTION mask_int (IN elem integer, OUT res integer) RETURNS integer AS
			'
			BEGIN  				
				res := -1;
				RETURN;
			END
			' LANGUAGE plpgsql;");

$node->safe_psql("postgres", "CREATE OR REPLACE FUNCTION t_schm.mask_int_1 (IN elem integer, OUT res integer) RETURNS integer AS
			'
			BEGIN  				
				res := -2;
				RETURN;
			END
			' LANGUAGE plpgsql;");

$node->safe_psql("postgres", "CREATE OR REPLACE FUNCTION mask_real (IN elem real, OUT res real) RETURNS real AS
			'
			BEGIN  				
				res := -1.5;
				RETURN;
			END
			' LANGUAGE plpgsql;");

$node->safe_psql("postgres", "CREATE OR REPLACE FUNCTION mask_text (IN elem text, OUT res text) RETURNS text AS
			\$BODY\$
			BEGIN  				
				res := '*****';
				RETURN;
			END
			\$BODY\$ LANGUAGE plpgsql;");

$node->safe_psql("postgres", "CREATE OR REPLACE FUNCTION msk_tmstmp (IN elem timestamp, OUT res timestamp) RETURNS timestamp AS
			\$BODY\$
			BEGIN  				
				res := '1970-01-01 00:00:00';
				RETURN;
			END
			\$BODY\$ LANGUAGE plpgsql;");

my %default_regexp = (
    'mask_all_ids' => qr/^
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
	'mask_all_ids_schema' => qr/^
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
    'mask_some_ids' => qr/^
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
    'mask_different_types' => qr/^
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
	'mask_ids_file' => qr/^
            \QCOPY public.t0 (id, t) FROM stdin;\E\n
            (-3\s*\w*\n){3}
			\Q\.\E
        /xm,
	'mask_ids_insert' => qr/^
			(\QINSERT INTO public.t0 (id, t) VALUES (-1, \E\'\w*\'\Q);\E\n){3}
		/xm,
);

my %tests = (
    'test_mask_all_ids' => {
		regexp => $default_regexp{'mask_all_ids'},
		dump => [
            'pg_dump',
            'postgres',
            '-f', "$tempdir/test_mask_all_ids.sql",
            '--mask-columns', '"id"',
			'--mask-function', 'mask_int']
            },
    'test_mask_some_ids' => {
		regexp => $default_regexp{'mask_some_ids'},
		dump => [
            'pg_dump',
            'postgres',
            '-f', "$tempdir/test_mask_some_ids.sql",
            '--mask-columns', '"t0.id, t1.id"',
			'--mask-function', 'mask_int']
            },
    'test_mask_different_types' => {
		regexp => $default_regexp{'mask_different_types'},
		dump => [
			'pg_dump',
			'postgres',
			'-f', "$tempdir/test_mask_different_types.sql",
			'--mask-columns', 't',
			'--mask-function', 'mask_text',
			'--mask-columns', 'd',
			'--mask-function', 'msk_tmstmp',
			'--mask-columns', 'r',
			'--mask-function', 'mask_real']
        },
    'test_mask_ids_with_schema' => {
		regexp => $default_regexp{'mask_all_ids_schema'},
		dump => [
            'pg_dump',
            'postgres',
            '-f', "$tempdir/test_mask_ids_with_schema.sql",
            '--mask-columns', 'id',
			'--mask-function', 't_schm.mask_int_1']
            },
	'test_mask_ids_file' => {
		regexp => $default_regexp{'mask_ids_file'},
		dump => [
            'pg_dump',
            'postgres',
            '-f', "$tempdir/test_mask_ids_file.sql",
			'-t', 't0',
            '--mask-columns', 'id',
			'--mask-function', "$tempdir/mask_ids.sql"]
            },
	'test_mask_ids_insert' => {
		regexp => $default_regexp{'mask_ids_insert'},
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