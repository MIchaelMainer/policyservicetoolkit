# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

#<#
#.Synopsis
#   Bulk exports the branch protection rules for many repositories as a policy service yaml file
#
#.Description
#   This script uses the GitHub CLI. You should sign in with the CLI before running this script.
#
#.Parameter repoowner
#   Specifies the organization owner of the repos. This is the organization name, not the organization ID.
#.Parameter reponame
#   Specifies the path to a file that contains the names of the repositories to export. Each repository name should be on a separate line.
#>

Param(
    [parameter(Mandatory = $true)] [String] $repoowner,
    [parameter(Mandatory = $true)] [String] $filepath
)

if (!(Test-Path $filepath -PathType Leaf -IsValid)) {
    Write-Error "The file path is invalid."
    exit 1
}

foreach($repo in [System.IO.File]::ReadLines($filepath))
{
    & .\branch_protection_export.ps1 -repoowner $repoowner -reponame $repo
}