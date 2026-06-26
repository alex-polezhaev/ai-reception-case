set check_function_bodies = off;

CREATE OR REPLACE FUNCTION public.update_incomplete_timestamp()
 RETURNS trigger
 LANGUAGE plpgsql
AS $function$BEGIN
  IF NEW.incomplete_timeline IS DISTINCT FROM OLD.incomplete_timeline THEN
    IF NEW.incomplete_timeline = '[]'::jsonb THEN
      NEW.incomplete_timestamp = NULL;
    ELSE
      NEW.incomplete_timestamp = NOW();
    END IF;
  END IF;
  RETURN NEW;
END;$function$
;


