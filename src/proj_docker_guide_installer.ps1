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

$psfile = "proj_docker_guide.ps1"
$icofile = "sage.ico"
$path = $($PWD)

$urlps1 = "https://raw.githubusercontent.com/soehms/projects_docker_guide/main/src/${psfile}"
$urlico = "https://raw.githubusercontent.com/soehms/projects_docker_guide/main/src/${icofile}"
$destination = "C:\Windows\system32"

Invoke-WebRequest -Uri $urlps1 -OutFile "${path}\${psfile}"
Invoke-WebRequest -Uri $urlico -OutFile "${path}\${icofile}"

$ShortcutPath = [System.IO.Path]::Combine([System.Environment]::GetFolderPath("Desktop"), "${proj_name}DockerGuide.lnk")
$WScriptObj = New-Object -ComObject WScript.Shell
$Shortcut = $WScriptObj.CreateShortcut($ShortcutPath)
$SourceFilePath = "C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe"
$SourceArguments = "-ExecutionPolicy Bypass -File C:\Windows\System32\proj_docker_guide.ps1"
$Shortcut.TargetPath = $SourceFilePath
$Shortcut.Arguments = $SourceArguments
$Shortcut.WorkingDirectory = "%HOMEDRIVE%%HOMEPATH%"
$Shortcut.IconLocation = "${path}\${icofile}" 
$Shortcut.Save()

$argu ="Move-Item -Path $PWD\proj_docker_guide.ps1 -Destination ${destination} -Force"

Start-Process -Verb RunAs powershell -ArgumentList $argu
del $icofile

