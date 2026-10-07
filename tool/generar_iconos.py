"""Genera los iconos de Previa para Android, iOS y web desde una sola receta.

Se deja en el repositorio para que cambiar el icono sea cambiar dos colores
aqui y volver a ejecutarlo, no rehacer a mano veinte PNG:

    python tool/generar_iconos.py

Necesita Pillow y la fuente Segoe UI Black de Windows.
"""

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

AMARILLO = (255, 229, 0)
NARANJA = (255, 159, 28)
NEGRO = (0, 0, 0)
FUENTE = "C:/Windows/Fonts/seguibl.ttf"
RAIZ = Path(__file__).resolve().parent.parent


def degradado(lado: int) -> Image.Image:
    """El mismo degradado diagonal que la marca del feed."""
    base = Image.new("RGB", (lado, lado))
    pixeles = base.load()
    for y in range(lado):
        for x in range(lado):
            t = (x + y) / (2 * (lado - 1))
            pixeles[x, y] = tuple(
                round(a + (b - a) * t) for a, b in zip(AMARILLO, NARANJA)
            )
    return base


def icono(lado: int, *, margen: float, redondeo: float, fondo_negro: bool) -> Image.Image:
    """Una P negra sobre el degradado.

    `margen` es la parte del lienzo que queda fuera del cuadrado de color;
    los iconos adaptables y "maskable" necesitan aire porque el sistema los
    recorta en circulo.
    """
    lienzo = Image.new("RGBA", (lado, lado), NEGRO + (255,) if fondo_negro else (0, 0, 0, 0))
    interior = round(lado * (1 - 2 * margen))
    color = degradado(interior)

    mascara = Image.new("L", (interior, interior), 0)
    ImageDraw.Draw(mascara).rounded_rectangle(
        (0, 0, interior - 1, interior - 1), radius=round(interior * redondeo), fill=255
    )

    dibujo = ImageDraw.Draw(color)
    fuente = ImageFont.truetype(FUENTE, round(interior * 0.72))
    caja = dibujo.textbbox((0, 0), "P", font=fuente)
    ancho, alto = caja[2] - caja[0], caja[3] - caja[1]
    dibujo.text(
        ((interior - ancho) / 2 - caja[0], (interior - alto) / 2 - caja[1]),
        "P",
        font=fuente,
        fill=NEGRO,
    )

    desplazamiento = round(lado * margen)
    lienzo.paste(color, (desplazamiento, desplazamiento), mascara)
    return lienzo


def guardar(imagen: Image.Image, ruta: str, *, sin_alfa: bool = False) -> None:
    destino = RAIZ / ruta
    destino.parent.mkdir(parents=True, exist_ok=True)
    # La App Store rechaza el icono de 1024 si lleva canal alfa.
    (imagen.convert("RGB") if sin_alfa else imagen).save(destino)


def main() -> None:
    # Web: normal, "maskable" con margen de seguridad y favicon.
    guardar(icono(192, margen=0, redondeo=0.22, fondo_negro=True), "web/icons/Icon-192.png")
    guardar(icono(512, margen=0, redondeo=0.22, fondo_negro=True), "web/icons/Icon-512.png")
    guardar(icono(192, margen=0.14, redondeo=0.22, fondo_negro=True), "web/icons/Icon-maskable-192.png")
    guardar(icono(512, margen=0.14, redondeo=0.22, fondo_negro=True), "web/icons/Icon-maskable-512.png")
    guardar(icono(64, margen=0, redondeo=0.22, fondo_negro=False), "web/favicon.png")

    # Android: el sistema recorta con su propia forma, asi que va a sangre
    # sobre negro y con la P centrada.
    for carpeta, lado in {
        "mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192,
    }.items():
        guardar(
            icono(lado, margen=0, redondeo=0, fondo_negro=True),
            f"android/app/src/main/res/mipmap-{carpeta}/ic_launcher.png",
        )

    # iOS: iOS pone las esquinas, el PNG va cuadrado y sin transparencia.
    for nombre in (RAIZ / "ios/Runner/Assets.xcassets/AppIcon.appiconset").glob("Icon-App-*.png"):
        medida, escala = nombre.stem.removeprefix("Icon-App-").split("@")
        lado = round(float(medida.split("x")[0]) * int(escala.removesuffix("x")))
        guardar(
            icono(lado, margen=0, redondeo=0, fondo_negro=True),
            str(nombre.relative_to(RAIZ)),
            sin_alfa=True,
        )


if __name__ == "__main__":
    main()
