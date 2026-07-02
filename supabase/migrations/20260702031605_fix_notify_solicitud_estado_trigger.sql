-- Corrige el trigger de notificaciones FCM al cliente.
-- El trigger anterior fallaba con: operator does not exist: text ->> unknown
-- y bloqueaba cualquier UPDATE de estado (p. ej. tomar solicitud como operador).

create or replace function public.notify_solicitud_estado()
returns trigger
language plpgsql
security definer
set search_path = public, extensions, net
as $$
declare
  v_url text := 'https://ipiqcrlpepoajvsbhnun.supabase.co/functions/v1/send_fcm_notification';
  v_anon_key text := 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImlwaXFjcmxwZXBvYWp2c2JobnVuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzc1NzcyNjAsImV4cCI6MjA5MzE1MzI2MH0.MV-JZ09HhcZECJBCfTmU3uymXot6VnRVRF1JeDPi1OI';
begin
  -- Best effort: nunca bloquear el UPDATE de la solicitud.
  begin
    perform net.http_post(
      url := v_url,
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'Authorization', 'Bearer ' || v_anon_key
      ),
      body := jsonb_build_object(
        'record', to_jsonb(new),
        'old_record', to_jsonb(old)
      )
    );
  exception when others then
    raise warning 'notify_solicitud_estado fallo (no bloqueante): %', sqlerrm;
  end;
  return new;
end;
$$;

drop trigger if exists on_solicitud_estado_changed on public.solicitudescredito;

create trigger on_solicitud_estado_changed
  after update of estado on public.solicitudescredito
  for each row
  when (old.estado is distinct from new.estado)
  execute function notify_solicitud_estado();
