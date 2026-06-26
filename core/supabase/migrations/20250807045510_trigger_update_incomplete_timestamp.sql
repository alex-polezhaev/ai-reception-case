alter table "public"."devices" add column "incomplete_timestamp" timestamp with time zone;

CREATE INDEX idx_devices_incomplete_timestamp ON public.devices USING btree (incomplete_timestamp);

set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.update_incomplete_timestamp()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$
BEGIN
   IF NEW.incomplete_timeline IS DISTINCT FROM OLD.incomplete_timeline THEN
       NEW.incomplete_timestamp = NOW();
   END IF;
   RETURN NEW;
END;
$function$
;

CREATE TRIGGER trigger_update_incomplete_timestamp BEFORE UPDATE ON public.devices FOR EACH ROW EXECUTE FUNCTION update_incomplete_timestamp();


