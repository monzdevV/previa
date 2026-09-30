# Genera assets/images/icon.png (1024x1024, sin transparencia),
# icon_foreground.png (capa adaptativa Android, transparente) y splash.png.
Add-Type -AssemblyName System.Drawing
$bg = [System.Drawing.ColorTranslator]::FromHtml('#0B0B12')
$fg = [System.Drawing.ColorTranslator]::FromHtml('#7C4DFF')
function Nuevo($file, $fondo, $radioRel) {
  $S = 1024
  $bmp = New-Object System.Drawing.Bitmap $S, $S, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  if ($fondo) { $g.Clear($bg) } else { $g.Clear([System.Drawing.Color]::Transparent) }
  $r = $S * $radioRel
  $c = $S / 2
  $brush = New-Object System.Drawing.SolidBrush $fg
  $g.FillEllipse($brush, $c - $r, $c - $r, 2 * $r, 2 * $r)
  # Punto claro interior para dar identidad (una "chispa" de fiesta).
  $w = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(235, 255, 255, 255))
  $r2 = $r * 0.28
  $g.FillEllipse($w, $c - $r2, $c - $r2, 2 * $r2, 2 * $r2)
  $g.Dispose()
  $bmp.Save($file, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()
}
$dir = Join-Path $PSScriptRoot '..\assets\images'
New-Item -ItemType Directory -Force $dir | Out-Null
Nuevo (Join-Path $dir 'icon.png') $true 0.32
# Capa adaptativa: el contenido debe caber en el 66 % central.
Nuevo (Join-Path $dir 'icon_foreground.png') $false 0.22
Nuevo (Join-Path $dir 'splash.png') $false 0.32
