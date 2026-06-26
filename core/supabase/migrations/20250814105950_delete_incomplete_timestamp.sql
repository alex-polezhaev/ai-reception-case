drop trigger if exists "trigger_update_incomplete_timestamp" on "public"."devices";

drop function if exists "public"."update_incomplete_timestamp"();

drop index if exists "public"."idx_devices_incomplete_timeline_timestamps";

alter table "public"."devices" drop column "incomplete_timeline";


