$ErrorActionPreference = 'Stop'

$cwd = Split-Path -Parent $MyInvocation.MyCommand.Path
$srcDir = Join-Path $cwd 'src'
$srcHtmlPath = Join-Path $srcDir 'index.html'
$srcQrcodePath = Join-Path $srcDir 'qrcode-trimmed.min.js'
$srcJsqrPath = Join-Path $srcDir 'jsqr-trimmed.min.js'
$distDir = Join-Path $cwd 'dist'
$distHtmlPath = Join-Path $distDir 'index.html'
$copyFiles = @('apple-touch-icon.png', 'favicon.ico', 'icon192.png', 'icon512.png', 'manifest.json', 'sw.js')

# Minify index.html
npx html-minifier-next $srcHtmlPath -o $distHtmlPath --collapse-whitespace --minify-css --minify-js --minify-svg --remove-comments

# Replace embedded JS to inline scripts
$html = $qrcodeContent = [IO.File]::ReadAllText($distHtmlPath)
$qrcodeContent = [IO.File]::ReadAllText($srcQrcodePath)
$html = $html -creplace '<script [^>]+qrcode.+?</script>', "<script>$qrcodeContent</script>"
$jsqrContent = [IO.File]::ReadAllText($srcJsqrPath)
$html = $html -creplace '<script [^>]+jsqr.+?</script>', "<script>$jsqrContent</script>"

[IO.File]::WriteAllText($distHtmlPath, $html)

# Copy other files
foreach ($file in $copyFiles) {
  $srcPath = Join-Path $srcDir $file
  Copy-Item $srcPath $distDir -Force
}

Write-Host 'Done.'
