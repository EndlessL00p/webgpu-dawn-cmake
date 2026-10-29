#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
	Builds Dawn for this machine's platform and packages it as a release archive in dist/.

.DESCRIPTION
	Configures this project with the platform's preset (CMakePresets.json), builds the shared library,
	installs it into dist/stage, checks it, writes VERSIONS, and zips the stage as
	dist/webgpu-dawn-<Version>-<platform>.zip with a .sha256 file beside it.

	The checks: on Windows, the library and DXC link the static C runtime (no VCRUNTIME, MSVCP or
	UCRT imports); on Linux, the library needs no newer glibc than -MaxGlibc.

	CI runs exactly this script; ./scripts/smoke.ps1 then tests the archive.

.PARAMETER Version
	The archive's version label, such as v20261027.184652-1. Defaults to dev.

.PARAMETER BuildDir
	The build folder. Defaults to build. Dawn's dependencies nest deeply, so on Windows a short path
	such as C:/b keeps file paths under Windows' 260-character limit.

.PARAMETER MaxGlibc
	Linux only: fail if the library needs a newer glibc than this, such as 2.28.

.EXAMPLE
	./scripts/build.ps1 -Version v20261027.184652-1 -BuildDir C:/b
#>
param(
	[string] $Version = 'dev',
	[string] $BuildDir = 'build',
	[string] $MaxGlibc = ''
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
Set-Location (Join-Path $PSScriptRoot '..')

$Platform = Get-HostPlatform
if ($IsWindows) { Enter-VisualStudioShell }

$Dist = 'dist'
$Stage = Join-Path $Dist 'stage'
Remove-Item -Recurse -Force $Stage -ErrorAction SilentlyContinue
New-Item -ItemType Directory -Force -Path $Stage | Out-Null

Invoke-Checked cmake --preset $Platform -B $BuildDir
Invoke-Checked cmake --build $BuildDir --parallel
Invoke-Checked cmake --install $BuildDir --prefix $Stage

# Checks on what was built.
$Notes = @()
if ($IsWindows)
{
	foreach ($Library in @('bin/webgpu_dawn.dll', 'bin/dxcompiler.dll'))
	{
		$Path = Join-Path $Stage $Library
		if (-not (Test-Path $Path)) { throw "$Library is missing from the archive." }
		$Imports = @(dumpbin /nologo /dependents $Path | Where-Object { $_ -match '^\s+\S+\.dll\s*$' } | ForEach-Object { $_.Trim() })
		$Runtime = @($Imports | Where-Object { $_ -match '^(vcruntime|msvcp|api-ms-win-crt-)' })
		if ($Runtime.Count -gt 0)
		{
			throw "$Library links the dynamic C runtime ($($Runtime -join ', ')); it must link the static one."
		}
		$Notes += "imports:  $Library -> $($Imports -join ', ')"
	}
}
elseif ($IsMacOS)
{
	$Library = Join-Path $Stage 'lib/libwebgpu_dawn.dylib'
	$MinimumOs = (otool -l $Library | Select-String -Pattern '^\s+minos (\S+)' | Select-Object -First 1).Matches[0].Groups[1].Value
	$Notes += "macos:    $MinimumOs or later"
}
else
{
	$Library = Join-Path $Stage 'lib/libwebgpu_dawn.so'
	$Glibc = objdump -T $Library | Select-String -Pattern 'GLIBC_([0-9.]+)' -AllMatches |
		ForEach-Object { $_.Matches } | ForEach-Object { [version]$_.Groups[1].Value } | Sort-Object -Unique | Select-Object -Last 1
	if ($MaxGlibc -and $Glibc -gt [version]$MaxGlibc)
	{
		throw "libwebgpu_dawn.so needs glibc $Glibc, newer than $MaxGlibc."
	}
	$Notes += "glibc:    $Glibc or later"
}

# Provenance: exactly what is in the archive.
function Get-CacheValue([string] $Key)
{
	$Hit = Select-String -Path (Join-Path $BuildDir 'CMakeCache.txt') -Pattern "^${Key}:\w+=(.*)$" | Select-Object -First 1
	if (-not $Hit) { throw "$Key is not in $BuildDir/CMakeCache.txt." }
	return $Hit.Matches[0].Groups[1].Value
}
$CompilerFile = Get-ChildItem (Join-Path $BuildDir 'CMakeFiles/*/CMakeCXXCompiler.cmake') | Select-Object -First 1
$CompilerText = Get-Content -Raw $CompilerFile
$Compiler = [regex]::Match($CompilerText, 'set\(CMAKE_CXX_COMPILER "([^"]+)"\)').Groups[1].Value
$CompilerId = [regex]::Match($CompilerText, 'set\(CMAKE_CXX_COMPILER_ID "([^"]+)"\)').Groups[1].Value
$CompilerVersion = [regex]::Match($CompilerText, 'set\(CMAKE_CXX_COMPILER_VERSION "([^"]+)"\)').Groups[1].Value
$DawnSource = Join-Path $BuildDir '_deps/dawn-src'
@(
	"package:  webgpu-dawn-cmake $Version"
	"dawn:     $(Get-CacheValue 'DAWN_TAG') ($(git -C $DawnSource rev-parse HEAD))"
	"compiler: $CompilerId $CompilerVersion ($Compiler)"
	"platform: $Platform"
	$Notes
	"built:    $((Get-Date).ToUniversalTime().ToString('yyyy-MM-dd HH:mm')) UTC"
) | Set-Content (Join-Path $Stage 'VERSIONS')

# The archive and its checksum.
$Name = "webgpu-dawn-$Version-$Platform"
$Zip = Join-Path $Dist "$Name.zip"
Remove-Item $Zip -ErrorAction SilentlyContinue
Compress-Archive -Path "$Stage/*" -DestinationPath $Zip
$Hash = (Get-FileHash -Algorithm SHA256 $Zip).Hash.ToLower()
"$Hash  $Name.zip" | Set-Content (Join-Path $Dist "$Name.zip.sha256")

Get-Content (Join-Path $Stage 'VERSIONS') | Write-Host
Write-Host "packaged $Zip"
Write-Host "sha256   $Hash"
