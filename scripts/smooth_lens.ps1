Add-Type -AssemblyName System.Drawing

$ErrorActionPreference = "Stop"

$src = [System.Drawing.Bitmap]::FromFile((Resolve-Path "apps/website/assets/gozvision_lens.png"))
$w = $src.Width
$h = $src.Height
$outBmp = New-Object System.Drawing.Bitmap $w, $h, ([System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

# Lock bits for fast pixel processing
$rect = New-Object System.Drawing.Rectangle 0, 0, $w, $h
$srcData = $src.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
$dstData = $outBmp.LockBits($rect, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)

$bytes = [Math]::Abs($srcData.Stride) * $h
$srcBuffer = New-Object byte[] $bytes
$dstBuffer = New-Object byte[] $bytes

[System.Runtime.InteropServices.Marshal]::Copy($srcData.Scan0, $srcBuffer, 0, $bytes)

# Process BGRA bytes
for ($i = 0; $i -lt $bytes; $i += 4) {
    $b = $srcBuffer[$i]
    $g = $srcBuffer[$i+1]
    $r = $srcBuffer[$i+2]
    
    # White background threshold
    $minChannel = [Math]::Min($r, [Math]::Min($g, $b))
    if ($minChannel -ge 245) {
        $dstBuffer[$i]   = 0
        $dstBuffer[$i+1] = 0
        $dstBuffer[$i+2] = 0
        $dstBuffer[$i+3] = 0
    } elseif ($minChannel -ge 215) {
        $alpha = [byte](([float](245 - $minChannel) / 30.0) * 255.0)
        $dstBuffer[$i]   = $b
        $dstBuffer[$i+1] = $g
        $dstBuffer[$i+2] = $r
        $dstBuffer[$i+3] = $alpha
    } else {
        $dstBuffer[$i]   = $b
        $dstBuffer[$i+1] = $g
        $dstBuffer[$i+2] = $r
        $dstBuffer[$i+3] = 255
    }
}

[System.Runtime.InteropServices.Marshal]::Copy($dstBuffer, 0, $dstData.Scan0, $bytes)

$src.UnlockBits($srcData)
$outBmp.UnlockBits($dstData)
$src.Dispose()

$outBmp.Save("scripts/temp_icons/clean_lens_smooth.png", [System.Drawing.Imaging.ImageFormat]::Png)
$outBmp.Dispose()
Write-Host "Done smoothing lens"
