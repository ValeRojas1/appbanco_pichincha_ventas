import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'
import { JWT } from 'https://esm.sh/google-auth-library@9'

function formatearFecha(fecha: string | null | undefined): string | null {
  if (!fecha) return null
  const d = new Date(fecha)
  if (Number.isNaN(d.getTime())) return null
  return d.toLocaleDateString('es-PE', {
    day: '2-digit',
    month: '2-digit',
    year: 'numeric',
  })
}

function construirMensaje(record: Record<string, unknown>, oldRecord?: Record<string, unknown>) {
  const estado = String(record.estado ?? '')
  const estadoAnterior = oldRecord ? String(oldRecord.estado ?? '') : ''
  const fechaDesembolso = formatearFecha(record.fechadesembolso as string | undefined)
  const fechaAnterior = oldRecord
    ? formatearFecha(oldRecord.fechadesembolso as string | undefined)
    : null

  const estadosNotificables = ['aprobada', 'rechazada', 'condicionada', 'desembolsada']
  if (!estadosNotificables.includes(estado)) {
    return null
  }

  if (
    oldRecord &&
    estado === estadoAnterior &&
    fechaDesembolso &&
    fechaDesembolso !== fechaAnterior &&
    (estado === 'aprobada' || estado === 'condicionada')
  ) {
    return {
      title: 'Fecha de desembolso confirmada',
      body: `Tu fecha de desembolso es el ${fechaDesembolso}. Revisa los detalles en la app.`,
    }
  }

  if (oldRecord && estado === estadoAnterior && fechaDesembolso === fechaAnterior) {
    return null
  }

  if (estado === 'aprobada') {
    return {
      title: '¡Tu crédito ha sido aprobado!',
      body: fechaDesembolso
        ? `Tu solicitud fue aprobada. Fecha de desembolso: ${fechaDesembolso}.`
        : 'Tu solicitud fue aprobada. Te informaremos la fecha de desembolso pronto.',
    }
  }

  if (estado === 'rechazada') {
    const motivo = record.motivorechazo
      ? ` Motivo: ${record.motivorechazo}.`
      : ' Revisa la app para más detalles.'
    return {
      title: 'Actualización sobre tu solicitud',
      body: `Tu solicitud no pudo ser aprobada en esta ocasión.${motivo}`,
    }
  }

  if (estado === 'condicionada') {
    const fechaTexto = fechaDesembolso
      ? ` Fecha de desembolso estimada: ${fechaDesembolso}.`
      : ''
    return {
      title: 'Atención requerida',
      body: `Tu solicitud está condicionada. Necesitamos información adicional.${fechaTexto} Ingresa a la app.`,
    }
  }

  if (estado === 'desembolsada') {
    const fechaTexto = fechaDesembolso ? ` Fecha: ${fechaDesembolso}.` : ''
    return {
      title: 'Crédito desembolsado',
      body: `El dinero ya está disponible en tu cuenta.${fechaTexto}`,
    }
  }

  return null
}

serve(async (req) => {
  try {
    const { record, old_record: oldRecord } = await req.json()

    const mensaje = construirMensaje(record, oldRecord)
    if (!mensaje) {
      return new Response('No notification needed', { status: 200 })
    }

    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseServiceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseServiceKey)

    const clienteDni = String(record.dni ?? '')
    if (!clienteDni) {
      return new Response('Missing client DNI', { status: 400 })
    }

    const { data: cliente, error: clienteError } = await supabase
      .from('clientes')
      .select('id')
      .eq('documento', clienteDni)
      .maybeSingle()

    if (clienteError || !cliente) {
      console.log('No client found for DNI:', clienteDni)
      return new Response('No client found', { status: 200 })
    }

    const { data: tokenRow, error: tokenError } = await supabase
      .from('clientes_fcmtokens')
      .select('fcmtoken')
      .eq('clienteid', cliente.id)
      .maybeSingle()

    if (tokenError || !tokenRow?.fcmtoken) {
      console.log('No FCM token found for client:', cliente.id)
      return new Response('No token found', { status: 200 })
    }

    const serviceAccountStr = Deno.env.get('FIREBASE_SERVICE_ACCOUNT')
    if (!serviceAccountStr) {
      throw new Error('FIREBASE_SERVICE_ACCOUNT secret is missing')
    }
    const serviceAccount = JSON.parse(serviceAccountStr)

    const jwtClient = new JWT({
      email: serviceAccount.client_email,
      key: serviceAccount.private_key,
      scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
    })

    const accessTokenObj = await jwtClient.getAccessToken()
    const accessToken = accessTokenObj.token

    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`

    const fcmResponse = await fetch(fcmUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        Authorization: `Bearer ${accessToken}`,
      },
      body: JSON.stringify({
        message: {
          token: tokenRow.fcmtoken,
          notification: {
            title: mensaje.title,
            body: mensaje.body,
          },
          data: {
            solicitudId: String(record.id ?? ''),
            estado: String(record.estado ?? ''),
            fechadesembolso: String(record.fechadesembolso ?? ''),
          },
        },
      }),
    })

    if (!fcmResponse.ok) {
      const errText = await fcmResponse.text()
      console.error('FCM Error:', errText)

      if (errText.includes('UNREGISTERED') || errText.includes('INVALID_ARGUMENT')) {
        await supabase.from('clientes_fcmtokens').delete().eq('fcmtoken', tokenRow.fcmtoken)
      }

      throw new Error(`FCM request failed: ${errText}`)
    }

    return new Response(JSON.stringify({ success: true }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (error) {
    console.error('Error sending notification:', error)
    return new Response(JSON.stringify({ error: (error as Error).message }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
