// Logica pura del minijuego: nada de red ni de Deno, para poder probarla
// con el ejecutor de pruebas de Node sin levantar Supabase.

/** El hueco donde la base de datos pone el nombre de a quien te toca. */
export const HUECO = "{persona}";

/**
 * Retos de reserva. Salen cuando no hay clave de la IA, cuando tarda
 * demasiado o cuando lo que devuelve no pasa la validacion. El juego tiene
 * que funcionar igual un sabado a las tres sin conexion con la IA.
 */
export const PLANTILLAS: readonly string[] = [
  `Busca a ${HUECO} y haceos una foto como si fuerais famosos en un photocall.`,
  `Encuentra a ${HUECO} y haceos un selfie poniendo la cara más seria del local.`,
  `Busca a ${HUECO} y haceos una foto imitando la portada de un disco.`,
  `Encuentra a ${HUECO}, averigua su canción favorita de esta noche y haceos una foto.`,
  `Busca a ${HUECO} y haceos una foto chocando los cinco a cámara.`,
  `Encuentra a ${HUECO} y haceos una foto como si acabarais de ganar un premio.`,
  `Busca a ${HUECO} y haceos una foto señalando a la cámara a la vez.`,
  `Encuentra a ${HUECO} y haceos una foto de espaldas, como en un videoclip.`,
];

export function plantillaAlAzar(azar: () => number = Math.random): string {
  return PLANTILLAS[Math.floor(azar() * PLANTILLAS.length) % PLANTILLAS.length];
}

/**
 * Lo que vuelve de la IA es texto libre, asi que se trata como no fiable:
 * se limpia y, si algo no cuadra, se descarta en vez de arreglarlo.
 * Devuelve null cuando no sirve.
 */
export function validarPlantilla(bruto: string): string | null {
  const texto = bruto
    .trim()
    // Las comillas envolventes son un tic habitual del modelo.
    .replace(/^["'«“]+|["'»”]+$/g, "")
    .trim();

  if (texto.length < 20 || texto.length > 200) return null;
  if (texto.includes("\n")) return null;
  if (texto.split(HUECO).length - 1 !== 1) return null;
  // Ni enlaces ni menciones: el reto es para leerlo, no para mandar a nadie
  // a ningun sitio.
  if (/https?:\/\/|www\.|@\w/i.test(texto)) return null;
  // Tiene que acabar en foto: es la prueba de que se ha cumplido.
  if (!/foto|selfie/i.test(texto)) return null;
  return texto;
}

/** Codigos que lanza la base de datos y como se devuelven a la app. */
const ESTADOS: Record<string, number> = {
  NO_EXISTE_LOCAL: 404,
  NO_VAS: 403,
  SIN_UBICACION: 400,
  NO_ESTAS_AQUI: 403,
  YA_TIENES_RETO: 409,
  LIMITE_NOCHE: 429,
  NO_HAY_NADIE: 409,
  NO_EXISTE_RETO: 404,
  PLANTILLA_INVALIDA: 500,
};

/**
 * Traduce el mensaje de un error de Postgres a un codigo conocido. Lo que
 * no se reconoce se queda en ERROR y no se reenvia tal cual: el texto de un
 * fallo interno no le sirve a nadie en el movil y puede contar demasiado.
 */
export function codigoDeError(mensaje: string | undefined): {
  codigo: string;
  estado: number;
} {
  const codigo = (mensaje ?? "").trim();
  if (codigo in ESTADOS) return { codigo, estado: ESTADOS[codigo] };
  return { codigo: "ERROR", estado: 500 };
}

/** Comprueba el cuerpo de la peticion sin fiarse de nada. */
export function leerPeticion(cuerpo: unknown): {
  localId: string;
  lat: number | null;
  lng: number | null;
} | null {
  if (typeof cuerpo !== "object" || cuerpo === null) return null;
  const { local_id, lat, lng } = cuerpo as Record<string, unknown>;

  const uuid =
    /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
  if (typeof local_id !== "string" || !uuid.test(local_id)) return null;

  const ausente = (v: unknown) => v === undefined || v === null;
  const valida = (v: unknown, max: number): v is number =>
    typeof v === "number" && Number.isFinite(v) && Math.abs(v) <= max;

  if (ausente(lat) && ausente(lng)) {
    return { localId: local_id, lat: null, lng: null };
  }
  // Las dos y bien formadas, o ninguna. Una coordenada rota no se convierte
  // en "sin posicion" en silencio: se rechaza la peticion entera.
  if (!valida(lat, 90) || !valida(lng, 180)) return null;
  return { localId: local_id, lat, lng };
}

const UUID = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

/** Peticion de quitar la foto de un reto en el que sales. */
export function leerQuitar(cuerpo: unknown): { retoId: string } | null {
  if (typeof cuerpo !== "object" || cuerpo === null) return null;
  const { accion, reto_id } = cuerpo as Record<string, unknown>;
  if (accion !== "quitar") return null;
  if (typeof reto_id !== "string" || !UUID.test(reto_id)) return null;
  return { retoId: reto_id };
}

/**
 * La ruta dentro del cubo a partir de la URL publica. Devuelve null si la
 * URL no es del cubo de publicaciones: nunca se borra algo que no se sabe
 * de donde viene.
 */
export function rutaEnElCubo(url: string): string | null {
  const marca = "/storage/v1/object/public/publicaciones/";
  const donde = url.indexOf(marca);
  if (donde < 0) return null;
  const ruta = decodeURIComponent(url.slice(donde + marca.length).split("?")[0]);
  if (!ruta || ruta.includes("..")) return null;
  return ruta;
}

/**
 * El nombre del local va dentro del mensaje a la IA y cualquiera puede
 * proponer un local. Se deja en una linea corta y sin comillas para que no
 * pueda colarse como instrucciones.
 */
export function limpiarNombreDeLocal(nombre: string): string {
  return nombre
    .replace(/[\r\n"`<>{}]/g, " ")
    .replace(/\s+/g, " ")
    .trim()
    .slice(0, 60);
}
