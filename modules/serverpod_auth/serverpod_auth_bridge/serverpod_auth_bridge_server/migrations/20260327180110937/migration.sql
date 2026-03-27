BEGIN;

--
-- ACTION CREATE TABLE
--
CREATE TABLE "serverpod_reactive_db_call" (
    "id" bigserial PRIMARY KEY,
    "handlerName" text NOT NULL,
    "sourceTable" text NOT NULL,
    "operation" text NOT NULL,
    "rowData" text NOT NULL,
    "createdAt" timestamp without time zone NOT NULL
);

-- Indexes
CREATE INDEX "serverpod_reactive_db_call_created_at_idx" ON "serverpod_reactive_db_call" USING btree ("createdAt");
CREATE INDEX "serverpod_reactive_db_call_handler_name_idx" ON "serverpod_reactive_db_call" USING btree ("handlerName");


--
-- MIGRATION VERSION FOR serverpod_auth_bridge
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_bridge', '20260327180110937', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260327180110937', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod', '20260327180003601', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260327180003601', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_core
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_core', '20260324085844499', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260324085844499', "timestamp" = now();

--
-- MIGRATION VERSION FOR serverpod_auth_idp
--
INSERT INTO "serverpod_migrations" ("module", "version", "timestamp")
    VALUES ('serverpod_auth_idp', '20260324085850822', now())
    ON CONFLICT ("module")
    DO UPDATE SET "version" = '20260324085850822', "timestamp" = now();


COMMIT;
