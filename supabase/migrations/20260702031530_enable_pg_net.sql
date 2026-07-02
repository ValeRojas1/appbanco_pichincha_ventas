-- Habilita pg_net para llamadas HTTP asíncronas desde triggers (notificaciones FCM).

create extension if not exists pg_net with schema extensions;
