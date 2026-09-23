// Se ejecuta con: node --test supabase/functions/no-hay-huevos/reto.test.ts
// Node 23 o superior quita los tipos solo; no hace falta Deno ni compilar.

import { test } from "node:test";
import assert from "node:assert/strict";

import {
  codigoDeError,
  leerPeticion,
  PLANTILLAS,
  plantillaAlAzar,
  validarPlantilla,
} from "./reto.ts";

test("todas las plantillas de reserva pasan su propia validacion", () => {
  for (const plantilla of PLANTILLAS) {
    assert.equal(validarPlantilla(plantilla), plantilla, plantilla);
  }
});

test("plantillaAlAzar no se sale de la lista ni con el extremo del azar", () => {
  assert.equal(plantillaAlAzar(() => 0), PLANTILLAS[0]);
  assert.equal(plantillaAlAzar(() => 0.9999999), PLANTILLAS.at(-1));
});

test("quita las comillas envolventes del modelo", () => {
  assert.equal(
    validarPlantilla('"Busca a {persona} y haceos una foto de pelicula."'),
    "Busca a {persona} y haceos una foto de pelicula.",
  );
});

test("descarta lo que no sirve", () => {
  const malos = [
    "Busca a Laura y haceos una foto juntos ahora mismo.", // sin hueco
    "Busca a {persona} y a {persona} y haceos una foto.", // hueco doble
    "Busca a {persona} y bailad una cancion entera.", // sin foto
    "Busca a {persona} y haceos una foto\nen la barra.", // dos lineas
    "Busca a {persona}, sigue a @alguien y haceos una foto.", // mencion
    "Busca a {persona} y entra en https://x.test para la foto.", // enlace
    "{persona} foto", // corto
    `Busca a {persona} y haceos una foto ${"muy ".repeat(60)}larga.`, // largo
  ];
  for (const malo of malos) assert.equal(validarPlantilla(malo), null, malo);
});

test("traduce los codigos de la base de datos y esconde el resto", () => {
  assert.deepEqual(codigoDeError("NO_VAS"), { codigo: "NO_VAS", estado: 403 });
  assert.deepEqual(codigoDeError("LIMITE_NOCHE"), { codigo: "LIMITE_NOCHE", estado: 429 });
  assert.deepEqual(
    codigoDeError('relation "x" does not exist'),
    { codigo: "ERROR", estado: 500 },
  );
  assert.deepEqual(codigoDeError(undefined), { codigo: "ERROR", estado: 500 });
});

test("lee una peticion valida con y sin posicion", () => {
  const id = "0f8fad5b-d9cb-469f-a165-70867728950e";
  assert.deepEqual(leerPeticion({ local_id: id }), { localId: id, lat: null, lng: null });
  assert.deepEqual(
    leerPeticion({ local_id: id, lat: 41.65, lng: -0.88 }),
    { localId: id, lat: 41.65, lng: -0.88 },
  );
});

test("rechaza peticiones mal formadas", () => {
  const id = "0f8fad5b-d9cb-469f-a165-70867728950e";
  const malas: unknown[] = [
    null,
    "texto",
    {},
    { local_id: "no-es-un-uuid" },
    { local_id: "1; drop table venues" },
    { local_id: id, lat: 41.65 }, // media coordenada
    { local_id: id, lat: 200, lng: 0 }, // fuera de rango
    { local_id: id, lat: "41", lng: "-0.8" }, // texto en vez de numero
    { local_id: id, lat: Number.NaN, lng: 0 },
  ];
  for (const mala of malas) assert.equal(leerPeticion(mala), null, JSON.stringify(mala));
});
