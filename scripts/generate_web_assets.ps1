Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Drawing.Drawing2D

$ErrorActionPreference = "Stop"

Write-Host "==> Initializing Web Assets Generator for GozVision..."

$srcLensPath = Resolve-Path "apps/website/assets/gozvision_lens_clean_cut.png"
$srcLogoPath = Resolve-Path "apps/website/assets/gozvision_logo.png"
$srcBgPath   = Resolve-Path "apps/website/assets/hero_optics_bg.jpg"

$srcLens = [System.Drawing.Image]::FromFile($srcLensPath)
$srcLogo = [System.Drawing.Image]::FromFile($srcLogoPath)
$srcBg   = [System.Drawing.Image]::FromFile($srcBgPath)

function Set-HighQualityGraphics($g) {
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
}

# -------------------------------------------------------------
# 1. Generate Favicons and App Icons
# -------------------------------------------------------------
function Create-AppIcon([int]$size, [bool]$hasBackground, [string]$outPath) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    Set-HighQualityGraphics $g

    if ($hasBackground) {
        $bgBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 8, 9, 12))
        $g.FillRectangle($bgBrush, 0, 0, $size, $size)
        $bgBrush.Dispose()

        $rimPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(60, 56, 189, 248)), 1.5
        $g.DrawRectangle($rimPen, 1, 1, ($size - 2), ($size - 2))
        $rimPen.Dispose()

        $pad = [int]($size * 0.10)
        $drawW = $size - ($pad * 2)
        $drawH = $size - ($pad * 2)

        $aspect = $srcLens.Width / $srcLens.Height
        if ($aspect -gt 1) {
            $destW = $drawW
            $destH = [int]($drawW / $aspect)
            $destX = $pad
            $destY = $pad + [int](($drawH - $destH) / 2)
        } else {
            $destH = $drawH
            $destW = [int]($drawH * $aspect)
            $destY = $pad
            $destX = $pad + [int](($drawW - $destW) / 2)
        }
        $g.DrawImage($srcLens, $destX, $destY, $destW, $destH)
    } else {
        $g.Clear([System.Drawing.Color]::Transparent)
        $pad = [int]($size * 0.04)
        $drawW = $size - ($pad * 2)
        $drawH = $size - ($pad * 2)
        $aspect = $srcLens.Width / $srcLens.Height
        if ($aspect -gt 1) {
            $destW = $drawW
            $destH = [int]($drawW / $aspect)
            $destX = $pad
            $destY = $pad + [int](($drawH - $destH) / 2)
        } else {
            $destH = $drawH
            $destW = [int]($drawH * $aspect)
            $destY = $pad
            $destX = $pad + [int](($drawW - $destW) / 2)
        }
        $g.DrawImage($srcLens, $destX, $destY, $destW, $destH)
    }

    $bmp.Save($outPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
    Write-Host "Created: $outPath ($size x $size)"
}

@("apps/website/icons", "apps/clinic/web/icons", "apps/patient/web/icons") | ForEach-Object {
    if (-not (Test-Path $_)) { New-Item -ItemType Directory -Force -Path $_ | Out-Null }
}

Create-AppIcon 16  $false "apps/website/favicon-16x16.png"
Create-AppIcon 32  $false "apps/website/favicon-32x32.png"
Create-AppIcon 32  $false "apps/website/favicon.png"
Create-AppIcon 180 $true  "apps/website/apple-touch-icon.png"
Create-AppIcon 192 $true  "apps/website/icons/Icon-192.png"
Create-AppIcon 512 $true  "apps/website/icons/Icon-512.png"
Create-AppIcon 192 $true  "apps/website/icons/Icon-maskable-192.png"
Create-AppIcon 512 $true  "apps/website/icons/Icon-maskable-512.png"

Copy-Item "apps/website/favicon.png" "apps/clinic/web/favicon.png" -Force
Copy-Item "apps/website/favicon-32x32.png" "apps/clinic/web/favicon-32x32.png" -Force
Copy-Item "apps/website/favicon-16x16.png" "apps/clinic/web/favicon-16x16.png" -Force
Copy-Item "apps/website/apple-touch-icon.png" "apps/clinic/web/apple-touch-icon.png" -Force
Copy-Item "apps/website/icons/*" "apps/clinic/web/icons/" -Force

Copy-Item "apps/website/favicon.png" "apps/patient/web/favicon.png" -Force
Copy-Item "apps/website/favicon-32x32.png" "apps/patient/web/favicon-32x32.png" -Force
Copy-Item "apps/website/favicon-16x16.png" "apps/patient/web/favicon-16x16.png" -Force
Copy-Item "apps/website/apple-touch-icon.png" "apps/patient/web/apple-touch-icon.png" -Force
Copy-Item "apps/website/icons/*" "apps/patient/web/icons/" -Force

# -------------------------------------------------------------
# 2. Generate 1200x630 OpenGraph (OG) Image
# -------------------------------------------------------------
Write-Host "==> Generating 1200x630 OpenGraph preview card..."

$ogW = 1200
$ogH = 630
$ogBmp = New-Object System.Drawing.Bitmap $ogW, $ogH, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$g = [System.Drawing.Graphics]::FromImage($ogBmp)
Set-HighQualityGraphics $g

$bgBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 8, 9, 12))
$g.FillRectangle($bgBrush, 0, 0, $ogW, $ogH)
$bgBrush.Dispose()

$bgDestW = 900
$bgDestH = $ogH
$bgDestX = $ogW - $bgDestW
$g.DrawImage($srcBg, $bgDestX, 0, $bgDestW, $bgDestH)

$leftGradientBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush (
    (New-Object System.Drawing.Point 0, 0),
    (New-Object System.Drawing.Point 950, 0),
    ([System.Drawing.Color]::FromArgb(255, 8, 9, 12)),
    ([System.Drawing.Color]::FromArgb(0, 8, 9, 12))
)
$g.FillRectangle($leftGradientBrush, 0, 0, 950, $ogH)
$leftGradientBrush.Dispose()

$vignetteBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush (
    (New-Object System.Drawing.Point 0, 0),
    (New-Object System.Drawing.Point 0, 200),
    ([System.Drawing.Color]::FromArgb(180, 8, 9, 12)),
    ([System.Drawing.Color]::FromArgb(0, 8, 9, 12))
)
$g.FillRectangle($vignetteBrush, 0, 0, $ogW, 200)
$vignetteBrush.Dispose()

$bottomVignette = New-Object System.Drawing.Drawing2D.LinearGradientBrush (
    (New-Object System.Drawing.Point 0, 480),
    (New-Object System.Drawing.Point 0, $ogH),
    ([System.Drawing.Color]::FromArgb(0, 8, 9, 12)),
    ([System.Drawing.Color]::FromArgb(240, 8, 9, 12))
)
$g.FillRectangle($bottomVignette, 0, 480, $ogW, 150)
$bottomVignette.Dispose()

$outerBorderPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(50, 56, 189, 248)), 1.5
$g.DrawRectangle($outerBorderPen, 0, 0, ($ogW - 1), ($ogH - 1))
$outerBorderPen.Dispose()

$lensW = 460
$lensH = [int]($lensW * ($srcLens.Height / $srcLens.Width))
$lensX = 690
$lensY = [int](($ogH - $lensH) / 2)

$glowSize = 520
$glowX = $lensX + [int](($lensW - $glowSize) / 2)
$glowY = $lensY + [int](($lensH - $glowSize) / 2)
$glowPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$glowPath.AddEllipse($glowX, $glowY, $glowSize, $glowSize)
$pbg = New-Object System.Drawing.Drawing2D.PathGradientBrush $glowPath
$pbg.CenterColor = [System.Drawing.Color]::FromArgb(70, 56, 189, 248)
$pbg.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 8, 9, 12))
$g.FillPath($pbg, $glowPath)
$pbg.Dispose()
$glowPath.Dispose()

$g.DrawImage($srcLens, $lensX, $lensY, $lensW, $lensH)

$fontFamilySans = "Segoe UI"
$fontFamilyMono = "Consolas"

# 1. Category Eyebrow Pill
$pillX = 70
$pillY = 75
$pillW = 475
$pillH = 34
$pillBg = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(35, 56, 189, 248))
$pillBorder = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(90, 56, 189, 248)), 1
$g.FillRectangle($pillBg, $pillX, $pillY, $pillW, $pillH)
$g.DrawRectangle($pillBorder, $pillX, $pillY, $pillW, $pillH)
$pillBg.Dispose()
$pillBorder.Dispose()

$eyebrowFont = New-Object System.Drawing.Font $fontFamilyMono, 10, [System.Drawing.FontStyle]::Bold
$eyebrowBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 56, 189, 248))
$g.DrawString("CLINICAL INTELLIGENCE - LOW-VISION COPILOT", $eyebrowFont, $eyebrowBrush, ($pillX + 16), ($pillY + 8))
$eyebrowFont.Dispose()
$eyebrowBrush.Dispose()

# 2. Main Brand Title: GozVision
$titleFont = New-Object System.Drawing.Font $fontFamilySans, 54, [System.Drawing.FontStyle]::Bold
$titleBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 248, 250, 252))
$g.DrawString("GozVision", $titleFont, $titleBrush, 68, 125)
$titleFont.Dispose()
$titleBrush.Dispose()

# 3. Main Tagline
$taglineFont = New-Object System.Drawing.Font $fontFamilySans, 21, [System.Drawing.FontStyle]::Bold
$taglineBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 56, 189, 248))
$g.DrawString("The Practice Operating & Patient Copilot Platform", $taglineFont, $taglineBrush, 72, 222)
$taglineFont.Dispose()
$taglineBrush.Dispose()

# 4. Description Paragraph
$descFont = New-Object System.Drawing.Font $fontFamilySans, 15, [System.Drawing.FontStyle]::Regular
$descBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(220, 148, 163, 184))
$descText = "Ambient Scribe charting, 90-day device abandonment radar, and Goz - the voice-first multimodal AI copilot patients take home."
$descRect = New-Object System.Drawing.RectangleF 72, 275, 570, 90
$g.DrawString($descText, $descFont, $descBrush, $descRect)
$descFont.Dispose()
$descBrush.Dispose()

# 5. Feature Badges
function Draw-Badge([float]$bx, [float]$by, [float]$bw, [float]$bh, [string]$label) {
    $bBg = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(200, 19, 23, 34))
    $bBorder = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(60, 255, 255, 255)), 1
    $g.FillRectangle($bBg, $bx, $by, $bw, $bh)
    $g.DrawRectangle($bBorder, $bx, $by, $bw, $bh)
    $bBg.Dispose()
    $bBorder.Dispose()

    $bFont = New-Object System.Drawing.Font $fontFamilySans, 11, [System.Drawing.FontStyle]::Bold
    $dotBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 16, 185, 129))
    $g.FillEllipse($dotBrush, ($bx + 12), ($by + 11), 8, 8)
    $dotBrush.Dispose()

    $txtBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(240, 241, 245, 249))
    $g.DrawString($label, $bFont, $txtBrush, ($bx + 28), ($by + 7))
    $bFont.Dispose()
    $txtBrush.Dispose()
}

Draw-Badge 72  385 270 32 "Ambient Scribe (OLD CARTS)"
Draw-Badge 354 385 260 32 "90-Day Abandonment Radar"
Draw-Badge 72  427 270 32 "SMART on FHIR R4 EHR Hub"
Draw-Badge 354 427 260 32 "Bachs Instant QR POS & Rx"

# 6. Bottom Domain / Accreditation Bar
$footerLinePen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(40, 255, 255, 255)), 1
$g.DrawLine($footerLinePen, 72, 510, 600, 510)
$footerLinePen.Dispose()

$footFont = New-Object System.Drawing.Font $fontFamilyMono, 12, [System.Drawing.FontStyle]::Regular
$footBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(200, 100, 116, 139))
$g.DrawString("gozvision.app  |  Enterprise Eye Care Intelligence  |  HIPAA Compliant", $footFont, $footBrush, 72, 525)
$footFont.Dispose()
$footBrush.Dispose()

$ogPaths = @(
    "apps/website/assets/og_image.png",
    "apps/website/og_image.png",
    "apps/clinic/web/og_image.png",
    "apps/patient/web/og_image.png"
)

foreach ($p in $ogPaths) {
    $dir = Split-Path $p
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
    $ogBmp.Save($p, [System.Drawing.Imaging.ImageFormat]::Png)
    Write-Host "Created OG Image: $p"
}

$g.Dispose()
$ogBmp.Dispose()
$srcLens.Dispose()
$srcLogo.Dispose()
$srcBg.Dispose()

Write-Host "==> Assets generated successfully!"
