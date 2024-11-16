##############################################################################
#       Copyright (C) 2024 Sebastian Oehms <seb.oehms@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#                  http://www.gnu.org/licenses/
##############################################################################

# ToDo
# 1. Implement the *More* functionality in the *tags* window
# 2. Add possiblility to stop a container
# 3. Add possiblility to rename a container
# 4. Extract project specific data from devcontainer.json files
# 5. Move $this._container to argument list of methods
# 6. Open separate terminal for selection windows on Linux, too


###############################################################################################
# To show verbose messages set $VerbosePreference = 2 (Continue)  in your Powershell session.
# To revert this set           $VerbosePreference = 0 (SilentlyContinue)
###############################################################################################


###############################################################################################
# Static declarations
###############################################################################################


param(
    [string] $option = "no option"
)

enum TagFilterValues {
    all
    stable
    pre
}

$env:WSL_UTF8 = 1 # needed to pass variables to WSL commands

###############################################################################################
# Access to global PS variables in class methods needs the following functions
###############################################################################################

function os_is_linux {
    return $PSVersionTable.Platform -eq 'Unix'
}

function get_matches {
    # get result of previous regular expresssion match via -match option
    Write-Verbose "get_matches ${Matches}"
    return $Matches
}

function reset_matches {
    # reset result of previous regular expresssion match via -match option
    if ($Matches -eq $null) {return}
    Write-Verbose "reset_matches before ${Matches}"
    $Matches.Clear()
    Write-Verbose "reset_matches after ${Matches}"
}

function journal_message($text) {
    # add a line to journal file
    Write-Verbose "Write to journal $PSScriptRoot"
    $today = Get-Date -Format "dddd MM\/dd\/yyyy HH:mm:ss K"
    if (os_is_linux) {
        $journal = "$PSScriptRoot/journal.log"
        $disk_space = (df -B1 /var/lib/docker)[1].Split()
        $drive = $disk_space[0]
        $disk_size = $disk_space[1] / 1GB | % {$_.ToString("####.##")}
        $disk_free = $disk_space[3] / 1GB | % {$_.ToString("####.##")}
    }
    else {
        $journal = "$PSScriptRoot\journal.log"
        $drive = "C:"
        $disk_space = @(foreach ($d  in Get-WmiObject -Class Win32_LogicalDisk) {if ($d.DeviceID -eq $drive) {$d.Size, $d.FreeSpace}})
        $disk_size = $disk_space[0] / 1GB | % {$_.ToString("####.##")}
        $disk_free = $disk_space[1] / 1GB | % {$_.ToString("####.##")}
    }
    if (-not (Test-Path $journal)) {
        Write-Verbose "Init journal ${journal}"
        "-------------------------------------------" > $journal
        "Journal file of your projects docker guide " >> $journal
        "-------------------------------------------" >> $journal
    }
    $message = "${today}: Size of drive ${drive}: ${disk_size} GB, free: ${disk_free} GB ($text)"
    Write-Verbose "Write ${message} to journal ${journal}"
    $message >> $journal
}


###############################################################################################
# Classes for configuration purpose
###############################################################################################
class DockerGuideMenue {
    [string] $text
    [int] $dialog

    DockerGuideMenue([string] $text, [int] $dialog) {
        $this.text = $text
        $this.dialog = $dialog
    }
}

class DockerGuideApp {
    [string] $Name
    [string] $Prefix
    [int] $port
    [string] $option
    [int] $rank

    DockerGuideApp([string] $name, [string] $prefix, [int] $port, [string] $option, [int] $rank) {
        $this.Name = $name
        $this.Prefix = $prefix
        $this.port = $port
        $this.option = $option
        $this.rank = $rank
    }
}

class DockerGuideRepo {
    [string] $user
    [string] $name
    [string] $description
    [TagFilterValues] $filter
    [System.Collections.ArrayList] $apps

    DockerGuideRepo([string] $user, [string] $name, [string] $description, [TagFilterValues] $filter, [System.Collections.ArrayList] $apps) {
        $this.user = $user
        $this.name = $name
        $this.description = $description
        $this.filter = $filter
        $this.apps = $apps
    }
}

###############################################################################################
# Base class containing declarations of static constants and methods common to
# ProjectsDockerGuide and DockerInstallAssistance
###############################################################################################
class DockerGuideBase {
    [string] $_proj_name
    [string] $_version
    [string] $_default_distro
    [pscustomobject] $image_keys
    [pscustomobject] $container_keys
    [pscustomobject] $tag_keys
    [pscustomobject] $dialogs
    [pscustomobject] $return_values
    [pscustomobject] $select_mode
    [pscustomobject] $buttons
    [pscustomobject] $icons
    [pscustomobject] $button_pressed

    DockerGuideBase() {
        # dictionaries for keys used in https://registry.hub.docker.com/v2/repositories/
        $this._default_distro = 'DockerForPowershell-0.1'
        $this.image_keys = [ordered]@{
            repo = 'Repository';
            tag = 'Tag';
            id = 'ID';
            created = 'CreatedAt';
            size = 'Size';
        }
        $this.container_keys = [ordered]@{
            name = 'Names';
            id = 'ID';
            image = 'Image';
            created = 'CreatedAt'
            status = 'Status';
            size = 'Size';
        }
        $this.tag_keys = [ordered]@{
            name = 'name';
            full_size = 'full_size';
            id = 'id';
            user = 'last_updater_username';
            updated = 'last_updated';
            last_pulled = 'tag_last_pulled';
            last_pushed = 'tag_last_pushed';
        }
        # dictionaries for dialog handling
        $this.dialogs = [ordered]@{
            distros = 1;
            repos = 2;
            tags = 3;
            images = 4;
            containers = 5;
            apps = 6;
        }
        $this.return_values = @{
            created = 1;
            pulled = 2;
        }
        $this.select_mode = @{
            single = 1;
            multiple = 2;
        }
        # dictionaries for popup-messages
        $this.buttons = @{
            ok = 0;
            ok_cancel = 1;
            abort_ignore_retry = 2;
            yes_no_cancel = 3;
            yes_no = 4;
            retry_cancel = 5;
        }
        $this.icons = @{
            critical = 16;
            question = 32;
            exclamtion = 48;
            information = 64;
        }
        $this.button_pressed = @{
            ok = 1;
            cancel = 2;
            abort = 3;
            retry = 4;
            ignore = 5;
            yes = 6;
            no = 7;
            timeout = -1;
        }
    }

    [pscustomobject] popup_message([string] $text, [int] $button, [int] $icon) {
        $wshell = New-Object -ComObject Wscript.Shell
        $answer = $wshell.Popup($text, 0, $this._proj_name + ' Docker Guide', $button + $icon)
        Write-Verbose "Popup ${answer} ${text}"
        return $answer
    }
}

###############################################################################################
###############################################################################################
# Main Class
###############################################################################################
###############################################################################################

class ProjectsDockerGuide : DockerGuideBase {
    [DockerInstallAssistent] $_install_assist
    [boolean] $_linux
    [boolean] $_ready
    [string] $_path
    [string] $_path_prefix
    [string] $_wsl_distro
    [pscustomobject] $_container
    [pscustomobject] $_tag_lists
    [pscustomobject] $_menues
    [System.Collections.Hashtable] $_port_maps
    [System.Collections.ArrayList] $_proj_repositories
    [System.Collections.ArrayList] $_images
    [System.Collections.ArrayList] $_containers

    ProjectsDockerGuide([string] $project_name, [System.Collections.ArrayList] $project_repositories) {
        # Instatiating the class
        $this._proj_name = $project_name
        $this._version = '0.1'
        $this._install_assist = [DockerInstallAssistent]::new($project_name)
        $this._linux = $false
        $this._port_maps = @{}
        $this._path = "$PWD"
        if (os_is_linux) {
            $this._linux = $true
            $this._path_prefix = $this._path
            if ($this._path_prefix.StartsWith('/')) {
                $this._path_prefix = $this._path_prefix.Substring(1)
            }
            $this._path_prefix = $this._path_prefix.Replace('/', '-')
        }
        else {
            $this._path_prefix = $this._path.Replace(':\', '_').Replace('\', '-')
        }
        Write-Verbose "_path_prefix: $($this._path_prefix)"
        $this._proj_name = $project_name
        $menues = @{
            install = [DockerGuideMenue]::new("Install $($this._default_distro)", $this.dialogs.distros);
            backr = [DockerGuideMenue]::new("Back", $this.dialogs.repos);
            backt = [DockerGuideMenue]::new("Back", $this.dialogs.tags);
            more = [DockerGuideMenue]::new("More", $this.dialogs.tags);
            download = [DockerGuideMenue]::new("Download other software version", $this.dialogs.images);
            del_image = [DockerGuideMenue]::new("Delete a software version", $this.dialogs.images);
            create = [DockerGuideMenue]::new("Create new session", $this.dialogs.containers);
            del_container = [DockerGuideMenue]::new("Delete a session", $this.dialogs.containers);
            bash = [DockerGuideMenue]::new("Work in a bash terminal (advanced)", $this.dialogs.apps);
            lab = [DockerGuideMenue]::new("Work in a Jupyter lab", $this.dialogs.apps);
            notebook = [DockerGuideMenue]::new("Work in a Jupyter notebook", $this.dialogs.apps);
            ipython = [DockerGuideMenue]::new("Work in a IPython terminal (default)", $this.dialogs.apps);
        }
        $this._menues = $menues
        $this._proj_repositories = $project_repositories
        $this.banner()
        $this._ready = $this.start_docker()
    }

    ####################################################################
    # Generic helper methods
    ####################################################################
    [void] banner() {
        $projname = $this._proj_name
        $version = $this._version
        @(
        ""
        "-----------------------------------------------------"
        "| Welcome to the ${projname} Docker Guide version ${version}! |"
        "-----------------------------------------------------"
        ""
        ) | Write-Host -BackgroundColor White -ForegroundColor DarkBlue
    }

    [pscustomobject] show_dialog([System.Collections.ArrayList] $view, [string] $description, [int] $mode) {
        Write-Verbose "show_dialog view $($view | Out-String)"
        Write-Host "Please have a look at the window: ${description}"
        $ans = $null
        try {
            $ans = $view | Out-GridView -Title $description -OutputMode $mode
        }
        catch [System.Management.Automation.CommandNotFoundException] {
            $ans = $view | Out-ConsoleGridView -Title $description -OutputMode $mode
        }
        Write-Verbose "show_dialog_view answer $($ans | Out-String)"
        return $ans
    }

    [boolean] check_proj_image([string] $img) {
        $proj_reps = @(foreach ($r in $this._proj_repositories) {
            "$($r.user)/$($r.name)"
        })
        if ($img -in $proj_reps) {
            return $true
        }
        return $false
    }

    [System.Collections.ArrayList] dialog_menue([int] $dialog) {
        return @(foreach ($m in $this._menues.values) {if ($m.dialog -eq $dialog) {$m.text}})
    }

    [DockerGuideRepo] image_to_repo([pscustomobject] $image) {
        Write-Verbose "Entering image_to_repo for $($image | Out-String)"
        $repo = $image.($this.image_keys.repo)
        $rep = $repo.Split("/")
        $user = $rep[0]
        $name = $rep[1]
        foreach ($r in $this._proj_repositories) {
            if ($r.user -eq $user -and $r.name -eq $name) {
                Write-Verbose "Leaving image_to_repo for $($image | Out-String) with $($r | Out-String)"
                return $r
            }
        }
        Write-Verbose "Leaving image_to_repo for $($image | Out-String) without result"
        return $null
    }

    [System.Collections.ArrayList] image_to_apps([pscustomobject] $image) {
        Write-Verbose "Entering image_to_apps for $($image | Out-String)"
        $repo = $this.image_to_repo($image)
        $apps = $repo.apps
        if ($apps.Count -eq 0) {
            $apps = @([DockerGuideApp]::new("Default", "X-", 0, "", 0))
        }
        Write-Verbose "Leaving image_to_apps for $($image | Out-String) with $($apps | Out-String)"
        return $apps
    }

    [pscustomobject] container_to_image([pscustomobject] $container) {
        Write-Verbose "Entering container_to_image for $($container | Out-String)"
        $img = $container.($this.container_keys.image)
        $imgs = $this.find_images()
        foreach ($i in $imgs) {
            $repo = $i.($this.image_keys.repo)
            $tag = $i.($this.image_keys.tag)
            if ($img -eq "${repo}:${tag}") {
                Write-Verbose "Leaving container_to_image for $($container | Out-String) with $($i | Out-String)"
                return $i
            }
        }
        Write-Verbose "Leaving container_to_image for $($container | Out-String) without result"
        return $null
    }

    [DockerGuideApp] container_to_app([pscustomobject] $container) {
        Write-Verbose "Entering container_to_app for $($container | Out-String)"
        $img = $this.container_to_image($container)
        if (-not $img) {return $null}
        $apps = $this.image_to_apps($img)
        if ($apps.Count -gt 1) {
            $name = $container.($this.container_keys.name)
            foreach ($app in $apps) {
                if ($name.StartsWith($app.Prefix)) {
                    Write-Verbose "Leaving container_to_image for $($container | Out-String) with $($app | Out-String)"
                    return $app
                }
            }
        }
        $app = $apps[0]
        Write-Verbose "Leaving container_to_image for $($container | Out-String) with default $($app | Out-String)"
        return $app
    }

    [pscustomobject] select_from_list([System.Collections.ArrayList] $items,
                                      [System.Collections.ArrayList] $cols,
                                      [System.Collections.ArrayList] $menue,
                                      [string] $title
                                     ) {
        # Return one image from the list according to user choice
        $proj_name = $this._proj_name
        Write-Verbose "Entering: select_from_list $title"
        $description = "${proj_name} Docker Guide: $title Please select the line of your choice!"
        $view = @(echo $items | select $cols)
        $mkeys = @()
        foreach ($m in $menue) {
            if ($cols.Count -eq 0) {
                $view += $m
                continue
            }
            $mline = echo @($items[0]) | select $cols  # copy of first line
            foreach ($key in $cols) {
                if ($cols.IndexOf($key) -eq 0) {
                    $mline.$key = $m
                    $mkeys += $key
                }
                else {
                    $mline.$key = ""
                }
            }
            $view += $mline
        }
        Write-Verbose "mkeys $($mkeys | Out-String)"
        $ans = $this.show_dialog($view, $description, $this.select_mode.single)
        if (-not $ans) {
            Write-Verbose "select_from_list $title canceled"
            return $null
        }
        else {
            foreach ($m in $menue) {
                $ind = $menue.IndexOf($m)
                $col = $mkeys[$ind]
                if ($ans.$col -eq $m) {
                    Write-Verbose "Leaving: select_from_list $title with $m"
                    return $m
                }
            }
        }
        Write-Verbose "Leaving: select_from_list $title with $ans"
        return $ans
    }

    [System.Collections.ArrayList] search_tags([pscustomobject] $repo) {
        # search tags for the given repository on Docker Hub
        $uri = "https://registry.hub.docker.com/v2/repositories/$($repo.user)/$($repo.name)/tags/?page_size=250"
        Write-Verbose "Invoke-WebRequest ${uri}"
        $result = Invoke-WebRequest -UseBasicParsing -Uri $uri
        $JsonObject = ConvertFrom-Json -InputObject $result.Content
        $res = $JsonObject.results
        # filter the result
        $new_res = @()
        foreach ($t in $res) {
            if ($t.name.Contains('latest') -or $t.name.Contains('develop')) {
                continue
            }
            if ($repo.filter -eq [TagFilterValues]::pre) {
                if ($t.name.Contains('beta') -or $t.name.Contains('rc')) {
                    $new_res += $t
                }
            }
            elseif ($repo.filter -eq [TagFilterValues]::stable) {
                if (-not ($t.name.Contains('beta') -or $t.name.Contains('rc'))) {
                    $new_res += $t
                }
            }
            else {
                $new_res += $t
            }
        }
        return $new_res
    }

    [DockerGuideApp] select_app($apps) {
        # Return one tag from the repository
        $title = "List of different applications to work with $($this._proj_name)."
        $app_names = $apps[0].psobject.Properties.Name
        $cols = @($app_names[0], $app_names[1])
        $view = @(echo $apps | select $cols)
        $description = "$($this._proj_name) Docker Guide: $title Please select the line of your choice!"
        $ans = $this.show_dialog($view, $description, $this.select_mode.single)
        foreach ($app in $apps) {
            if ($app.Name -eq $ans.Name) {
                Write-Verbose "Selected app: $($app | Out-String)"
                return $app
            }
        }
        Write-Verbose "No Selection $($ans | Out-String)"
        return $null
    }

    [pscustomobject] select_wsl_distro($distros) {
        # Return wsl distribution
        $menue = $this.dialog_menue($this.dialogs.distros)
        $title = "List of WSL distros that have Docker available."
        return $this.select_from_list($distros, @(), $menue, $title)
    }

    [pscustomobject] select_repo() {
        # Return a repository
        $repos = $this._proj_repositories
        $cols = $repos[0].psobject.properties.name
        $menue = $this.dialog_menue($this.dialogs.repos)
        $title = "List of software that can be downloaded."
        return $this.select_from_list($repos, $cols, $menue, $title)
    }

    [pscustomobject] select_tag([pscustomobject] $repo) {
        # Return one tag from a repository
        $tags = $this.search_tags($repo)
        $cols = $($this.tag_keys.Values)
        $menue = $this.dialog_menue($this.dialogs.tags)
        $title = "List of software versions that can be downloaded."
        return $this.select_from_list($tags, $cols, $menue, $title)
    }

    ####################################################################
    # Methods to choose an image
    ####################################################################
    [System.Collections.ArrayList] find_images() {
        # Find all images
        return $this.find_images($false)
    }

    [System.Collections.ArrayList] find_images([bool] $refresh) {
        # Find all images
        if ($this._images -and -not $refresh) {
            return $this._images
        }
        $lines = $this.docker("images --format json")
        Write-Verbose "docker images: $($lines | Out-String)"
        $this._images = [System.Collections.ArrayList]@(foreach ($line in $lines) {
            $json = $line | ConvertFrom-Json
            $json
        })
        Write-Verbose "Images found: $($this._images | Out-String)"
        return $this._images
    }

    [System.Collections.ArrayList] find_proj_images() {
        # Filter the list of containers for the project
        $proj_images = [System.Collections.ArrayList]@()
        if (-not $this._images) {
            $this.find_images()
        }
        foreach ($i in $this._images) {
        $irep = $i.($this.image_keys.repo)
            if ($this.check_proj_image($irep)) {
                $proj_images.Add($i) | Out-Null
            }
        }
        return $proj_images
    }

    [pscustomobject] choose_image() {
        # Return the Image for which a new container should be started
        Write-Verbose "Entering choose image"
        do {
            $images = $this.find_proj_images()
            $i = $images.Count
            if ($i -eq 0) {
                $ans = $this.pull_images()
                if ($ans -eq $this.return_values.pulled) {
                    continue
                }
                elseif ($this._menues.backr.text -eq $ans) {
                    continue
                }
                else {
                    return $ans
                }
            }
            $ans = $this.select_image($images)

            if ($this._menues.download.text -eq $ans) {
                $ans = $this.pull_images()
                if ($ans -eq $this.return_values.pulled) {
                    continue
                }
                elseif ($this._menues.backr.text -eq $ans) {
                    continue
                }
                else {
                    return $ans
                }
            }
            elseif ($this._menues.del_image.text -eq $ans) {
                $this.delete_images($images)
                continue
            }
            else {
                return $ans
            }
        } while ($true)
        
    return $null
    }

    [pscustomobject] select_image([System.Collections.ArrayList] $images) {
        # Return one image from the list according to user choice
        $cols = $($this.image_keys.Values)
        $menue = $this.dialog_menue($this.dialogs.images)
        $title = "List of software versions that have been downloaded."
        return $this.select_from_list($images, $cols, $menue, $title)
    }

    [pscustomobject] pull_images() {
        # Return the Image for which a new container should be started
        Write-Verbose "Entering: pull images"
        do {
            $repo = $this.select_repo()
            if ($repo -eq $null) {
                return $null
            }
            if ($this._menues.backr.text -eq $repo) {
                Write-Verbose "Repo cmd $($repo | Out-String)"
                return $repo
            }
            $tag = $this.select_tag($repo)
            if ($tag -eq $null) {
                return $null
            }
            if ($this._menues.backt.text -eq $tag) {
                Write-Verbose "Tag cmd $($tag | Out-String)"
                continue
            }
            $this.pull_image($repo, $tag)
            $this._images = $null
            return $this.return_values.pulled
        } while ($true)
        return $null
    }

    [void] delete_images([System.Collections.ArrayList] $images) {
        # Return a list of images that should be deleted
        $proj_name = $this._proj_name
        $description = "${proj_name} Docker Guide: List of software that have been used formerly. Please select the lines you want to remove!"
        $cols = $($this.image_keys.Values)
        $view = @(echo $images | select $cols)
        $list = $this.show_dialog($view, $description, $this.select_mode.multiple)
        if (-not $list) {
            return
        }
        foreach ($i in $list) {
            Write-Verbose "Delete $($i | Out-String)"
            $this.delete_image($i)
        } 
        return
    }

    ####################################################################
    # Methods to choose a container
    ####################################################################
    [System.Collections.ArrayList] find_containers() {
        # Find all containers
        return $this.find_containers($false)
    }

    [System.Collections.ArrayList] find_containers([bool] $refresh) {
        # Find all containers
        if ($this._containers -and -not $refresh) {
            return $this._containers
        }
        $lines = $this.docker("ps -a --format json")
        Write-Verbose "docker ps: $($lines | Out-String)"
        $this._containers = [System.Collections.ArrayList]@(foreach ($line in $lines) {
            $json = $line | ConvertFrom-Json
            $json
        })
        Write-Verbose "Containers found: $($this._containers | Out-String)"
        return $this._containers
    }

    [System.Collections.ArrayList] find_proj_containers() {
        # Filter the list of containers for the project
        return $this.find_proj_containers($false)
    }

    [System.Collections.ArrayList] find_proj_containers([bool] $matching) {
        # Filter the list of containers for the project
        $proj_containers = [System.Collections.ArrayList]@()
        if (-not $this._containers) {
            $this.find_containers()
        }
        foreach ($c in $this._containers) {
            $this.get_container_port($c)
            $cim = $c.($this.container_keys.image)
            $ci = $cim -split ":" # cut off the tag
            $img = $ci[0]
            if ($this.check_proj_image($img)) {
                $cn =  $c.($this.container_keys.name)
                if ($matching -and -not $cn.Contains($this._path_prefix)) {
                    Write-Verbose "Container ${cim} does not match $($this._path_prefix)"
                    continue
                }
                $proj_containers.Add($c) | Out-Null
            }
        }
        return $proj_containers
    }

    [int] get_container_port([pscustomobject] $c) {
        $ports = $c.Ports
        if ($ports -eq "") {
            return 0
        }
        Write-Verbose "Ports ${ports}"
        if ($ports -match ":([0-9]*)-" -eq $true) {
            $m = get_matches
            Write-Verbose "match $($m | Out-String), $($m.Count)"
            $p = [int] $m[1]
            $cn = $c.($this.container_keys.name)
            Write-Verbose "port for ${cn}: $($p)"
            $this._port_maps[$cn] = $p
            return $p
        }
        return 0
    }

    [int] find_free_port([string] $start_port) {
        $s = [int] $start_port
        $p = $s
        foreach ($c in $this._containers) {
           $app = $this.container_to_app($c)
           if ($app -and $app.port -eq $s) {
               $p += 1
           }
        }
        Write-Verbose "Free port ${p} found for $($start_port)"
        return $p
    }

    [pscustomobject] choose_container() {
        # Return the Container that should be started
        Write-Verbose "Entering: choose container"
        $matching_containers = $this.find_proj_containers($true)
        $l = $matching_containers.Count
        if ($l -eq 0) {
            $containers = $this.find_proj_containers()
            $k = $containers.Count
            if (-not $k) {
                $img = $this.choose_image()
                if ($img -eq $null) {
                    return $null
                }
                $this.create_container($img)
                return $this.return_values.created
            }
            else {
                Write-Host "No session belongs to the current directory $($this._path)!"
                return $this.select_container($containers)
            }
        }
        else {
            return $this.select_container($matching_containers)
        }
    }

    [pscustomobject] select_container([System.Collections.ArrayList] $containers) {
        # Return one container from the list according to user choice
        $cols = $($this.container_keys.Values)
        $menue =  $this.dialog_menue($this.dialogs.containers)
        $title = "List of sessions that have been used or created formerly."
        return $this.select_from_list($containers, $cols, $menue, $title)
    }

    [void] delete_containers([System.Collections.ArrayList] $containers, [string] $purpose) {
        # Return a list of containers that should be deleted
        $proj_name = $this._proj_name
        $description = "${proj_name} Docker Guide: ${purpose}Please select the lines you want to remove!"
        $cols = $($this.container_keys.Values)
        $view = @(echo $containers | select $cols)
        $list = $this.show_dialog($view, $description, $this.select_mode.multiple)
        if (-not $list) {
            return
        }
        foreach ($c in $list) {
            Write-Verbose "Delete $($c | Out-String)"
            $this.delete_container($c)
        } 
        return
    }

    ####################################################################
    # Methods that directly access Docker
    ####################################################################
    [string] docker_str([string] $arguments) {
        $d = $this._wsl_distro
        if ($d) {
            $cmd = "wsl -d $d -e docker $arguments"
        }
        else {
            $cmd = "docker $arguments"
        }
        Write-Verbose "Command to call Docker: $cmd"
        return $cmd
    }

    [pscustomobject] docker([string] $arguments) {
        $cmd = $this.docker_str($arguments)
        Write-Verbose "Invoke Docker with: $cmd"
        return Invoke-Expression $cmd
    }

    [void] start_daemon() {
        Write-Host "The Docker daemon is not running but will be started now"
        $d = $this._wsl_distro
        $def = $this._default_distro.Split('-')[0] # version independent part
        if (-not $d) {
            if ($this._linux) {
                Write-Host "Your admin authentication is needed to start the Docker daemon!"
                sudo service docker start
                Write-Verbose "Starting Docker daemon"
                return
            }
            # share using Docker Desktop
            $cmd = 'C:\Program Files\Docker\Docker\resources\dockerd.exe' # must be started with 'Start-Process -Verb runAs' and than only listens to admin
            $cmd = 'C:\Program Files\Docker\Docker\Docker Desktop.exe'
            Start-Process $cmd
            Write-Verbose "Starting Docker Desktop with $cmd"
        }
        elseif ($d.StartsWith($def)) {
            # default distro
            wsl -d $d -e sh /root/start_dockerd
            Write-Verbose "Starting Docker daemon in default WSL-distro $d"
        }
        else {
            # others with fingers crossed
            Write-Host "Your admin authentication is needed to start the Docker daemon!"
            wsl -d $d -e sudo service docker start
            Write-Verbose "Starting Docker daemon in WSL-distro $d"
        }
    }

    [boolean] daemon_down() {
        $test = $this.docker("ps") -join ' ' | Out-String
        Write-Verbose "Test if Docker daemon s up with ps gives '$test'"
        if (-not $test) {
            return $true
        }
        return -not $test.Contains('CONTAINER ID')
    }

    [void] run_install_assist() {
        $distro = $this._default_distro
        $text = "${distro} is not available on your system, but needed for this software! Shall we install it?"
        $answer = $this.popup_message($text, $this.buttons.yes_no, $this.icons.information)
        if ($answer -eq $this.button_pressed.yes) {
            $this._install_assist.run()
        }
    }

    [boolean] set_wsl_distro() {
        if ($this._linux) {return $true}
        $test_wsl = wsl --status
        if ($test_wsl -eq $null) {
            $this.run_install_assist()
            return $false
        }
        elseif (($test_wsl -join ' ' | Out-String).Contains('WSL_E_WSL_OPTIONAL_COMPONENT_REQUIRED')) {
            $this._install_assist.reboot()
            return $false
        }
        $def = $this._default_distro.Split('-')[0] # version independent part
        $distributions = wsl -l -q | Sort-Object -Descending 

        $docker_desktop = $null
        $default = $null
        $docker_distros = @()
        foreach ($d in $distributions) {
            if ($d -eq "") {
                continue
            }
            if ($d -eq "docker-desktop") {
                Write-Verbose "Docker Desktop is present"
                $docker_desktop = $d
                $docker_distros += $d
                continue
            }              
            elseif ($d.StartsWith($def)) {
                Write-Verbose "$def is present: $d"
                $default = $d
                $docker_distros += $d
                continue
            }
            else {
                $test_distro = wsl -d $d -e docker info
                Write-Verbose "Test WSL distro $d gives '$test_distro'"
                if ($test_distro.StartsWith('Client')) {
                    $distro = $d
                    Write-Verbose "Use WSL distro: $distro"
                    $docker_distros += $d
                }
            }
        }

        $distro = $null
        if ($docker_distros.Count -eq 1)
        {
            if ($docker_distros[0] -eq $default) {
                $distro = $default
            }
            elseif ($docker_distros[0] -ne $docker_desktop) {
                $distro = $docker_distros[0]
                $text = "Docker is available on your system in the WSL-distribution $distro. Shall we share its usage?"
                $answer = $this.popup_message($text, $this.buttons.yes_no, $this.icons.information)
                if ($answer -ne $this.button_pressed.yes) {
                    return $false
                }
            }
        }
        elseif ($docker_distros.Count -gt 1)
        {
            if ($default) {
                $distro = $default
            }
            else
            {
                $answer = $this.select_wsl_distro($docker_distros)
                if (-not $answer) {return $false}
                if ($answer -eq $this._menues.install.text) {
                    $this.run_install_assist()
                    $distro = $default
                    return $true
                }
                $distro = $answer
            }
        }

        if ($distro -eq $null) {
            try {
                docker
                if ($docker_desktop) {
                    $text = "Docker Desktop is available on your system. Shall we share its usage?"
                    $answer = $this.popup_message($text, $this.buttons.yes_no, $this.icons.information)
                    if ($answer -ne $this.button_pressed.yes) {
                        return $false
                    }
                }
            }
            catch [System.Management.Automation.CommandNotFoundException] {
                $this.run_install_assist()
                return $false
            }
        }

        $this._wsl_distro = $distro
        return $true
    }

    [boolean] start_docker() {
        if (-not $this.set_wsl_distro()) {
            return $false
        }
        if ($this.daemon_down()) {
            $this.start_daemon()
        }
        while ($this.daemon_down()) {
            $text = 'Please wait until the Docker engine is running!'
            if (-not $this._wsl_distro) {
                $text = $text + 'As soon as this message does not appear any more, you may close the Docker Desktop app.'
            }
            $answer = $this.popup_message($text, $this.buttons.retry_cancel, $this.icons.information)
            if ($answer -ne $this.button_pressed.retry) {
                return $false
            }
            Write-Verbose "Start Docker $($answer | Out-String)"
        }
        return $true
    }

    [void] pull_image([pscustomobject] $repo, [pscustomobject] $tag) {
        # pull image
        $ruser = $repo.user
        $rname = $repo.name
        $tname = $tag.($this.tag_keys.name)
        $name = "${ruser}/${rname}:${tname}"
        Write-Host "Download of ${name} starts!"
        $cmd = $this.docker_str("pull $($name)")
        $argu = "/c " + $cmd
        Write-Verbose "docker pull: ${argu}"
        journal_message "before $cmd"
        Start-Process -FilePath cmd -ArgumentList $argu -Wait
        journal_message "after $cmd"
    }

    [void] delete_image([pscustomobject] $i) {
        # delete an image
        $rep = $i.($this.image_keys.repo)
        $tag = $i.($this.image_keys.tag)
        $name = "${rep}:${tag}"
        Write-Host "Try to delete ${name}"
        $cont_to_delete = @()
        foreach ($c in $this._containers) {
            if ($c.($this.container_keys.image) -eq $name) {
            $cont_to_delete += $c
            }
        }
        Write-Verbose "cont_to_delete $($cont_to_delete | Out-String)"
        if ($cont_to_delete.Count -eq 0) {
            journal_message "before deleting ${name}"
            $this.docker("rmi ${name}")
            journal_message "after deleting ${name}"
            Write-Host "The software ${name} has been deleted!"
            # remove it from the list
            $this._images = @($this._images | Where-Object {$i.($this.image_keys.id) -ne $_.($this.image_keys.id)})
            Write-Verbose "Images Count $($this._images.Count)"
        }
        else {
            Write-Host "There are containers for ${name} which must be deleted first!"
            $this.delete_containers($cont_to_delete, "List of sessions that must be deleted, to delete ${name}. ")
        }
    }

    [string] find_new_container_name([DockerGuideApp] $app) {
        # Rename Container to path
        Write-Verbose "Entering: find new container name"
        $base = $($app.Prefix) + $this._path_prefix
        $occupied = @()
        foreach ($c in $this._containers) {
            $cname = $c.($this.container_keys.name)
            if ($cname.Contains($base)) {
               $occupied += $cname
            }
        }
        Write-Verbose "occupied $($occupied | Out-String)"
        $i = 0
        do {
            if ($i -eq 0) {
                $name = ${base}
            }
            else {
                $name = "${base}_${i}"
            }
            $i += 1
        } while ($name -in $occupied)
        Write-Verbose "occupied $($occupied | Out-String)"
        Write-Verbose "new name ${name}"
        return $name
    }

    [void] create_container([pscustomobject] $image) {
        # create a new container
        $repo = $image.Repository
        $tag = $image.Tag
        Write-Host "Create a new container for ${repo}:${tag}"
        $port = ""
        $option = ""
        $apps = $this.image_to_apps($image)
        $app = $apps[0]
        if ($apps.Count -gt 1) {
            $app = $this.select_app($apps)
            if ($app -eq $null) {
                return
            }
        }
        $p = $this.find_free_port($app.port)
        if ($p -eq 0) {
            $port = ""
        }
        else {
            $port = " -p $($p):8888"
        }
        $option = " $($app.option)"
        $name = $this.find_new_container_name($app)
        $spwd = "$PWD"
        if ($this._wsl_distro) {
            $spwd = $spwd.Replace('C:', '/mnt/c').Replace('\', '/')
        }
        $tpwd = "/home/" + $name
        journal_message "before creating ${name}"
        $this.docker("create -it --mount `"type=bind,src=$($spwd),target=$($tpwd)`" --name $($name) -w $($tpwd)$($port) $($repo):$($tag)$($option)")
        journal_message "after creating ${name}"
        $this._port_maps[$name] = $p
        $this._containers = $null  # to refresh the list
    }

    [void] delete_container([pscustomobject] $c) {
        # delete a container
        $id = $c.($this.container_keys.id)
        $name = $c.($this.container_keys.name)
        Write-Host "Delete container ${name} (id ${id})"
        journal_message "before deleting ${name} (id ${id})"
        $this.docker("stop ${id}")
        $this.docker("rm ${id}")
        journal_message "after deleting ${name} (id ${id})"
        # remove it from the list
        $this._containers = @($this._containers | Where-Object {$id -ne $_.($this.container_keys.id)})
        Write-Verbose "Containers Count $($this._containers.Count)"
    }

    [void] attach_container() {
        # attach to an existing container
        $c = $this._container
        $id = $c.($this.container_keys.id)
        $name = $c.($this.container_keys.name)
        $app = $this.container_to_app($c)
        $ports = $this._port_maps
        $port_a = $app.port
        $port_m = $ports[$name]
        Write-Host "Attach container ${name} (id ${id})"
        $this.docker("start $($id)")
        if ($port_a -gt 0) {
            Write-Verbose "Use port $($port_m | Out-String) from mapping list $($ports | Out-String)"
            $cmd = $this.docker_str("logs $($id)")
            reset_matches
            $url = ""
            $port = ""
            $tok = ""
            $match_str = "http\://127\.0\.0\.1\:([8-9][0-9]{3})\/.*\?token=([a-z,0-9]*)"
            Write-Verbose "match_str ${match_str}"
            do {
                $log_lines = Invoke-Expression $cmd
                if ($log_lines.Count -eq 0) {
                    continue
                }
                [array]::Reverse($log_lines) # Revert the log-lines to not use older token
                $logs = $log_lines | Out-String
                Write-Verbose "Logs ${logs}"
                if ($logs -match $match_str) {
                    $m = get_matches
                    Write-Verbose "match $($m | Out-String), $($m.Count)"
                    $url = $m[0]
                    $port = $m[1]
                    $tok = $m[2]
                }
            } while ($tok -eq "")
            $url = $url.Replace(":$($port_a)", ":$($port_m)")
            Write-Host "Please have a look at your browser at a tab with URL: ${url}"
            Start-Process $url
        }
        else {
            $cmd = $this.docker_str("attach $($id)")
            if ($this._linux) {
                $argu = "-x " + $cmd
            }
            else {
                $argu = "/c " + $cmd
            }
            Write-Verbose "docker attach: ${argu}"
            Start-Process -FilePath cmd -ArgumentList $argu -Wait
        }
    }

    ####################################################################
    # Entrypoint to app
    ####################################################################
    [void] run() {
        if (-not $this._ready) {
            $text = 'Docker is not available on your system, yet! Try again later on.'
            $this.popup_message($text, $this.buttons.ok, $this.icons.information)
            return
        }
        do {
            $this._container = $this.choose_container()
            Write-Verbose "Container Choice: $($this._container | Out-String)"
            if ($this._container -eq $this.return_values.created) {
                Write-Verbose "Just created a conrainer, now search it."
                continue
            }
            elseif ($this._menues.create.text -eq $this._container) {
                $image = $this.choose_image()
                if ($image -ne $null) {
                    $this.create_container($image)
                }
                Write-Verbose "Just created a container here, now search it."
                continue
            }
            elseif ($this._menues.del_container.text -eq $this._container) {
                $this.delete_containers($this._containers, "List of sessions that have been used formerly. ")
                Write-Verbose "After deletion of containsers, now search again."
                continue
            }
            elseif ($this._container -eq $null) {
                Write-Verbose "No container chosen, now finish."
                Write-Host "Good bye!"
                return
            }
            elseif (-not $($this._container.($this.container_keys.name)).Contains($this._path_prefix)) {
                $c = $this._container
                Write-Verbose "$($c.Names) does not contain $($this._path_prefix)"
                $text = "The choosen session does not belong to the current folder $($this._path)! Start in anyway?"
                $answer = $this.popup_message($text, $this.buttons.yes_no, $this.icons.information)
                if ($answer -ne $this.button_pressed.yes) {
                    continue
                }
            }
            $this.attach_container()
        } while ($true)
    }
}


###############################################################################################
# Helper class to assist the Installation of Docker Desktop
###############################################################################################
class DockerInstallAssistent : DockerGuideBase {

    DockerInstallAssistent([string] $project_name) {
        $this._proj_name = $project_name
    }

    [void] banner() {
        $app_name = $this._proj_name + " Docker Guide"
        @(
        "                                                          "
        " Docker For Powershell will now be installed!             "
        "                                                          "
        " This also needs the Windows Subsystem for Linux (WSL)    "
        "                                                          "
        " If you didn't use this before on your computer it might  "
        " be necessary to install this too.                        "
        "                                                          "
        " In this case you will be asked to reboot your computer.  "
        " Afterwards, to finish the instalation start              "
        " ${app_name} again.                                "
        ) | Write-Host -BackgroundColor White -ForegroundColor Red
    }

    [void] reboot() {
        Write-Verbose "Restart Computer"
        $app_name = $this._proj_name + " Docker Guide"
        $text = "Your Computer must be restarted to complete the current installation step. After this is finished start ${app_name} again to continue."
        $answer = $this.popup_message($text, $this.buttons.ok_cancel, $this.icons.information)
        if ($answer -ne $this.button_pressed.ok) {
            return
        }
        Restart-Computer
    }

    [void] run() {
        $distro = $this._default_distro
        Write-Verbose "${distro} will now be installed!"
        $this.banner()
        $text = "${distro} installation starts now. Maybe your computer must be rebooted during the process. Continue?"
        $answer = $this.popup_message($text, $this.buttons.yes_no, $this.icons.information)
        if ($answer -ne $this.button_pressed.yes) {
            return
        }
        $version = $distro.split('-')[1]
        $url_templ = "https://github.com/soehms/docker_for_powershell/releases/download/VER/docker_for_powershell-VER-installer.ps1"
        $url = $url_templ.Replace('VER', $version)
        Write-Verbose "URL: ${url}"
        $file = "docker_for_powershell-installer.ps1"
        Write-Verbose "File: ${file}"
        $web_client = New-Object System.Net.WebClient
        Write-Host "Download the ${distro} installer"
        $web_client.DownloadFile($url, $file)
        Write-Host "Install ${distro}"
        $argu = "Set-ExecutionPolicy Bypass -Scope  Process -Force; .\docker_for_powershell-installer.ps1"
        Start-Process -Wait powershell -ArgumentList $argu
        del $file
    }
}
