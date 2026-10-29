# Shared helpers for the scripts in this folder. Dot-source, don't run:
#   . (Join-Path $PSScriptRoot 'common.ps1')

# Runs a native command and stops on a failing exit code, which $ErrorActionPreference = 'Stop'
# alone does not cover.
function Invoke-Checked
{
	& $args[0] @($args[1..($args.Count - 1)])
	if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
}

# The platform label of archives built on this machine: windows-x64, linux-x64 or macos-arm64.
function Get-HostPlatform
{
	if ($IsWindows) { return 'windows-x64' }
	if ($IsMacOS) { return 'macos-arm64' }
	return 'linux-x64'
}

# Enters a Visual Studio developer environment for x64, unless cl is already on PATH.
function Enter-VisualStudioShell
{
	if (Get-Command cl -ErrorAction SilentlyContinue) { return }
	$VsWhere = Join-Path ${env:ProgramFiles(x86)} 'Microsoft Visual Studio\Installer\vswhere.exe'
	$VsPath = & $VsWhere -latest -products * -requires Microsoft.VisualStudio.Component.VC.Tools.x86.x64 -property installationPath
	if (-not $VsPath) { throw 'No Visual Studio with the x64 C++ tools was found.' }
	Import-Module (Join-Path $VsPath 'Common7\Tools\Microsoft.VisualStudio.DevShell.dll')
	Enter-VsDevShell -VsInstallPath $VsPath -DevCmdArguments '-arch=x64 -host_arch=x64' -SkipAutomaticLocation
}
