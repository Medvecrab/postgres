/*-------------------------------------------------------------------------
 *
 * masking.h
 *
 *	Masking functionality for pg_dump
 *
 * Portions Copyright (c) 1996-2022, PostgreSQL Global Development Group
 * Portions Copyright (c) 1994, Regents of the University of California
 *
 * IDENTIFICATION
 *		src/bin/pg_dump/masking.h
 *
 *-------------------------------------------------------------------------
 */

#include "postgres_fe.h"

#include "dumputils.h"
#include "fe_utils/string_utils.h"
#include "common/logging.h"
#include "pg_dump.h"

#ifndef MASKING_H
#define MASKING_H

typedef struct
{
	char* column; 	/* name of masked column */
	char* table;	/* name of table where masked column is stored */
	char* func;		/* name of masking function */
	char* schema;	/* name of schema where masking function is stored */
} MaskColumnInfo;


/*
* mask_column_info_list contains info about every to-be-masked column:
* its name, a name of its table (if nothing is specified - mask all columns with this name),
* name of masking function and name of schema containing this function (public if not specified)
*/

extern SimplePtrList mask_column_info_list;
extern SimpleStringList mask_columns_list;
extern SimpleStringList mask_func_list;

void formMaskingLists(DumpOptions* dopt);
void addFuncToDatabase(MaskColumnInfo* cur_mask_column_info, 
							 FILE* mask_func_file, PGconn *connection);
void maskColumns(TableInfo *tbinfo, char* current_column_name,
						PQExpBuffer* q, SimpleStringList* column_names);


#endif							/* MASKING_H */
