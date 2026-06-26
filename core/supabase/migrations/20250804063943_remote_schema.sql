

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;


CREATE SCHEMA IF NOT EXISTS "pgmq_public";


ALTER SCHEMA "pgmq_public" OWNER TO "postgres";


COMMENT ON SCHEMA "public" IS 'standard public schema';



CREATE EXTENSION IF NOT EXISTS "pg_graphql" WITH SCHEMA "graphql";






CREATE EXTENSION IF NOT EXISTS "pg_stat_statements" WITH SCHEMA "extensions";






CREATE EXTENSION IF NOT EXISTS "pgcrypto" WITH SCHEMA "extensions";






CREATE SCHEMA IF NOT EXISTS "pgmq";

CREATE EXTENSION IF NOT EXISTS "pgmq" WITH SCHEMA "pgmq";






CREATE EXTENSION IF NOT EXISTS "supabase_vault" WITH SCHEMA "vault";






CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA "extensions";






CREATE OR REPLACE FUNCTION "pgmq_public"."archive"("queue_name" "text", "message_id" bigint) RETURNS boolean
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$ begin return pgmq.archive( queue_name := queue_name, msg_id := message_id ); end; $$;


ALTER FUNCTION "pgmq_public"."archive"("queue_name" "text", "message_id" bigint) OWNER TO "postgres";


COMMENT ON FUNCTION "pgmq_public"."archive"("queue_name" "text", "message_id" bigint) IS 'Archives a message by moving it from the queue to a permanent archive.';



CREATE OR REPLACE FUNCTION "pgmq_public"."delete"("queue_name" "text", "message_id" bigint) RETURNS boolean
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$ begin return pgmq.delete( queue_name := queue_name, msg_id := message_id ); end; $$;


ALTER FUNCTION "pgmq_public"."delete"("queue_name" "text", "message_id" bigint) OWNER TO "postgres";


COMMENT ON FUNCTION "pgmq_public"."delete"("queue_name" "text", "message_id" bigint) IS 'Permanently deletes a message from the specified queue.';



CREATE OR REPLACE FUNCTION "pgmq_public"."pop"("queue_name" "text") RETURNS SETOF "pgmq"."message_record"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$ begin return query select * from pgmq.pop( queue_name := queue_name ); end; $$;


ALTER FUNCTION "pgmq_public"."pop"("queue_name" "text") OWNER TO "postgres";


COMMENT ON FUNCTION "pgmq_public"."pop"("queue_name" "text") IS 'Retrieves and locks the next message from the specified queue.';



CREATE OR REPLACE FUNCTION "pgmq_public"."read"("queue_name" "text", "sleep_seconds" integer, "n" integer) RETURNS SETOF "pgmq"."message_record"
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$ begin return query select * from pgmq.read( queue_name := queue_name, vt := sleep_seconds, qty := n ); end; $$;


ALTER FUNCTION "pgmq_public"."read"("queue_name" "text", "sleep_seconds" integer, "n" integer) OWNER TO "postgres";


COMMENT ON FUNCTION "pgmq_public"."read"("queue_name" "text", "sleep_seconds" integer, "n" integer) IS 'Reads up to "n" messages from the specified queue with an optional "sleep_seconds" (visibility timeout).';



CREATE OR REPLACE FUNCTION "pgmq_public"."send"("queue_name" "text", "message" "jsonb", "sleep_seconds" integer DEFAULT 0) RETURNS SETOF bigint
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$ begin return query select * from pgmq.send( queue_name := queue_name, msg := message, delay := sleep_seconds ); end; $$;


ALTER FUNCTION "pgmq_public"."send"("queue_name" "text", "message" "jsonb", "sleep_seconds" integer) OWNER TO "postgres";


COMMENT ON FUNCTION "pgmq_public"."send"("queue_name" "text", "message" "jsonb", "sleep_seconds" integer) IS 'Sends a message to the specified queue, optionally delaying its availability by a number of seconds.';



CREATE OR REPLACE FUNCTION "pgmq_public"."send_batch"("queue_name" "text", "messages" "jsonb"[], "sleep_seconds" integer DEFAULT 0) RETURNS SETOF bigint
    LANGUAGE "plpgsql"
    SET "search_path" TO ''
    AS $$ begin return query select * from pgmq.send_batch( queue_name := queue_name, msgs := messages, delay := sleep_seconds ); end; $$;


ALTER FUNCTION "pgmq_public"."send_batch"("queue_name" "text", "messages" "jsonb"[], "sleep_seconds" integer) OWNER TO "postgres";


COMMENT ON FUNCTION "pgmq_public"."send_batch"("queue_name" "text", "messages" "jsonb"[], "sleep_seconds" integer) IS 'Sends a batch of messages to the specified queue, optionally delaying their availability by a number of seconds.';



CREATE OR REPLACE FUNCTION "public"."notify_pcm_chunk_insert"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    PERFORM pgmq.send('session-queue', jsonb_build_object('pcm_chunk_id', NEW.id));
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."notify_pcm_chunk_insert"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_vad_session_insert"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    PERFORM pgmq.send('transcription-queue', jsonb_build_object('vad_session_id', NEW.id));
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."notify_vad_session_insert"() OWNER TO "postgres";


CREATE OR REPLACE FUNCTION "public"."notify_vad_transcription_insert"() RETURNS "trigger"
    LANGUAGE "plpgsql"
    AS $$
BEGIN
    PERFORM pgmq.send('analysis-queue', jsonb_build_object('vad_session_id', NEW.vad_session_id));
    RETURN NEW;
END;
$$;


ALTER FUNCTION "public"."notify_vad_transcription_insert"() OWNER TO "postgres";

SET default_tablespace = '';

SET default_table_access_method = "heap";


CREATE TABLE IF NOT EXISTS "public"."devices" (
    "id" "text" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "boot_at" timestamp with time zone,
    "bad_vad_count" integer DEFAULT 0 NOT NULL,
    "title" "text",
    "incomplete_timeline" "jsonb" DEFAULT '[]'::"jsonb" NOT NULL
);


ALTER TABLE "public"."devices" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."logs" (
    "id" bigint NOT NULL,
    "level" "text" NOT NULL,
    "timestamp" timestamp with time zone NOT NULL,
    "source" "text" NOT NULL,
    "message" "text" NOT NULL
);


ALTER TABLE "public"."logs" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."logs_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."logs_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."logs_id_seq" OWNED BY "public"."logs"."id";



CREATE TABLE IF NOT EXISTS "public"."pcm_chunks" (
    "id" integer NOT NULL,
    "device_id" "text" NOT NULL,
    "s3_key" "text" NOT NULL,
    "vad_timeline" integer[] NOT NULL,
    "timestamp" timestamp with time zone NOT NULL,
    "duration" integer NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"() NOT NULL,
    CONSTRAINT "check_vad_timeline_length" CHECK (("array_length"("vad_timeline", 1) = 60))
);


ALTER TABLE "public"."pcm_chunks" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."pcm_chunks_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."pcm_chunks_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."pcm_chunks_id_seq" OWNED BY "public"."pcm_chunks"."id";



CREATE TABLE IF NOT EXISTS "public"."proxies" (
    "id" bigint NOT NULL,
    "host" "text" NOT NULL,
    "port" integer NOT NULL,
    "username" "text" NOT NULL,
    "password" "text" NOT NULL,
    "priority" integer NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."proxies" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."proxies_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."proxies_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."proxies_id_seq" OWNED BY "public"."proxies"."id";



CREATE TABLE IF NOT EXISTS "public"."telegram_account_devices" (
    "account_id" bigint NOT NULL,
    "device_id" "text" NOT NULL
);


ALTER TABLE "public"."telegram_account_devices" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."telegram_accounts" (
    "id" bigint NOT NULL,
    "first_name" "text" NOT NULL,
    "last_name" "text",
    "username" "text",
    "language_code" "text",
    "is_premium" boolean DEFAULT false,
    "photo_url" "text",
    "created_at" timestamp with time zone DEFAULT "now"(),
    "updated_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."telegram_accounts" OWNER TO "postgres";


CREATE TABLE IF NOT EXISTS "public"."vad_analysis" (
    "id" bigint NOT NULL,
    "vad_session_id" bigint NOT NULL,
    "title" "text" NOT NULL,
    "type" "text" NOT NULL,
    "keywords" "text"[] NOT NULL,
    "products" "text"[],
    "quality" integer,
    "optimized_text" "text"
);


ALTER TABLE "public"."vad_analysis" OWNER TO "postgres";


ALTER TABLE "public"."vad_analysis" ALTER COLUMN "id" ADD GENERATED ALWAYS AS IDENTITY (
    SEQUENCE NAME "public"."vad_analysis_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1
);



CREATE TABLE IF NOT EXISTS "public"."vad_sessions" (
    "id" bigint NOT NULL,
    "device_id" "text" NOT NULL,
    "s3_key" "text" NOT NULL,
    "timestamp" timestamp with time zone NOT NULL,
    "duration" double precision NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"(),
    "is_unsuitable" boolean DEFAULT false,
    "is_read" boolean
);


ALTER TABLE "public"."vad_sessions" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."vad_sessions_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."vad_sessions_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."vad_sessions_id_seq" OWNED BY "public"."vad_sessions"."id";



CREATE TABLE IF NOT EXISTS "public"."vad_transcriptions" (
    "id" bigint NOT NULL,
    "vad_session_id" bigint NOT NULL,
    "text" "text" NOT NULL,
    "segments" "jsonb" NOT NULL,
    "created_at" timestamp with time zone DEFAULT "now"()
);


ALTER TABLE "public"."vad_transcriptions" OWNER TO "postgres";


CREATE SEQUENCE IF NOT EXISTS "public"."vad_transcriptions_id_seq"
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE "public"."vad_transcriptions_id_seq" OWNER TO "postgres";


ALTER SEQUENCE "public"."vad_transcriptions_id_seq" OWNED BY "public"."vad_transcriptions"."id";



ALTER TABLE ONLY "public"."logs" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."logs_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."pcm_chunks" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."pcm_chunks_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."proxies" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."proxies_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."vad_sessions" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."vad_sessions_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."vad_transcriptions" ALTER COLUMN "id" SET DEFAULT "nextval"('"public"."vad_transcriptions_id_seq"'::"regclass");



ALTER TABLE ONLY "public"."devices"
    ADD CONSTRAINT "devices_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."logs"
    ADD CONSTRAINT "logs_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."pcm_chunks"
    ADD CONSTRAINT "pcm_chunks_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."proxies"
    ADD CONSTRAINT "proxies_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."telegram_account_devices"
    ADD CONSTRAINT "telegram_account_devices_pkey" PRIMARY KEY ("account_id", "device_id");



ALTER TABLE ONLY "public"."telegram_accounts"
    ADD CONSTRAINT "telegram_accounts_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vad_analysis"
    ADD CONSTRAINT "vad_analysis_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vad_analysis"
    ADD CONSTRAINT "vad_analysis_vad_session_id_key" UNIQUE ("vad_session_id");



ALTER TABLE ONLY "public"."vad_sessions"
    ADD CONSTRAINT "vad_sessions_device_id_s3_key_key" UNIQUE ("device_id", "s3_key");



ALTER TABLE ONLY "public"."vad_sessions"
    ADD CONSTRAINT "vad_sessions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vad_transcriptions"
    ADD CONSTRAINT "vad_transcriptions_pkey" PRIMARY KEY ("id");



ALTER TABLE ONLY "public"."vad_transcriptions"
    ADD CONSTRAINT "vad_transcriptions_vad_session_id_key" UNIQUE ("vad_session_id");



CREATE INDEX "idx_devices_incomplete_timeline_timestamps" ON "public"."devices" USING "gin" ("incomplete_timeline");



CREATE INDEX "idx_pcm_chunks_device_id" ON "public"."pcm_chunks" USING "btree" ("device_id");



CREATE INDEX "idx_pcm_chunks_device_timestamp" ON "public"."pcm_chunks" USING "btree" ("device_id", "timestamp");



CREATE UNIQUE INDEX "idx_pcm_chunks_s3_key" ON "public"."pcm_chunks" USING "btree" ("s3_key");



CREATE INDEX "idx_pcm_chunks_timestamp" ON "public"."pcm_chunks" USING "btree" ("timestamp");



CREATE UNIQUE INDEX "idx_vad_sessions_s3_key" ON "public"."vad_sessions" USING "btree" ("s3_key");



CREATE OR REPLACE TRIGGER "pcm_chunks_insert_trigger" AFTER INSERT ON "public"."pcm_chunks" FOR EACH ROW EXECUTE FUNCTION "public"."notify_pcm_chunk_insert"();



CREATE OR REPLACE TRIGGER "vad_sessions_insert_trigger" AFTER INSERT ON "public"."vad_sessions" FOR EACH ROW EXECUTE FUNCTION "public"."notify_vad_session_insert"();



CREATE OR REPLACE TRIGGER "vad_transcriptions_insert_trigger" AFTER INSERT ON "public"."vad_transcriptions" FOR EACH ROW EXECUTE FUNCTION "public"."notify_vad_transcription_insert"();



ALTER TABLE ONLY "public"."pcm_chunks"
    ADD CONSTRAINT "pcm_chunks_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "public"."devices"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."telegram_account_devices"
    ADD CONSTRAINT "telegram_account_devices_account_id_fkey" FOREIGN KEY ("account_id") REFERENCES "public"."telegram_accounts"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."telegram_account_devices"
    ADD CONSTRAINT "telegram_account_devices_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "public"."devices"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."vad_analysis"
    ADD CONSTRAINT "vad_analysis_vad_session_id_fkey" FOREIGN KEY ("vad_session_id") REFERENCES "public"."vad_sessions"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."vad_sessions"
    ADD CONSTRAINT "vad_sessions_device_id_fkey" FOREIGN KEY ("device_id") REFERENCES "public"."devices"("id") ON DELETE CASCADE;



ALTER TABLE ONLY "public"."vad_transcriptions"
    ADD CONSTRAINT "vad_transcriptions_vad_session_id_fkey" FOREIGN KEY ("vad_session_id") REFERENCES "public"."vad_sessions"("id") ON DELETE CASCADE;





ALTER PUBLICATION "supabase_realtime" OWNER TO "postgres";


GRANT USAGE ON SCHEMA "pgmq_public" TO "anon";
GRANT USAGE ON SCHEMA "pgmq_public" TO "authenticated";
GRANT USAGE ON SCHEMA "pgmq_public" TO "service_role";



GRANT USAGE ON SCHEMA "public" TO "postgres";
GRANT USAGE ON SCHEMA "public" TO "anon";
GRANT USAGE ON SCHEMA "public" TO "authenticated";
GRANT USAGE ON SCHEMA "public" TO "service_role";











































































































































































GRANT ALL ON FUNCTION "pgmq_public"."archive"("queue_name" "text", "message_id" bigint) TO "service_role";
GRANT ALL ON FUNCTION "pgmq_public"."archive"("queue_name" "text", "message_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "pgmq_public"."archive"("queue_name" "text", "message_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "pgmq_public"."delete"("queue_name" "text", "message_id" bigint) TO "service_role";
GRANT ALL ON FUNCTION "pgmq_public"."delete"("queue_name" "text", "message_id" bigint) TO "anon";
GRANT ALL ON FUNCTION "pgmq_public"."delete"("queue_name" "text", "message_id" bigint) TO "authenticated";



GRANT ALL ON FUNCTION "pgmq_public"."pop"("queue_name" "text") TO "service_role";
GRANT ALL ON FUNCTION "pgmq_public"."pop"("queue_name" "text") TO "anon";
GRANT ALL ON FUNCTION "pgmq_public"."pop"("queue_name" "text") TO "authenticated";



GRANT ALL ON FUNCTION "pgmq_public"."read"("queue_name" "text", "sleep_seconds" integer, "n" integer) TO "service_role";
GRANT ALL ON FUNCTION "pgmq_public"."read"("queue_name" "text", "sleep_seconds" integer, "n" integer) TO "anon";
GRANT ALL ON FUNCTION "pgmq_public"."read"("queue_name" "text", "sleep_seconds" integer, "n" integer) TO "authenticated";



GRANT ALL ON FUNCTION "pgmq_public"."send"("queue_name" "text", "message" "jsonb", "sleep_seconds" integer) TO "service_role";
GRANT ALL ON FUNCTION "pgmq_public"."send"("queue_name" "text", "message" "jsonb", "sleep_seconds" integer) TO "anon";
GRANT ALL ON FUNCTION "pgmq_public"."send"("queue_name" "text", "message" "jsonb", "sleep_seconds" integer) TO "authenticated";



GRANT ALL ON FUNCTION "pgmq_public"."send_batch"("queue_name" "text", "messages" "jsonb"[], "sleep_seconds" integer) TO "service_role";
GRANT ALL ON FUNCTION "pgmq_public"."send_batch"("queue_name" "text", "messages" "jsonb"[], "sleep_seconds" integer) TO "anon";
GRANT ALL ON FUNCTION "pgmq_public"."send_batch"("queue_name" "text", "messages" "jsonb"[], "sleep_seconds" integer) TO "authenticated";



GRANT ALL ON FUNCTION "public"."notify_pcm_chunk_insert"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_pcm_chunk_insert"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_pcm_chunk_insert"() TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_vad_session_insert"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_vad_session_insert"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_vad_session_insert"() TO "service_role";



GRANT ALL ON FUNCTION "public"."notify_vad_transcription_insert"() TO "anon";
GRANT ALL ON FUNCTION "public"."notify_vad_transcription_insert"() TO "authenticated";
GRANT ALL ON FUNCTION "public"."notify_vad_transcription_insert"() TO "service_role";






























GRANT ALL ON TABLE "public"."devices" TO "anon";
GRANT ALL ON TABLE "public"."devices" TO "authenticated";
GRANT ALL ON TABLE "public"."devices" TO "service_role";



GRANT ALL ON TABLE "public"."logs" TO "anon";
GRANT ALL ON TABLE "public"."logs" TO "authenticated";
GRANT ALL ON TABLE "public"."logs" TO "service_role";



GRANT ALL ON SEQUENCE "public"."logs_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."logs_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."logs_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."pcm_chunks" TO "anon";
GRANT ALL ON TABLE "public"."pcm_chunks" TO "authenticated";
GRANT ALL ON TABLE "public"."pcm_chunks" TO "service_role";



GRANT ALL ON SEQUENCE "public"."pcm_chunks_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."pcm_chunks_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."pcm_chunks_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."proxies" TO "anon";
GRANT ALL ON TABLE "public"."proxies" TO "authenticated";
GRANT ALL ON TABLE "public"."proxies" TO "service_role";



GRANT ALL ON SEQUENCE "public"."proxies_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."proxies_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."proxies_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."telegram_account_devices" TO "anon";
GRANT ALL ON TABLE "public"."telegram_account_devices" TO "authenticated";
GRANT ALL ON TABLE "public"."telegram_account_devices" TO "service_role";



GRANT ALL ON TABLE "public"."telegram_accounts" TO "anon";
GRANT ALL ON TABLE "public"."telegram_accounts" TO "authenticated";
GRANT ALL ON TABLE "public"."telegram_accounts" TO "service_role";



GRANT ALL ON TABLE "public"."vad_analysis" TO "anon";
GRANT ALL ON TABLE "public"."vad_analysis" TO "authenticated";
GRANT ALL ON TABLE "public"."vad_analysis" TO "service_role";



GRANT ALL ON SEQUENCE "public"."vad_analysis_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."vad_analysis_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."vad_analysis_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."vad_sessions" TO "anon";
GRANT ALL ON TABLE "public"."vad_sessions" TO "authenticated";
GRANT ALL ON TABLE "public"."vad_sessions" TO "service_role";



GRANT ALL ON SEQUENCE "public"."vad_sessions_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."vad_sessions_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."vad_sessions_id_seq" TO "service_role";



GRANT ALL ON TABLE "public"."vad_transcriptions" TO "anon";
GRANT ALL ON TABLE "public"."vad_transcriptions" TO "authenticated";
GRANT ALL ON TABLE "public"."vad_transcriptions" TO "service_role";



GRANT ALL ON SEQUENCE "public"."vad_transcriptions_id_seq" TO "anon";
GRANT ALL ON SEQUENCE "public"."vad_transcriptions_id_seq" TO "authenticated";
GRANT ALL ON SEQUENCE "public"."vad_transcriptions_id_seq" TO "service_role";









ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON SEQUENCES TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON FUNCTIONS TO "service_role";






ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "postgres";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "anon";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "authenticated";
ALTER DEFAULT PRIVILEGES FOR ROLE "postgres" IN SCHEMA "public" GRANT ALL ON TABLES TO "service_role";






























RESET ALL;
