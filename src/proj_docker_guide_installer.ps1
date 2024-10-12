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

$proj_name = "SageMath"

$path = $($PWD)
$psfile = "proj_docker_guide.ps1"; $icofile = "sage.ico"
$ps = "${path}\${psfile}"; $ico = "${path}\${icofile}"

$url = "https://raw.githubusercontent.com/soehms/projects_docker_guide/main/src"
$urlps = "${url}/${psfile}"; $urlico = "${url}/${icofile}"

Invoke-WebRequest -Uri $urlps -OutFile $ps
Invoke-WebRequest -Uri $urlico -OutFile $ico

$destination = "C:\Windows\system32"
$argu ="Move-Item -Path $ps,$ico -Destination ${destination} -Force"
Start-Process -Verb RunAs powershell -ArgumentList $argu

$ShortcutPath = [System.IO.Path]::Combine([System.Environment]::GetFolderPath("Desktop"), "${proj_name}DockerGuide.lnk")
$WScriptObj = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptObj.CreateShortcut($ShortcutPath)
$SourceFilePath = "${destination}\WindowsPowerShell\v1.0\powershell.exe"
$SourceArguments = "-ExecutionPolicy Bypass -File ${destination}\${psfile}"
$Shortcut.TargetPath = $SourceFilePath
$Shortcut.Arguments = $SourceArguments
$Shortcut.WorkingDirectory = "%HOMEDRIVE%%HOMEPATH%"
$Shortcut.IconLocation = "${destination}\${icofile}"
$Shortcut.Save()

