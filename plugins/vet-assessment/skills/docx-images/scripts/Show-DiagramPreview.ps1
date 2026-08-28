<#
.SYNOPSIS
  Draws a PNG preview of a diagram spec, and checks its geometry.

.DESCRIPTION
  A quality aid, not part of the document. It runs the same layout functions
  the real renderer uses, then draws the result so the layout can be looked at
  before anything is written into a document, and reports any box that runs off
  the canvas or overlaps another.

  The PNG is a preview only. What goes into the .docx is always native Word
  shapes - this never becomes a picture in a document.

.EXAMPLE
  .\Show-DiagramPreview.ps1 -ManifestPath .\images\manifest.json -OutDir .\images\previews
  .\Show-DiagramPreview.ps1 -SpecPath .\spec.json -OutDir .\previews
#>
[CmdletBinding()]
param(
  [string]$ManifestPath,
  [string]$SpecPath,
  [Parameter(Mandatory)][string]$OutDir,
  [string]$ConfigPath,
  [string[]]$Only,
  [int]$WidthEmu = 6188710
)

$ErrorActionPreference = 'Stop'
Add-Type -AssemblyName System.Drawing
. (Join-Path $PSScriptRoot 'Docx-DiagramLib.ps1')

if (-not $ConfigPath) { $ConfigPath = Join-Path (Split-Path -Parent $PSScriptRoot) 'config\defaults.json' }
$cfg  = Get-Content -LiteralPath $ConfigPath -Raw -Encoding UTF8 | ConvertFrom-Json
$dcfg = if ($cfg.PSObject.Properties['diagram']) { $cfg.diagram } else { $null }
$pal  = Get-DiagramPalette $dcfg

if (-not (Test-Path -LiteralPath $OutDir)) { New-Item -ItemType Directory -Path $OutDir -Force | Out-Null }

$jobs = @()
if ($ManifestPath) {
  $m = Get-Content -LiteralPath $ManifestPath -Raw -Encoding UTF8 | ConvertFrom-Json
  foreach ($ph in $m.placeholders) {
    if ($ph.kind -ne 'diagram' -or -not $ph.spec) { continue }
    if ($Only -and $Only -notcontains $ph.id) { continue }
    $jobs += @{ Id = $ph.id; Spec = $ph.spec }
  }
}
if ($SpecPath) {
  $s = Get-Content -LiteralPath $SpecPath -Raw -Encoding UTF8 | ConvertFrom-Json
  $jobs += @{ Id = [System.IO.Path]::GetFileNameWithoutExtension($SpecPath); Spec = $s }
}
if ($jobs.Count -eq 0) { Write-Host 'No diagram specs to preview.'; exit 0 }

function ToPx { param([int]$Emu, [double]$Scale) return [int]($Emu * $Scale) }

$problems = 0
foreach ($j in $jobs) {
  $spec   = $j.Spec
  $layout = "$(Get-Prop $spec 'layout' 'process')".ToLower()

  if ($layout -in @('table','matrix','comparison')) {
    $rows = @(Get-Prop $spec 'rows' @())
    Write-Host ("{0}  table  {1} row(s) x {2} column(s) - rendered as a real Word table, nothing to preview" -f `
      $j.Id, $rows.Count, (@($rows[0])).Count) -ForegroundColor DarkCyan
    continue
  }

  $nodes  = @(Get-Prop $spec 'nodes' @())
  $orient = "$(Get-Prop $spec 'orientation' 'horizontal')".ToLower()
  switch ($layout) {
    'bands'     { $L = Get-BandsLayout     -Nodes $nodes -W $WidthEmu }
    'cycle'     { $L = Get-CycleLayout     -Nodes $nodes -W $WidthEmu }
    'hierarchy' { $L = Get-HierarchyLayout -Nodes $nodes -W $WidthEmu }
    default     { $L = Get-ProcessLayout   -Nodes $nodes -W $WidthEmu -Orientation $orient }
  }

  # ---- geometry checks ------------------------------------------------------
  $issues = @()
  $boxes = @()
  foreach ($p in $L.Nodes) {
    $boxes += @{ X = $p.X; Y = $p.Y; R = $p.X + $p.Cx; B = $p.Y + $p.Cy; T = "$(Get-Prop $p.Node 'text' '')" }
  }
  foreach ($b in $boxes) {
    if ($b.X -lt 0 -or $b.R -gt $WidthEmu) { $issues += "'$($b.T)' runs off the canvas horizontally" }
    if ($b.Y -lt 0 -or $b.B -gt $L.Height) { $issues += "'$($b.T)' runs off the canvas vertically" }
  }
  for ($a = 0; $a -lt $boxes.Count; $a++) {
    for ($b2 = $a + 1; $b2 -lt $boxes.Count; $b2++) {
      $p = $boxes[$a]; $q = $boxes[$b2]
      $ox = [Math]::Min($p.R, $q.R) - [Math]::Max($p.X, $q.X)
      $oy = [Math]::Min($p.B, $q.B) - [Math]::Max($p.Y, $q.Y)
      # Bands touch by design; anything else overlapping is a bug.
      if ($ox -gt 0 -and $oy -gt 0 -and $layout -ne 'bands') {
        $issues += "'$($p.T)' overlaps '$($q.T)'"
      }
    }
  }

  # ---- draw -----------------------------------------------------------------
  $scale = 1000.0 / $WidthEmu
  $wpx = 1000
  $hpx = [Math]::Max(80, (ToPx $L.Height $scale))
  $bmp = New-Object System.Drawing.Bitmap($wpx, $hpx)
  $g = [System.Drawing.Graphics]::FromImage($bmp)
  $g.SmoothingMode = 'AntiAlias'
  $g.TextRenderingHint = 'ClearTypeGridFit'
  $g.Clear([System.Drawing.Color]::White)

  $penArrow = New-Object System.Drawing.Pen ([System.Drawing.ColorTranslator]::FromHtml("#$($pal.grey)")), 2
  $penArrow.EndCap = [System.Drawing.Drawing2D.LineCap]::ArrowAnchor
  foreach ($c in $L.Connectors) {
    $g.DrawLine($penArrow, (ToPx $c.X1 $scale), (ToPx $c.Y1 $scale), (ToPx $c.X2 $scale), (ToPx $c.Y2 $scale))
  }

  $fmt = New-Object System.Drawing.StringFormat
  $fmt.Alignment = [System.Drawing.StringAlignment]::Center
  $fmt.LineAlignment = [System.Drawing.StringAlignment]::Center
  foreach ($p in $L.Nodes) {
    $st = Get-FillStyle -Name (Get-Prop $p.Node 'fill' 'light') -Palette $pal
    $rect = New-Object System.Drawing.RectangleF `
      ((ToPx $p.X $scale), (ToPx $p.Y $scale), (ToPx $p.Cx $scale), (ToPx $p.Cy $scale))
    $brush = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#$($st.Fill)"))
    $pen   = New-Object System.Drawing.Pen ([System.Drawing.ColorTranslator]::FromHtml("#$($st.Line)")), 2
    $g.FillRectangle($brush, $rect)
    $g.DrawRectangle($pen, $rect.X, $rect.Y, $rect.Width, $rect.Height)
    $txt = "$(Get-Prop $p.Node 'text' '')"
    $note = "$(Get-Prop $p.Node 'note' '')"
    if ($note) { $txt = "$txt`n$note" }
    $font = New-Object System.Drawing.Font('Arial', 11)
    $tb = New-Object System.Drawing.SolidBrush ([System.Drawing.ColorTranslator]::FromHtml("#$($st.Text)"))
    $g.DrawString($txt, $font, $tb, $rect, $fmt)
    $font.Dispose(); $tb.Dispose(); $brush.Dispose(); $pen.Dispose()
  }
  $g.Dispose()

  $png = Join-Path $OutDir ("{0}_preview.png" -f $j.Id)
  $bmp.Save($png, [System.Drawing.Imaging.ImageFormat]::Png)
  $bmp.Dispose()

  $hcm = [Math]::Round($L.Height / 360000.0, 1)
  if ($issues.Count -gt 0) {
    $problems += $issues.Count
    Write-Host ("{0}  {1,-10} {2} node(s), {3} cm tall  - {4} PROBLEM(S)" -f $j.Id, $layout, $L.Nodes.Count, $hcm, $issues.Count) -ForegroundColor Red
    foreach ($i in $issues) { Write-Host "     $i" -ForegroundColor Red }
  }
  else {
    Write-Host ("{0}  {1,-10} {2} node(s), {3} connector(s), {4} cm tall  - clean" -f `
      $j.Id, $layout, $L.Nodes.Count, $L.Connectors.Count, $hcm) -ForegroundColor Green
  }
  Write-Host "     $png"
}

if ($problems -gt 0) { exit 5 }
