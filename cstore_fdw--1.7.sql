/* cstore_fdw/cstore_fdw--1.7.sql */

-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION cstore_fdw" to load this file. \quit

CREATE FUNCTION cstore_fdw_handler()
RETURNS fdw_handler
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT;

CREATE FUNCTION cstore_fdw_validator(text[], oid)
RETURNS void
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT;

CREATE FOREIGN DATA WRAPPER cstore_fdw
HANDLER cstore_fdw_handler
VALIDATOR cstore_fdw_validator;

CREATE FUNCTION cstore_ddl_event_end_trigger()
RETURNS event_trigger
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT;

CREATE EVENT TRIGGER cstore_ddl_event_end
ON ddl_command_end
EXECUTE PROCEDURE cstore_ddl_event_end_trigger();

CREATE FUNCTION cstore_table_size(relation regclass)
RETURNS bigint
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT;

CREATE OR REPLACE FUNCTION cstore_clean_table_resources(oid)
RETURNS void
AS 'MODULE_PATHNAME'
LANGUAGE C STRICT;

CREATE OR REPLACE FUNCTION cstore_drop_trigger()
	RETURNS event_trigger
	LANGUAGE plpgsql
	AS $csdt$
DECLARE v_obj record;
BEGIN
	FOR v_obj IN SELECT * FROM pg_event_trigger_dropped_objects() LOOP

		IF v_obj.object_type NOT IN ('table', 'foreign table') THEN
			CONTINUE;
		END IF;

		PERFORM public.cstore_clean_table_resources(v_obj.objid);

	END LOOP;
END;
$csdt$;

CREATE EVENT TRIGGER cstore_drop_event
    ON SQL_DROP
    EXECUTE PROCEDURE cstore_drop_trigger();

CREATE TABLE cstore_tables (
    relid oid NOT NULL,
    block_row_count int NOT NULL,
    version_major bigint NOT NULL,
    version_minor bigint NOT NULL,
    PRIMARY KEY (relid)
) WITH (user_catalog_table = true);

ALTER TABLE cstore_tables SET SCHEMA pg_catalog;

CREATE TABLE cstore_stripes (
    relid oid NOT NULL,
    stripe bigint NOT NULL,
    file_offset bigint NOT NULL,
    skiplist_length bigint NOT NULL,
    data_length bigint NOT NULL,
    PRIMARY KEY (relid, stripe),
    FOREIGN KEY (relid) REFERENCES cstore_tables(relid) ON DELETE CASCADE INITIALLY DEFERRED
) WITH (user_catalog_table = true);

ALTER TABLE cstore_stripes SET SCHEMA pg_catalog;

CREATE TABLE cstore_stripe_attr (
    relid oid NOT NULL,
    stripe bigint NOT NULL,
    attr int NOT NULL,
    exists_size bigint NOT NULL,
    value_size bigint NOT NULL,
    skiplist_size bigint NOT NULL,
    PRIMARY KEY (relid, stripe, attr),
    FOREIGN KEY (relid, stripe) REFERENCES cstore_stripes(relid, stripe) ON DELETE CASCADE INITIALLY DEFERRED
) WITH (user_catalog_table = true);

ALTER TABLE cstore_stripe_attr SET SCHEMA pg_catalog;
