param(
  [int]$Port = 8090
)

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$Listener = New-Object System.Net.HttpListener
$Prefix = "http://localhost:$Port/"
$Listener.Prefixes.Add($Prefix)
$Listener.Start()

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "  BE Mentor Akademi Yerel Sunucu Aktif!" -ForegroundColor Green
Write-Host "  Web Sitesi   : http://localhost:$Port/index.html" -ForegroundColor White
Write-Host "  Admin Paneli : http://localhost:$Port/admin.html" -ForegroundColor Yellow
Write-Host "  Kapatmak icin bu pencereyi kapatin." -ForegroundColor Gray
Write-Host "==========================================" -ForegroundColor Cyan

$MimeTypes = @{
  ".html"        = "text/html; charset=utf-8"
  ".css"         = "text/css; charset=utf-8"
  ".js"          = "application/javascript; charset=utf-8"
  ".svg"         = "image/svg+xml"
  ".png"         = "image/png"
  ".jpg"         = "image/jpeg"
  ".jpeg"        = "image/jpeg"
  ".webp"        = "image/webp"
  ".mp4"         = "video/mp4"
  ".webm"        = "video/webm"
  ".json"        = "application/json; charset=utf-8"
  ".webmanifest" = "application/manifest+json; charset=utf-8"
  ".xml"         = "application/xml; charset=utf-8"
  ".txt"         = "text/plain; charset=utf-8"
  ".ico"         = "image/x-icon"
}

try {
  while ($Listener.IsListening) {
    $Context = $Listener.GetContext()
    $Req = $Context.Request
    $Res = $Context.Response

    try {
      $RelPath = [System.Uri]::UnescapeDataString($Req.Url.AbsolutePath.TrimStart('/'))
      if ([string]::IsNullOrWhiteSpace($RelPath)) { $RelPath = "index.html" }
      $FullPath = Join-Path $Root ($RelPath -replace '/', '\')

      if ((Test-Path $FullPath -PathType Leaf) -and $FullPath.StartsWith($Root)) {
        $Ext = [System.IO.Path]::GetExtension($FullPath).ToLower()
        $Res.ContentType = if ($MimeTypes.ContainsKey($Ext)) { $MimeTypes[$Ext] } else { "application/octet-stream" }
        $Res.Headers.Add("Accept-Ranges", "bytes")

        $FileInfo = Get-Item $FullPath
        $TotalLen = $FileInfo.Length
        $RangeHeader = $Req.Headers["Range"]

        $Stream = [System.IO.File]::OpenRead($FullPath)
        try {
          if ($RangeHeader -and $RangeHeader -match "bytes=(\d*)-(\d*)") {
            $Start = if ($Matches[1] -ne "") { [long]$Matches[1] } else { 0 }
            $End   = if ($Matches[2] -ne "") { [long]$Matches[2] } else { $TotalLen - 1 }
            if ($End -ge $TotalLen) { $End = $TotalLen - 1 }
            if ($Start -gt $End -or $Start -lt 0) {
              $Res.StatusCode = 416
            } else {
              $ChunkLen = $End - $Start + 1
              $Res.StatusCode = 206
              $Res.Headers.Add("Content-Range", "bytes $Start-$End/$TotalLen")
              $Res.ContentLength64 = $ChunkLen
              $Stream.Seek($Start, [System.IO.SeekOrigin]::Begin) | Out-Null
              $Buffer = New-Object byte[] 65536
              $Remaining = $ChunkLen
              while ($Remaining -gt 0) {
                $ToRead = [int][Math]::Min($Buffer.Length, $Remaining)
                $Read = $Stream.Read($Buffer, 0, $ToRead)
                if ($Read -le 0) { break }
                $Res.OutputStream.Write($Buffer, 0, $Read)
                $Remaining -= $Read
              }
            }
          } else {
            $Res.StatusCode = 200
            $Res.ContentLength64 = $TotalLen
            $Stream.CopyTo($Res.OutputStream)
          }
        } finally {
          $Stream.Dispose()
        }
      } else {
        $Res.StatusCode = 404
        $Msg = [System.Text.Encoding]::UTF8.GetBytes("404 - Dosya bulunamadi")
        $Res.OutputStream.Write($Msg, 0, $Msg.Length)
      }
    } catch {
      # Ignore client disconnect during video range scrubbing
    } finally {
      try { $Res.OutputStream.Close() } catch {}
    }
  }
} finally {
  $Listener.Stop()
}
