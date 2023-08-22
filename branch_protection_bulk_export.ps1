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
#.Parameter filepath
#   Specifies the path to a file that contains the names of the repositories to export. Each repository name should be on a separate line.
#.Parameter -outputdirectory
#   Specifies the path to a directory where the generated policy files are created.
#>

Param(
    [parameter(Mandatory = $true)] [String] $repoowner,
    [parameter(Mandatory = $true)] [String] $filepath,
    [parameter(Mandatory = $false)] [String] $outputdirectory = "."
)

if (!(Test-Path $filepath -PathType Leaf -IsValid)) {
    Write-Error "The path $filepath is invalid."
    exit 1
}

if (!(Test-Path $outputdirectory -PathType Leaf -IsValid)) {
    Write-Error "The path $outputdirectory is invalid."
    exit 1
}

foreach($repo in [System.IO.File]::ReadLines($filepath))
{
    & .\branch_protection_export.ps1 -repoowner $repoowner -reponame $repo -outputdirectory $outputdirectory
    Write-Host "Exported branch protection rules for $repo"
}