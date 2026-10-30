#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
	Tests a release archive the way a consumer uses it.

.DESCRIPTION
	Unpacks the archive into a temporary folder, builds tests/smoke against it with find_package(Dawn),
	with no Dawn sources present, and runs it. The smoke test creates a device on the platform's
	adapter and compiles a compute pipeline; on Windows it also checks that DXC was used. No release
	is published without this passing.

.PARAMETER Archive
	The .zip to test.

.EXAMPLE
	./scripts/smoke.ps1 -Archive dist/webgpu-dawn-dev-linux-x64.zip
#>
param(
	[Parameter(Mandatory)] [string] $Archive
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'common.ps1')
Set-Location (Join-Path $PSScriptRoot '..')

$Work = Join-Path ([IO.Path]::GetTempPath()) ('webgpu-dawn-smoke-' + [IO.Path]::GetRandomFileName())
try
{
	$Root = Join-Path $Work 'archive'
	Expand-Archive -Path $Archive -DestinationPath $Root
	Get-Content (Join-Path $Root 'VERSIONS') | Write-Host

	$Build = Join-Path $Work 'build'
	Invoke-Checked cmake -S tests/smoke -B $Build "-DCMAKE_PREFIX_PATH=$Root" -DCMAKE_BUILD_TYPE=Release
	Invoke-Checked cmake --build $Build --config Release
	$Executable = @("$Build/smoke", "$Build/smoke.exe", "$Build/Release/smoke.exe") |
		Where-Object { Test-Path $_ } | Select-Object -First 1
	if (-not $Executable) { throw 'The smoke test was not built.' }

	$Output = & $Executable 2>&1 | ForEach-Object { "$_" }
	$Output | Write-Host
	if ($LASTEXITCODE -ne 0 -or -not ($Output -match 'SMOKE_PASS'))
	{
		Write-Host "FAIL: $Archive"
		exit 1
	}
	Write-Host "PASS: $Archive"
}
finally
{
	Remove-Item -Recurse -Force $Work -ErrorAction SilentlyContinue
}
