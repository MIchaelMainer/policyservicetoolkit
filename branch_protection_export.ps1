# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

#<#
#.Synopsis
#   Exports the branch protection rules as a policy service yaml file
#
#.Description
#   This script uses the GitHub CLI. You should sign in with the CLI before running this script.
#
#.Parameter repoowner
#   Specifies the organization owner of the repo."
#.Parameter reponame
#   Specifies the repo to target.
#.Parameter outputdirectory
#   Specifies the path to a directory where the generated policy file is created.
#.Parameter outputresponse
#   Switch that indicates whether we should  output the raw json response to the console without writing a branch protection policy file.
#>

Param(
    [parameter(Mandatory = $true)] [String] $repoowner,
    [parameter(Mandatory = $true)] [String] $reponame,
    [parameter(Mandatory = $false)] [String] $outputdirectory = ".",
    [parameter(Mandatory = $false)] [switch] $outputresponse
)

# Check whether the output directory exists
if (!(Test-Path $outputdirectory -PathType Container)) {
    #Check whether the syntax is valid.
    if (Test-Path $outputdirectory -PathType Container -IsValid) {
        # Create the output directory
        New-Item -Path $outputdirectory -ItemType Directory -Force | Out-Null
    } else {
        Write-Error "The `$outputdirectory path is invalid syntax."
        exit 1
    }
}

# Setting local variable so that it can be injected into the template
$reponame = $reponame

# GraphQL query to get the branch protection rules
# https://docs.github.com/en/graphql/reference/objects#branchprotectionrule
$JsonContent = & "gh" api graphql -H 'X-Github-Next-Global-ID: 1' -F owner="$repoowner" -F name="$reponame" -f query='
    query($name: String!, $owner: String!) {
        repository(owner: $owner, name: $name) {
            branchProtectionRules(first: 100) {
                nodes {
                    matchingRefs(first: 100) {
                    nodes {
                        name
                    }
                }
                pattern
                allowsDeletions
                allowsForcePushes
                dismissesStaleReviews
                reviewDismissalAllowances(first: 100) {
                    nodes {
                        actor {
                        ... on App {
                          id
                          name
                          slug
                        }
                        ... on Team {
                          id
                          name
                          slug
                        }
                        ... on User {
                          id
                          name
                          login
                        }
                      }
                    }
                  }
                isAdminEnforced
                pushAllowances(first: 100) {
                    nodes {
                      actor {
                        ... on App {
                          id
                          name
                          slug
                        }
                        ... on Team {
                          id
                          name
                          slug
                        }
                        ... on User {
                          id
                          name
                          login
                        }
                      }
                    }
                  }
                requiresApprovingReviews
                requiredApprovingReviewCount
                requiresCodeOwnerReviews
                requiresCommitSignatures
                requiresConversationResolution
                requiresLinearHistory
                requiresStatusChecks
                requiredStatusChecks {
                    context

                }
                requiredStatusCheckContexts
                requiresStrictStatusChecks
                restrictsPushes
                restrictsReviewDismissals
                }
            }
        }
    }
'

if ($outputresponse) {
    Write-Host $JsonContent
    Exit
}

$json_object = ($JsonContent | ConvertFrom-Json)
$nodes = $json_object.data.repository.branchProtectionRules.nodes

$branch_protection_template = Get-Content "$PSScriptRoot\branch_protection_export_template.txt" -Raw

# Injects locally defined variables into the template
$branch_protection_policy_file_contents = Invoke-Expression "@`"`r`n$branch_protection_template`r`n`"@"

$sb = [System.Text.StringBuilder]::new($branch_protection_policy_file_contents)

$sorted_nodes = $nodes | Sort-Object -Property pattern

$sorted_nodes | ForEach-Object {

    [void]$sb.AppendLine("`n    - branchNamePattern: $($_.pattern.ToString())")

    if ($_.matchingRefs.nodes.count -gt 0) {
        [void]$sb.AppendLine("      # This branch pattern applies to the following branches as of approximately $(Get-Date):")
        $_.matchingRefs.nodes | ForEach-Object {
            [void]$sb.AppendLine("      # $($_.name.ToString())")
        }
    }
    else {
        [void]$sb.AppendLine("      # This branch pattern does not apply to any currently existent branches as of $(Get-Date).")
    }

    [void]$sb.AppendLine("`n      # Specifies whether this branch can be deleted. boolean")
    [void]$sb.AppendLine("      allowsDeletions: $($_.allowsDeletions.ToString().ToLower())")

    [void]$sb.AppendLine("      # Specifies whether forced pushes are allowed on this branch. boolean")
    [void]$sb.AppendLine("      allowsForcePushes: $($_.allowsForcePushes.ToString().ToLower())")

    [void]$sb.AppendLine("      # Specifies whether new commits pushed to the matching branches dismiss pull request review approvals. boolean")
    [void]$sb.AppendLine("      dismissStaleReviews: $($_.dismissesStaleReviews.ToString().ToLower())")

    [void]$sb.AppendLine("      # Specifies whether admins can overwrite branch protection. boolean")
    [void]$sb.AppendLine("      isAdminEnforced: $($_.isAdminEnforced.ToString().ToLower())")

    # https://stackoverflow.com/questions/76384359/github-graphql-api-branch-protection-rule-how-do-i-get-require-a-pull-reque
    if (($_.requiredApprovingReviewCount -ne $null) -and ($_.requiresApprovingReviews.ToString().ToLower() -eq "true")) {
        [void]$sb.AppendLine("      # Indicates whether `"Require a pull request before merging`" is enabled. boolean")
        [void]$sb.AppendLine("      requiresPullRequestBeforeMerging: $($_.requiresApprovingReviews.ToString().ToLower())")
    }

    if ($_.requiredApprovingReviewCount -ne $null) {
        [void]$sb.AppendLine("      # Specifies the number of pull request reviews before merging. int (0-6). Should be null/empty if PRs are not required")
        [void]$sb.AppendLine("      requiredApprovingReviewsCount: $($_.requiredApprovingReviewCount.ToString())")
    }

    [void]$sb.AppendLine("      # Require review from Code Owners. Requires requiredApprovingReviewsCount. boolean")
    [void]$sb.AppendLine("      requireCodeOwnersReview: $($_.requiresCodeOwnerReviews.ToString().ToLower())")

    [void]$sb.AppendLine("      # Are commits required to be signed. boolean. TODO: all contributors must have commit signing on local machines.")
    [void]$sb.AppendLine("      requiresCommitSignatures: $($_.requiresCommitSignatures.ToString().ToLower())")

    [void]$sb.AppendLine("      # Are conversations required to be resolved before merging? boolean")
    [void]$sb.AppendLine("      requiresConversationResolution: $($_.requiresConversationResolution.ToString().ToLower())")

    [void]$sb.AppendLine("      # Are merge commits prohibited from being pushed to this branch. boolean")
    [void]$sb.AppendLine("      requiresLinearHistory: $($_.requiresLinearHistory.ToString().ToLower())")

    if ($_.requiresStatusChecks -eq $true) {
        [void]$sb.AppendLine("      # Required status checks to pass before merging. Values can be any string, but if the value does not correspond to any existing status check, the status check will be stuck on pending for status since nothing exists to push an actual status")
        [void]$sb.AppendLine("      requiredStatusChecks:")
        $_.requiredStatusCheckContexts | ForEach-Object {
            [void]$sb.AppendLine("      - $($_.ToString())")
        }
    }

    [void]$sb.AppendLine("      # Require branches to be up to date before merging. boolean")
    [void]$sb.AppendLine("      requiresStrictStatusChecks: $($_.requiresStrictStatusChecks.ToString().ToLower())")

    [void]$sb.AppendLine("      # Indicates whether there are restrictions on who can push. boolean. Should be set with whoCanPush.")
    [void]$sb.AppendLine("      restrictsPushes: $($_.restrictsPushes.ToString().ToLower())")

    if (($_.restrictsPushes.ToString().ToLower() -eq "true") -and ($_.pushAllowances.nodes.Count -gt 0)) {
        [void]$sb.AppendLine("      # List of Apps, Users, and Teams that can push to this branch.")
        [void]$sb.AppendLine("      whoCanPush:")
        $_.pushAllowances.nodes | ForEach-Object {
            if ($_.actor.login -ne $null) {
                [void]$sb.AppendLine("    - $($_.actor.login.ToString())")
            }
            elseif ($_.actor.slug -ne $null)  {
                [void]$sb.AppendLine("    - $($_.actor.slug.ToString())")
            }
        }
    }

    [void]$sb.AppendLine("      # Restrict who can dismiss pull request reviews. boolean")
    [void]$sb.AppendLine("      restrictsReviewDismissals: $($_.restrictsReviewDismissals.ToString().ToLower())")

    if (($_.restrictsReviewDismissals.ToString().ToLower() -eq "true") -and ($_.reviewDismissalAllowances.nodes.Count -gt 0)) {
        [void]$sb.AppendLine("      # List of Apps, Users, and Teams that can dismiss pull request reviews to this branch pattern.")
        [void]$sb.AppendLine("      whoCanDismissReviews:")
        $_.reviewDismissalAllowances.nodes | ForEach-Object {
            if ($_.actor.login -ne $null) {
                [void]$sb.AppendLine("    - $($_.actor.login.ToString())")
            }
            elseif ($_.actor.slug -ne $null)  {
                [void]$sb.AppendLine("    - $($_.actor.slug.ToString())")
            }
        }
    }
}

$outputfilename = ".\$reponame-branch-protection.yml"
$filepath = Join-Path -Path $outputdirectory -ChildPath $outputfilename

Out-File -FilePath $filepath -InputObject $sb.ToString()
