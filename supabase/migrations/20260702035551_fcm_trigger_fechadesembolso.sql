-- Extiende el trigger FCM para notificar cambios de fecha de desembolso
-- en solicitudes aprobadas, condicionadas o desembolsadas.

drop trigger if exists on_solicitud_estado_changed on public.solicitudescredito;

create trigger on_solicitud_estado_changed
  after update of estado, fechadesembolso on public.solicitudescredito
  for each row
  when (
    old.estado is distinct from new.estado
    or (
      old.fechadesembolso is distinct from new.fechadesembolso
      and new.estado = any (array['aprobada', 'condicionada', 'desembolsada'])
    )
  )
  execute function notify_solicitud_estado();
