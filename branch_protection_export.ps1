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
#>

Param(
    [parameter(Mandatory = $true)] [String] $repoowner,
    [parameter(Mandatory = $true)] [String] $reponame
)

# Setting local variable so that it can be injected into the template
$reponame = $reponame

# GraphQL query to get the branch protection rules
# https://docs.github.com/en/graphql/reference/objects#branchprotectionrule
$JsonContent = & "gh" api graphql -F owner="$repoowner" -F name="$reponame" -f query='
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
                isAdminEnforced
                requiresApprovingReviews
                requiredApprovingReviewCount
                requiresCodeOwnerReviews
                requiresCommitSignatures
                requiresLinearHistory
                requiresStatusChecks
                requiredStatusCheckContexts
                requiresStrictStatusChecks
                restrictsPushes
                restrictsReviewDismissals
                }
            }
        }
    }
'

$json_object = ($JsonContent | ConvertFrom-Json)
$nodes = $json_object.data.repository.branchProtectionRules.nodes #| ForEach-Object $_.PsObject.Properties.Pattern

$outputfilename = ".\$reponame-branch-protection.yml"
$branch_protection_template = Get-Content '.\branch_protection_export_template.txt' -Raw

# Injects locally defined variables into the template
$branch_protection_policy_file_contents = Invoke-Expression "@`"`r`n$branch_protection_template`r`n`"@"

$sb = [System.Text.StringBuilder]::new($branch_protection_policy_file_contents)

$nodes | ForEach-Object {

    [void]$sb.AppendLine("  - branchNamePattern: $($_.pattern.ToString())")

    [void]$sb.AppendLine("    # Specifies whether this branch can be deleted. boolean")
    [void]$sb.AppendLine("    allowsDeletions: $($_.allowsDeletions.ToString().ToLower())")

    [void]$sb.AppendLine("    # Specifies whether forced pushes are allowed on this branch. boolean")
    [void]$sb.AppendLine("    allowsForcePushes: $($_.allowsForcePushes.ToString().ToLower())")

    [void]$sb.AppendLine("    # Specifies whether new commits pushed to the matching branches dismiss pull request review approvals. boolean")
    [void]$sb.AppendLine("    dismissStaleReviews: $($_.dismissesStaleReviews.ToString().ToLower())")

    [void]$sb.AppendLine("    # Specifies whether admins can overwrite branch protection. boolean")
    [void]$sb.AppendLine("    isAdminEnforced: $($_.isAdminEnforced.ToString().ToLower())")

    [void]$sb.AppendLine("    # Specifies the number of pull request reviews before merging. int (0-6)")
    [void]$sb.AppendLine("    requiredApprovingReviewsCount: $($_.requiredApprovingReviewCount.ToString())")

    [void]$sb.AppendLine("    # Require review from Code Owners. Requires requiredApprovingReviewsCount. boolean")
    [void]$sb.AppendLine("    requireCodeOwnersReview: $($_.requiresCodeOwnerReviews.ToString().ToLower())")

    [void]$sb.AppendLine("    # Are commits required to be signed. boolean")
    [void]$sb.AppendLine("    requiresCommitSignatures: $($_.requiresCommitSignatures.ToString().ToLower())")

    # $requiresConversationResolution = $_.requiresConversationResolution ? "" : $_.requiresConversationResolution.ToString().ToLower()
    # [void]$sb.AppendLine("    # Are conversations required to be resolved before merging.")
    # [void]$sb.AppendLine("    requiresConversationResolution: $requiresConversationResolution")

    [void]$sb.AppendLine("    # Are merge commits prohibited from being pushed to this branch. boolean")
    [void]$sb.AppendLine("    requiresLinearHistory: $($_.requiresLinearHistory.ToString().ToLower())")

    # [void]$sb.AppendLine("    # I'm not seeing this in the docs https://docs.github.com/en/graphql/reference/objects#branchprotectionrule")
    # [void]$sb.AppendLine("    requiresPullRequestBeforeMerging: $($_.requiresPullRequestBeforeMerging.ToString().ToLower())")

    # [void]$sb.AppendLine("    # Requires requiresStrictStatusChecks. Values can be any string, but if the value does not correspond to any existing status check, the status check will be stuck on pending for status since nothing exists to push an actual status")
    # [void]$sb.AppendLine("    requiredStatusChecks: $($_.requiresStatusChecks.ToString().ToLower())")

    if ($_.requiresStatusChecks -eq $true) {
        [void]$sb.AppendLine("    # Requires requiresStrictStatusChecks. Values can be any string, but if the value does not correspond to any existing status check, the status check will be stuck on pending for status since nothing exists to push an actual status")
        [void]$sb.AppendLine("    requiredStatusChecks:")
        $_.requiredStatusCheckContexts | ForEach-Object {
            [void]$sb.AppendLine("    - $($_.ToString())")
        }
    }

    [void]$sb.AppendLine("    # The docs conflict. Are branches required to be up to date before merging. Or Require status checks to pass before merging")
    [void]$sb.AppendLine("    requiresStrictStatusChecks: $($_.requiresStrictStatusChecks.ToString().ToLower())")

    [void]$sb.AppendLine("    # Restrict who can push to matching branches")
    [void]$sb.AppendLine("    restrictsPushes: $($_.restrictsPushes.ToString().ToLower())")

    [void]$sb.AppendLine("    # Restrict who can dismiss pull request reviews")
    [void]$sb.AppendLine("    restrictsReviewDismissals: $($_.restrictsReviewDismissals.ToString().ToLower())`n")
}

Out-File -FilePath $outputfilename -InputObject $sb.ToString()