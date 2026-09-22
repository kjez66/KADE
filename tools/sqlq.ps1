param([string]$Db, [string]$Sql, [string]$OutFile)

if (-not ([System.Management.Automation.PSTypeName]'SQLite').Type) {
Add-Type -TypeDefinition @"
using System;
using System.Runtime.InteropServices;
public static class SQLite {
  [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl, CharSet=CharSet.Unicode)]
  public static extern int sqlite3_open16(string f, out IntPtr db);
  [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl, CharSet=CharSet.Unicode)]
  public static extern int sqlite3_prepare16_v2(IntPtr db, string sql, int n, out IntPtr stmt, IntPtr tail);
  [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
  public static extern int sqlite3_step(IntPtr stmt);
  [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
  public static extern int sqlite3_column_count(IntPtr stmt);
  [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
  public static extern IntPtr sqlite3_column_name16(IntPtr stmt, int i);
  [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
  public static extern IntPtr sqlite3_column_text16(IntPtr stmt, int i);
  [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
  public static extern int sqlite3_finalize(IntPtr stmt);
  [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
  public static extern int sqlite3_close(IntPtr db);
  [DllImport("winsqlite3.dll", CallingConvention=CallingConvention.Cdecl)]
  public static extern IntPtr sqlite3_errmsg16(IntPtr db);
}
"@
}

$hDb = [IntPtr]::Zero
if ([SQLite]::sqlite3_open16($Db, [ref]$hDb) -ne 0) { throw "open failed" }
$st = [IntPtr]::Zero
if ([SQLite]::sqlite3_prepare16_v2($hDb, $Sql, -1, [ref]$st, [IntPtr]::Zero) -ne 0) {
  throw ("prepare failed: " + [Runtime.InteropServices.Marshal]::PtrToStringUni([SQLite]::sqlite3_errmsg16($hDb)))
}
$n = [SQLite]::sqlite3_column_count($st)
$cols = @(); for($i=0;$i -lt $n;$i++){ $cols += [Runtime.InteropServices.Marshal]::PtrToStringUni([SQLite]::sqlite3_column_name16($st,$i)) }
$rows = @()
while ([SQLite]::sqlite3_step($st) -eq 100) {
  $o = [ordered]@{}
  for($i=0;$i -lt $n;$i++){ $o[$cols[$i]] = [Runtime.InteropServices.Marshal]::PtrToStringUni([SQLite]::sqlite3_column_text16($st,$i)) }
  $rows += [pscustomobject]$o
}
[void][SQLite]::sqlite3_finalize($st); [void][SQLite]::sqlite3_close($hDb)
if ($OutFile) { $rows[0].($cols[0]) | Out-File -FilePath $OutFile -Encoding ascii -NoNewline; Write-Output "wrote $OutFile" }
else { $rows }
