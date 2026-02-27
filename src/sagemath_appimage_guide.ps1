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

$appimage = @($ipython, $notebook, $lab)


$sagemath_repositories = @(
    [DockerGuideRepo]::new("3-manifolds", "sage_appimage", "SageMath App for inexperienced, only stable releases", [RepoHost]::github, [TagFilterValues]::all, $appimage)
)


$sagemath_docker_guide = [ProjectsDockerGuide]::new("SageMath", $sagemath_repositories)
$sagemath_docker_guide.run()
