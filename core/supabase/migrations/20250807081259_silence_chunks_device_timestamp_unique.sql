CREATE UNIQUE INDEX silence_chunks_device_timestamp_unique ON public.silence_chunks USING btree (device_id, "timestamp");

alter table "public"."silence_chunks" add constraint "silence_chunks_device_timestamp_unique" UNIQUE using index "silence_chunks_device_timestamp_unique";


