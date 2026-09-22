param([string]$Db,[string]$OutDir,[string]$Family='minimus')
. "$PSScriptRoot\sqlq.ps1" -Db $Db -Sql "SELECT 1" | Out-Null
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

function Test-IntelHex {
  param([string[]]$Lines)
  $bytes=0; $eof=$false; $bad=0
  foreach($l in $Lines){
    $l=$l.Trim(); if(-not $l){continue}
    if($l[0] -ne ':'){ $bad++; continue }
    $h=$l.Substring(1)
    if($h.Length % 2 -ne 0){ $bad++; continue }
    $b=@(); for($i=0;$i -lt $h.Length;$i+=2){ $b += [Convert]::ToByte($h.Substring($i,2),16) }
    $sum=0; foreach($x in $b){ $sum=($sum+$x) -band 0xFF }
    if($sum -ne 0){ $bad++ }
    if($b[3] -eq 0){ $bytes += $b[0] }
    if($b[3] -eq 1){ $eof=$true }
  }
  [pscustomobject]@{Bytes=$bytes;Eof=$eof;BadLines=$bad;Records=$Lines.Count}
}

$rows = & "$PSScriptRoot\sqlq.ps1" -Db $Db -Sql "SELECT name, hex FROM firmwares WHERE family='$Family' AND hex IS NOT NULL AND length(hex)>0 ORDER BY name"
$res=@()
foreach($r in $rows){
  $path = Join-Path $OutDir ("{0}.hex" -f $r.name)
  $norm = $r.hex -replace "`r`n","`n"
  [System.IO.File]::WriteAllText($path, ($norm.TrimEnd() + "`n"), [System.Text.ASCIIEncoding]::new())
  $v = Test-IntelHex -Lines ($norm -split "`n")
  $res += [pscustomobject]@{
    Firmware=$r.name; FlashBytes=$v.Bytes; Records=$v.Records
    BadChecksums=$v.BadLines; HasEOF=$v.Eof
    FitsIn16K = ($v.Bytes -le 16384)
  }
}
$res | Sort-Object FlashBytes -Descending
