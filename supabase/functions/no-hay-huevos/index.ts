// Funcion de borde del minijuego "No hay 🥚".
//
// Por que existe en vez de llamar a la base de datos desde la app: la clave
// de la IA no puede vivir en el movil, y el reparto de retos necesita la
// clave de servicio para decidir a quien le toca sin que el cliente pueda
// elegirlo. Aqui se verifica la sesion, se pide el texto a Claude y se
// guarda el reto; lo que decide las reglas sigue estando en Postgres.
//
// Secretos que usa (Supabase inyecta los dos primeros):
//   SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY
//   ANTHROPIC_API_KEY  opcional; sin ella salen retos de la lista de reserva

import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "npm:@supabase/supabase-js@2";
import Anthropic from "npm:@anthropic-ai/sdk@0.128.0";

import {
  codigoDeError,
  HUECO,
  leerPeticion,
  plantillaAlAzar,
  validarPlantilla,
} from "./reto.ts";

const url = Deno.env.get("SUPABASE_URL")!;
const claveServicio = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const claveIa = Deno.env.get("ANTHROPIC_API_KEY");

const servicio = createClient(url, claveServicio, {
  auth: { persistSession: false, autoRefreshToken: false },
});

// Los reintentos del SDK multiplicarian la espera: con la gente delante de
// la pantalla es mejor caer a la plantilla que hacerles esperar 30 segundos.
const ia = claveIa
  ? new Anthropic({ apiKey: claveIa, maxRetries: 0, timeout: 12_000 })
  : null;

const cabeceras = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function responder(estado: number, cuerpo: unknown): Response {
  return new Response(JSON.stringify(cuerpo), {
    status: estado,
    headers: { ...cabeceras, "Content-Type": "application/json" },
  });
}

// El sistema fija el tono y los limites; no cambia entre peticiones.
const INSTRUCCIONES = `Escribes retos para "No hay 🥚", un minijuego dentro de una app para salir de fiesta en España.
El jugador está en un local y tiene que encontrar a otra persona que está allí y hacerse una foto con ella.

Devuelve SOLO el texto del reto, en una línea, sin comillas ni explicaciones.
- Castellano de España, tono de colega, con gracia. Máximo 150 caracteres.
- Escribe exactamente una vez el hueco ${HUECO} donde va el nombre de la persona. No inventes nombres.
- El reto termina siempre con hacerse una foto o un selfie juntos.
- Nada de alcohol ni de beber, nada sexual ni de ligar, sin tocar a nadie más allá de un choque de manos, sin humillar, sin nada peligroso ni ilegal, sin molestar al personal ni a desconocidos.
- Varía: poses, imitaciones, preguntas curiosas antes de la foto, fotos temáticas. Como mucho un emoji.`;

async function pedirPlantilla(nombreLocal: string): Promise<string | null> {
  if (!ia) return null;
  try {
    const respuesta = await ia.beta.messages.create({
      model: "claude-opus-5",
      max_tokens: 2000,
      // Un reto de una linea no necesita pensar mucho; esfuerzo bajo es lo
      // que lo deja en un par de segundos.
      output_config: { effort: "low" },
      // Si los filtros de seguridad rechazan la peticion, el servidor la
      // repite con el modelo que toque en vez de devolver un rechazo.
      betas: ["server-side-fallback-2026-07-01"],
      fallbacks: "default",
      system: INSTRUCCIONES,
      messages: [
        {
          role: "user",
          content: `Local: ${nombreLocal}. Hora: ${
            new Date().toLocaleTimeString("es-ES", {
              timeZone: "Europe/Madrid",
              hour: "2-digit",
              minute: "2-digit",
            })
          }. Escribe un reto nuevo.`,
        },
      ],
    });

    if (respuesta.stop_reason === "refusal") return null;
    const texto = respuesta.content
      .map((bloque) => (bloque.type === "text" ? bloque.text : ""))
      .join("");
    return validarPlantilla(texto);
  } catch (error) {
    // Cualquier fallo de la IA acaba en plantilla; se registra el tipo para
    // poder verlo en los registros de la funcion sin volcar la respuesta.
    console.error(JSON.stringify({
      evento: "ia_fallida",
      tipo: error instanceof Anthropic.APIError ? error.status : "red",
    }));
    return null;
  }
}

Deno.serve(async (peticion) => {
  if (peticion.method === "OPTIONS") return new Response("ok", { headers: cabeceras });
  if (peticion.method !== "POST") return responder(405, { codigo: "METODO" });

  // Se verifica aqui aunque el despliegue ya exija JWT: la clave de servicio
  // salta las politicas y el jugador tiene que salir de la sesion, nunca del
  // cuerpo de la peticion.
  const token = peticion.headers.get("Authorization")?.replace(/^Bearer\s+/i, "");
  if (!token) return responder(401, { codigo: "SIN_SESION" });

  const { data: usuario, error: errorSesion } = await servicio.auth.getUser(token);
  if (errorSesion || !usuario.user) return responder(401, { codigo: "SIN_SESION" });
  const jugador = usuario.user.id;

  let datos;
  try {
    datos = leerPeticion(await peticion.json());
  } catch {
    datos = null;
  }
  if (!datos) return responder(400, { codigo: "PETICION_INVALIDA" });

  const inicio = Date.now();

  // Paso 1: comprobar antes de gastar una llamada a la IA.
  const comprobacion = await servicio.rpc("comprobar_reto", {
    jugador,
    local: datos.localId,
    lat: datos.lat,
    lng: datos.lng,
  });
  if (comprobacion.error) {
    const { codigo, estado } = codigoDeError(comprobacion.error.message);
    if (codigo === "ERROR") console.error(JSON.stringify({ evento: "comprobar", error: comprobacion.error.message }));
    return responder(estado, { codigo });
  }

  // Paso 2: el texto. A la IA solo le llega el nombre del local.
  const deIa = await pedirPlantilla(comprobacion.data as string);
  const plantilla = deIa ?? plantillaAlAzar();

  // Paso 3: la base de datos elige a quien te toca y lo guarda.
  const creado = await servicio.rpc("crear_reto", {
    jugador,
    local: datos.localId,
    plantilla,
    origen: deIa ? "ia" : "plantilla",
  });
  if (creado.error) {
    const { codigo, estado } = codigoDeError(creado.error.message);
    if (codigo === "ERROR") console.error(JSON.stringify({ evento: "crear", error: creado.error.message }));
    return responder(estado, { codigo });
  }

  console.log(JSON.stringify({
    evento: "reto_creado",
    origen: deIa ? "ia" : "plantilla",
    ms: Date.now() - inicio,
  }));
  return responder(201, { id: creado.data });
});
