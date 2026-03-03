##############################################################################
#       Copyright (C) 2024 Sebastian Oehms <seb.oehms@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#                  http://www.gnu.org/licenses/
##############################################################################

# Copy-Paste from here including the final Blankline

param(
    [string] $Type = "TwoInOne",
    [string] $branch = "main"  # for testing
)

if ($Type -eq "OnlyDocker") {
    $app_name = "SageMathDockerGuide"
    $script_name = "sagemath_docker_guide"
    $icofile = "sage.ico"
}
elseif ($Type -eq "OnlyAppImage") {
    $app_name = "SageMathAppImageGuide"
    $script_name = "sagemath_appimage_guide"
    $icofile = "orange.ico"
}
else {
    $app_name = "SageMathDockerAndAppImageGuide"
    $script_name = "sagemath_docker_and_appimage_guide"
    $icofile = "blue.ico"
}

$path = "$HOME\AppData\Local\$app_name"
$psfile = "$script_name.ps1"
$psmfile = "proj_docker_guide.psm1"
$ps = "${path}\${psfile}"; $psm = "${path}\${psmfile}"; $ico = "${path}\${icofile}"

$url = "https://raw.githubusercontent.com/soehms/projects_docker_guide/$branch/src"
$urlps = "${url}/${psfile}"; $urlpsm = "${url}/${psmfile}"; $urlico = "${url}/${icofile}"

New-Item -ItemType Directory -Force -Path $path
Start-BitsTransfer -Source $urlps -Destination $ps
Start-BitsTransfer -Source $urlpsm -Destination $psm
Start-BitsTransfer -Source $urlico -Destination $ico
(Get-Content -Raw $ps) -creplace '$psmfile', '$psm' | Set-Content -NoNewLine $ps # adjust module path

$ShortcutPath = [System.IO.Path]::Combine([System.Environment]::GetFolderPath("Desktop"), "${app_name}.lnk")
$WScriptObj = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptObj.CreateShortcut($ShortcutPath)
$SourceFilePath = "C:\Windows\system32\WindowsPowerShell\v1.0\powershell.exe"
$SourceArguments = "-ExecutionPolicy Bypass -File $ps"
$Shortcut.TargetPath = $SourceFilePath
$Shortcut.Arguments = $SourceArguments
$Shortcut.WorkingDirectory = "%HOMEDRIVE%%HOMEPATH%"
$Shortcut.IconLocation = "$ico"
$Shortcut.Save()
