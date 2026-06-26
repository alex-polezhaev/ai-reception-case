-- Example proxy row. Replace with your own proxy or load credentials from env/secrets.
INSERT INTO "public"."proxies" ("id", "host", "port", "username", "password", "priority", "created_at") VALUES ('1', 'proxy.example.com', '50100', 'PROXY_USER', 'PROXY_PASSWORD', '1', '2025-07-11 02:21:13+00');

INSERT INTO public.devices (id) VALUES
('PRINCESS-8Q5I'),
('MAX-4Y1M'),
('CHARLIE-1T3Q'),
('COCO-1B7O'),
('LOLA-7F9V'),
('ROCKY-9B1T'),
('BUDDY-7E4B'),
('LUCY-8X1X'),
('LUCKY-7U9W'),
('DAISY-6Z5F'),
('LUNA-3N9H'),
('BAILEY-5U5A'),
('BELLA-1P7U'),
('TEDDY-5P2D'),
('CHLOE-6Y6I'),
('TOBY-4A6M'),
('MOLLY-7P4M'),
('JACK-3M1X'),
('MILO-2U3E'),
('OLIVER-2A2L'),
('MAGGIE-6A0H'),
('PENNY-4Q1G'),
('SOPHIE-2N0P'),
('LILY-9C9F'),
('COOPER-1R6L'),
('OREO-7L5K'),
('MIA-2E7N'),
('LEO-3S7A'),
('COOKIE-1X2J'),
('LULU-2L2W'),
('RUBY-8U4U'),
('STELLA-9Q5N'),
('PRINCE-9O5G'),
('GIZMO-8A0Q'),
('GINGER-6Q6B'),
('RILEY-6O4Y'),
('ROSIE-5R6C'),
('ROXY-6Y7M'),
('CODY-7E9T'),
('LADY-7L4H'),
('SADIE-8G2I'),
('OSCAR-7E9E'),
('ZOEY-6L2R'),
('BUSTER-1B6Q'),
('SHADOW-6E8I'),
('JAKE-3P4R'),
('BRUNO-2A0K'),
('ZOE-1X2F'),
('HENRY-1C4T'),
('SAMMY-1X3W'),
('PEPPER-9R5V'),
('BEAR-3L6O'),
('BLUE-1Z3D'),
('ROCCO-1N5D'),
('DUKE-6P0H'),
('LOUIE-6W3F'),
('PEANUT-4T1J'),
('FRANKIE-4X3Q'),
('DEXTER-2A1R'),
('GRACIE-3S3L'),
('KING-2R0T'),
('SANDY-2U7U'),
('HONEY-8J5Y'),
('BENJI-0K3Y'),
('REX-5L6P');

-- Grant privileges on all PGMQ objects to service_role only
GRANT USAGE ON SCHEMA pgmq TO service_role;
GRANT ALL ON ALL TABLES IN SCHEMA pgmq TO service_role;
GRANT ALL ON ALL SEQUENCES IN SCHEMA pgmq TO service_role;
GRANT ALL ON ALL FUNCTIONS IN SCHEMA pgmq TO service_role;

-- Default privileges for new objects
ALTER DEFAULT PRIVILEGES IN SCHEMA pgmq GRANT ALL ON TABLES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA pgmq GRANT ALL ON SEQUENCES TO service_role;
ALTER DEFAULT PRIVILEGES IN SCHEMA pgmq GRANT ALL ON FUNCTIONS TO service_role;

-- Create PGMQ queues
SELECT pgmq.create('session-queue');
SELECT pgmq.create('transcription-queue');
SELECT pgmq.create('analysis-queue');
