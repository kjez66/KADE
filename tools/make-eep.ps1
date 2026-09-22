<#
  Build a KADE *-custom EEPROM mapping image (Intel HEX .eep).

  Layout, per kade-pin-custom/main.c ("uint8_t ass[40], state[20]"):
    bytes 0x00-0x13  function number for inputs A1..A10, B1..B10  (unshifted)
    bytes 0x14-0x27  same 20 inputs, shifted layer
  Values are `function` numbers from the loader database `library` table.
  0 means unassigned.

  Flash with:  dfu-programmer at90usb162 flash-eeprom <file>.eep
#>
param(
  [Parameter(Mandatory)][string]$Database,
  [Parameter(Mandatory)][string]$System,
  [int]$Preset = 0,
  [Parameter(Mandatory)][string]$Out
)

$rows = & "$PSScriptRoot\sqlq.ps1" -Db $Database -Sql @"
SELECT position, function FROM presets
WHERE system='$System' AND preset=$Preset
ORDER BY CAST(position AS INTEGER)
"@
if (-not $rows) { throw "no preset $Preset for system '$System'" }

$bytes = New-Object byte[] 40
foreach ($r in $rows) {
  $pos = [int]$r.position            # 1-based input number
  $fn  = [int]$r.function
  if ($pos -lt 1 -or $pos -gt 20) { throw "position $pos out of range 1..20" }
  if ($fn  -lt 0 -or $fn  -gt 255) { throw "function $fn out of byte range" }
  $bytes[$pos - 1] = [byte]$fn       # unshifted layer; shifted stays 0
}

# Emit Intel HEX, 16 data bytes per record
$sb = New-Object System.Text.StringBuilder
for ($addr = 0; $addr -lt $bytes.Length; $addr += 16) {
  $len = [Math]::Min(16, $bytes.Length - $addr)
  $rec = @([byte]$len, [byte](($addr -shr 8) -band 0xFF), [byte]($addr -band 0xFF), [byte]0)
  $rec += $bytes[$addr..($addr + $len - 1)]
  $sum = 0; foreach ($b in $rec) { $sum += $b }
  $cks = [byte](((-bnot $sum) + 1) -band 0xFF)
  [void]$sb.Append(':')
  foreach ($b in $rec) { [void]$sb.Append($b.ToString('X2')) }
  [void]$sb.Append($cks.ToString('X2')).Append("`n")
}
[void]$sb.Append(":00000001FF`n")

[System.IO.File]::WriteAllText($Out, $sb.ToString(), [System.Text.ASCIIEncoding]::new())
Write-Output "wrote $Out ($($bytes.Length) bytes of EEPROM)"
