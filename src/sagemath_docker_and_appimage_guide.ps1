##############################################################################
#       Copyright (C) 2026 Sebastian Oehms <seb.oehms@gmail.com>
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 2 of the License, or
# (at your option) any later version.
#                  http://www.gnu.org/licenses/
##############################################################################


Using module .\proj_docker_guide.psm1

###############################################################################################
# Project specific configuration
###############################################################################################

$ipython = [DockerGuideApp]::new("Work in a Sage customized IPython terminal (default)", "S-", 0, "", 1)
$notebook = [DockerGuideApp]::new("Work in a Jupyter notebook", "N-", 8888, "-n", 2)
$lab = [DockerGuideApp]::new("Work in Jupyter lab", "L-", 8888, " -n jupyterlab", 3)
$bash = [DockerGuideApp]::new("Work in a bash terminal (advanced)", "B-", 0, "", 4)
$notebook_docker = [DockerGuideApp]::new("Work in a Jupyter notebook", "N-", 8888, "sage-jupyter", 2)
$lab_docker = [DockerGuideApp]::new("Work in Jupyter lab", "L-", 8888, "sage-jupyterlab", 3)

$all_apps = @($ipython, $notebook_docker, $lab_docker, $bash)
$all_apps = @($ipython, $notebook_docker) # lab and bash not functional, yet
$bash_app = @($bash)
$appimage = @($ipython, $notebook, $lab)


$sagemath_repositories = @(
    [DockerGuideRepo]::new("sagemath", "sagemath", "Repository for inexperienced users, ony stable releases (default)", [RepoHost]::docker_hub, [TagFilterValues]::stable, $all_apps),
    [DockerGuideRepo]::new("3-manifolds", "sage_appimage", "SageMath App for inexperienced, only stable releases", [RepoHost]::github, [TagFilterValues]::all, $appimage),
    [DockerGuideRepo]::new("sagemath", "sagemath", "Repository for inexperienced users, only pre-releases", [RepoHost]::docker_hub, [TagFilterValues]::pre, $all_apps),
    [DockerGuideRepo]::new("sagemathinc", "cocalc-docker", "Repository for experienced users, Cocalc version)", [RepoHost]::docker_hub, [TagFilterValues]::all, $bash_app),
    [DockerGuideRepo]::new("computop", "sage", "Repository for experienced users, featuring geometric topology", [RepoHost]::docker_hub, [TagFilterValues]::all, $bash_app),
    [DockerGuideRepo]::new("sagemath", "sagemath-dev", "Repository for development (advanced)", [RepoHost]::docker_hub, [TagFilterValues]::all, $bash_app)
)


$sagemath_docker_guide = [ProjectsDockerGuide]::new("SageMath", $sagemath_repositories)
$sagemath_docker_guide.run()
