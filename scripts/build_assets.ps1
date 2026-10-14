Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"

Write-Host "==> GozVision Unified Web Assets Builder"

# Sources: Use the navbar/footer lens
$srcLensPath = Resolve-Path "apps/website/assets/gozvision_lens_clean_cut.png"
$srcBgPath   = Resolve-Path "apps/website/assets/hero_optics_bg.jpg"

$srcLens = [System.Drawing.Image]::FromFile($srcLensPath)
$srcBg   = [System.Drawing.Image]::FromFile($srcBgPath)

function Set-HighQualityGraphics($g) {
    $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.PixelOffsetMode = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.TextRenderingHint = [System.Drawing.Text.TextRenderingHint]::ClearTypeGridFit
    $g.CompositingQuality = [System.Drawing.Drawing2D.CompositingQuality]::HighQuality
}

$tempDir = "scripts/temp_icons"
if (-not (Test-Path $tempDir)) { New-Item -ItemType Directory -Force -Path $tempDir | Out-Null }

function Export-Icon([int]$size, [bool]$hasBg, [string]$destPath, [float]$paddingRatio = 0.0) {
    $bmp = New-Object System.Drawing.Bitmap $size, $size, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    Set-HighQualityGraphics $g

    if ($hasBg) {
        $bgBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 8, 9, 12))
        $g.FillRectangle($bgBrush, 0, 0, $size, $size)
        $bgBrush.Dispose()

        $rimPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(60, 56, 189, 248)), 1.5
        $g.DrawRectangle($rimPen, 1, 1, ($size - 2), ($size - 2))
        $rimPen.Dispose()
    } else {
        $g.Clear([System.Drawing.Color]::Transparent)
    }

    $pad = [int]($size * $paddingRatio)
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
    $bmp.Save($destPath, [System.Drawing.Imaging.ImageFormat]::Png)
    $g.Dispose()
    $bmp.Dispose()
    Write-Host "Generated: $destPath ($size x $size, bg=$hasBg)"
}

Export-Icon 16  $false "$tempDir/icon_16.png" 0.0
Export-Icon 32  $false "$tempDir/icon_32.png" 0.0
Export-Icon 48  $false "$tempDir/icon_48.png" 0.0
Export-Icon 64  $false "$tempDir/icon_64.png" 0.0
Export-Icon 180 $true  "$tempDir/apple_touch_icon.png" 0.10
Export-Icon 192 $true  "$tempDir/icon_192.png" 0.08
Export-Icon 512 $true  "$tempDir/icon_512.png" 0.08
Export-Icon 192 $true  "$tempDir/icon_maskable_192.png" 0.20
Export-Icon 512 $true  "$tempDir/icon_maskable_512.png" 0.20

Write-Host "==> Generating 1200x630 OpenGraph Social Share Card..."
$ogW = 1200
$ogH = 630
$ogBmp = New-Object System.Drawing.Bitmap $ogW, $ogH, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$ogG = [System.Drawing.Graphics]::FromImage($ogBmp)
Set-HighQualityGraphics $ogG

$bgBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 8, 9, 12))
$ogG.FillRectangle($bgBrush, 0, 0, $ogW, $ogH)
$bgBrush.Dispose()

$bgDestW = 880
$bgDestH = $ogH
$bgDestX = $ogW - $bgDestW
$ogG.DrawImage($srcBg, $bgDestX, 0, $bgDestW, $bgDestH)

$leftGradientBrush = New-Object System.Drawing.Drawing2D.LinearGradientBrush (
    (New-Object System.Drawing.Point 0, 0),
    (New-Object System.Drawing.Point 920, 0),
    ([System.Drawing.Color]::FromArgb(255, 8, 9, 12)),
    ([System.Drawing.Color]::FromArgb(0, 8, 9, 12))
)
$ogG.FillRectangle($leftGradientBrush, 0, 0, 920, $ogH)
$leftGradientBrush.Dispose()

$vignetteTop = New-Object System.Drawing.Drawing2D.LinearGradientBrush (
    (New-Object System.Drawing.Point 0, 0),
    (New-Object System.Drawing.Point 0, 180),
    ([System.Drawing.Color]::FromArgb(190, 8, 9, 12)),
    ([System.Drawing.Color]::FromArgb(0, 8, 9, 12))
)
$ogG.FillRectangle($vignetteTop, 0, 0, $ogW, 180)
$vignetteTop.Dispose()

$vignetteBottom = New-Object System.Drawing.Drawing2D.LinearGradientBrush (
    (New-Object System.Drawing.Point 0, 470),
    (New-Object System.Drawing.Point 0, $ogH),
    ([System.Drawing.Color]::FromArgb(0, 8, 9, 12)),
    ([System.Drawing.Color]::FromArgb(240, 8, 9, 12))
)
$ogG.FillRectangle($vignetteBottom, 0, 470, $ogW, 160)
$vignetteBottom.Dispose()

$outerBorderPen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(55, 56, 189, 248)), 1.5
$ogG.DrawRectangle($outerBorderPen, 0, 0, ($ogW - 1), ($ogH - 1))
$outerBorderPen.Dispose()

$lensW = 440
$lensH = [int]($lensW * ($srcLens.Height / $srcLens.Width))
$lensX = 710
$lensY = [int](($ogH - $lensH) / 2)

$glowSize = 520
$glowX = $lensX + [int](($lensW - $glowSize) / 2)
$glowY = $lensY + [int](($lensH - $glowSize) / 2)
$glowPath = New-Object System.Drawing.Drawing2D.GraphicsPath
$glowPath.AddEllipse($glowX, $glowY, $glowSize, $glowSize)
$pbg = New-Object System.Drawing.Drawing2D.PathGradientBrush $glowPath
$pbg.CenterColor = [System.Drawing.Color]::FromArgb(75, 56, 189, 248)
$pbg.SurroundColors = @([System.Drawing.Color]::FromArgb(0, 8, 9, 12))
$ogG.FillPath($pbg, $glowPath)
$pbg.Dispose()
$glowPath.Dispose()

$ogG.DrawImage($srcLens, $lensX, $lensY, $lensW, $lensH)

$fontFamilySans = "Segoe UI"
$fontFamilyMono = "Consolas"

# Category Eyebrow Pill
$pillX = 70
$pillY = 70
$pillW = 485
$pillH = 34
$pillBg = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(35, 56, 189, 248))
$pillBorder = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(90, 56, 189, 248)), 1
$ogG.FillRectangle($pillBg, $pillX, $pillY, $pillW, $pillH)
$ogG.DrawRectangle($pillBorder, $pillX, $pillY, $pillW, $pillH)
$pillBg.Dispose()
$pillBorder.Dispose()

$eyebrowFont = New-Object System.Drawing.Font ($fontFamilyMono, [float]10, [System.Drawing.FontStyle]::Bold)
$eyebrowBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 56, 189, 248))
$ogG.DrawString("CLINICAL INTELLIGENCE - LOW-VISION COPILOT", $eyebrowFont, $eyebrowBrush, ($pillX + 16), ($pillY + 8))
$eyebrowFont.Dispose()
$eyebrowBrush.Dispose()

# Main Title: GozVision
$titleFont = New-Object System.Drawing.Font ($fontFamilySans, [float]56, [System.Drawing.FontStyle]::Bold)
$titleBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 248, 250, 252))
$ogG.DrawString("GozVision", $titleFont, $titleBrush, 68, 118)
$titleFont.Dispose()
$titleBrush.Dispose()

# Tagline
$taglineFont = New-Object System.Drawing.Font ($fontFamilySans, [float]21, [System.Drawing.FontStyle]::Bold)
$taglineBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 56, 189, 248))
$ogG.DrawString("The Practice Operating & Patient Copilot Platform", $taglineFont, $taglineBrush, 72, 218)
$taglineFont.Dispose()
$taglineBrush.Dispose()

# Description Paragraph
$descFont = New-Object System.Drawing.Font ($fontFamilySans, [float]15, [System.Drawing.FontStyle]::Regular)
$descBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(220, 148, 163, 184))
$descText = "Ambient Scribe charting, 90-day device abandonment radar, and Goz - the voice-first multimodal AI copilot patients take home."
$descRect = New-Object System.Drawing.RectangleF 72, 270, 580, 90
$ogG.DrawString($descText, $descFont, $descBrush, $descRect)
$descFont.Dispose()
$descBrush.Dispose()

# Feature Badges
function Draw-FeatureBadge([float]$bx, [float]$by, [float]$bw, [float]$bh, [string]$label) {
    $bBg = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(200, 19, 23, 34))
    $bBorder = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(60, 255, 255, 255)), 1
    $ogG.FillRectangle($bBg, $bx, $by, $bw, $bh)
    $ogG.DrawRectangle($bBorder, $bx, $by, $bw, $bh)
    $bBg.Dispose()
    $bBorder.Dispose()

    $dotBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(255, 16, 185, 129))
    $ogG.FillEllipse($dotBrush, ($bx + 12), ($by + 11), 8, 8)
    $dotBrush.Dispose()

    $bFont = New-Object System.Drawing.Font ($fontFamilySans, [float]11, [System.Drawing.FontStyle]::Bold)
    $txtBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(240, 241, 245, 249))
    $ogG.DrawString($label, $bFont, $txtBrush, ($bx + 28), ($by + 7))
    $bFont.Dispose()
    $txtBrush.Dispose()
}

Draw-FeatureBadge 72  380 270 32 "Ambient Scribe (OLD CARTS)"
Draw-FeatureBadge 354 380 260 32 "90-Day Abandonment Radar"
Draw-FeatureBadge 72  422 270 32 "SMART on FHIR R4 EHR Hub"
Draw-FeatureBadge 354 422 260 32 "Bachs Instant QR POS & Rx"

# Footer Bar
$footerLinePen = New-Object System.Drawing.Pen ([System.Drawing.Color]::FromArgb(40, 255, 255, 255)), 1
$ogG.DrawLine($footerLinePen, 72, 505, 600, 505)
$footerLinePen.Dispose()

$footFont = New-Object System.Drawing.Font ($fontFamilyMono, [float]12, [System.Drawing.FontStyle]::Regular)
$footBrush = New-Object System.Drawing.SolidBrush ([System.Drawing.Color]::FromArgb(200, 100, 116, 139))
$ogG.DrawString("gozvision.app  |  Enterprise Eye Care Intelligence  |  HIPAA Compliant", $footFont, $footBrush, 72, 520)
$footFont.Dispose()
$footBrush.Dispose()

$ogBmp.Save("$tempDir/og_image.png", [System.Drawing.Imaging.ImageFormat]::Png)
$ogG.Dispose()
$ogBmp.Dispose()
$srcLens.Dispose()
$srcBg.Dispose()

Write-Host "==> Finished image synthesis in $tempDir"
