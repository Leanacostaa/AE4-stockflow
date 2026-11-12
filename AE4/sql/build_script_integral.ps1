# Genera AE4_StockFlow_script_integral.sql concatenando los modulos 01..08
# en orden. Ejecutar desde la carpeta AE4\sql:  .\build_script_integral.ps1
$ErrorActionPreference = 'Stop'
$here = Split-Path -Parent $MyInvocation.MyCommand.Path
$out  = Join-Path (Split-Path -Parent $here) 'AE4_StockFlow_script_integral.sql'
$mods = Get-ChildItem $here -Filter '0*.sql' | Sort-Object Name
$sb = New-Object System.Text.StringBuilder
[void]$sb.AppendLine('/* ==========================================================================')
[void]$sb.AppendLine('   AE4 - TRABAJO FINAL INTEGRADOR - BASE DE DATOS (ISI17BAD28V26AE4V26)')
[void]$sb.AppendLine('   Proyecto StockFlow - SCRIPT INTEGRAL')
[void]$sb.AppendLine('   Estudiantes: Leandro Acosta - Nahuel Villegas')
[void]$sb.AppendLine('   Motor: Microsoft SQL Server 2022. Ejecutable de principio a fin sobre un')
[void]$sb.AppendLine('   servidor sin la base StockFlow (la crea desde cero).')
[void]$sb.AppendLine('   SSMS: abrir y ejecutar (F5). sqlcmd:')
[void]$sb.AppendLine('     sqlcmd -S .\SQLEXPRESS -E -f 65001 -i AE4_StockFlow_script_integral.sql')
[void]$sb.AppendLine('   Archivo generado a partir de los modulos de la carpeta sql/:')
foreach ($m in $mods) { [void]$sb.AppendLine('     ' + $m.Name) }
[void]$sb.AppendLine('   ========================================================================== */')
foreach ($m in $mods) {
    [void]$sb.AppendLine('')
    [void]$sb.AppendLine('/* ##########################################################################')
    [void]$sb.AppendLine('   MODULO ' + $m.Name)
    [void]$sb.AppendLine('   ########################################################################## */')
    [void]$sb.Append([System.IO.File]::ReadAllText($m.FullName, [System.Text.Encoding]::UTF8))
}
# UTF-8 con BOM: SSMS lo reconoce sin ambiguedad.
[System.IO.File]::WriteAllText($out, $sb.ToString(), (New-Object System.Text.UTF8Encoding($true)))
Write-Host "Generado: $out"
