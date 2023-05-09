
# https://stackoverflow.com/questions/56322993/proper-formating-of-json-using-powershell
function Format-Json {
    <#
    .SYNOPSIS
        Prettifies JSON output.
    .DESCRIPTION
        Reformats a JSON string so the output looks better than what ConvertTo-Json outputs.
    .PARAMETER Json
        Required: [string] The JSON text to prettify.
    .PARAMETER Minify
        Optional: Returns the json string compressed.
    .PARAMETER Indentation
        Optional: The number of spaces (1..1024) to use for indentation. Defaults to 4.
    .PARAMETER AsArray
        Optional: If set, the output will be in the form of a string array, otherwise a single string is output.
    .EXAMPLE
        $json | ConvertTo-Json  | Format-Json -Indentation 2
    #>
    [CmdletBinding(DefaultParameterSetName = 'Prettify')]
    Param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromPipeline = $true)]
        [string]$Json,

        [Parameter(ParameterSetName = 'Minify')]
        [switch]$Minify,

        [Parameter(ParameterSetName = 'Prettify')]
        [ValidateRange(1, 1024)]
        [int]$Indentation = 4,

        [Parameter(ParameterSetName = 'Prettify')]
        [switch]$AsArray
    )

    if ($PSCmdlet.ParameterSetName -eq 'Minify') {
        return ($Json | ConvertFrom-Json) | ConvertTo-Json -Depth 100 -Compress
    }

    # If the input JSON text has been created with ConvertTo-Json -Compress
    # then we first need to reconvert it without compression
    if ($Json -notmatch '\r?\n') {
        $Json = ($Json | ConvertFrom-Json) | ConvertTo-Json -Depth 100
    }

    $indent = 0
    $regexUnlessQuoted = '(?=([^"]*"[^"]*")*[^"]*$)'

    $result = $Json -split '\r?\n' |
        ForEach-Object {
            # If the line contains a ] or } character,
            # we need to decrement the indentation level unless it is inside quotes.
            if ($_ -match "[}\]]$regexUnlessQuoted") {
                $indent = [Math]::Max($indent - $Indentation, 0)
            }

            # Replace all colon-space combinations by ": " unless it is inside quotes.
            $line = (' ' * $indent) + ($_.TrimStart() -replace ":\s+$regexUnlessQuoted", ': ')

            # If the line contains a [ or { character,
            # we need to increment the indentation level unless it is inside quotes.
            if ($_ -match "[\{\[]$regexUnlessQuoted") {
                $indent += $Indentation
            }

            $line
        }

    if ($AsArray) { return $result }
    return $result -Join [Environment]::NewLine
}

# gh api repos/microsoftgraph/microsoft-graph-toolkit/branches/main/protection

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
#.Parameter allRepos
#   Indicates that we will export the branch protection rules for all repos.
#>

# param([parameter(Mandatory = $true)] [String] $repoowner,
#       [parameter(Mandatory = $true)] [String] $reponame,
#       [parameter(Mandatory = $true)] [String] $branch,
#       [parameter(Mandatory = $false)] [bool] $allRepos)


# https://dotnet-helpers.com/powershell/convert-yaml-to-json-or-json-to-yaml-using-powershell/#:~:text=Converting%20JSON%20to%20YAML%20format%3A%201%20STEP%3A1%20Get,%26%20Finally%20save%20the%20file%20using%20Set-Content.%20

# 1) Call https://docs.github.com/en/rest/branches/branches?apiVersion=2022-11-28#list-branches to get prtected branches
# gh api repos/microsoftgraph/microsoft-graph-toolkit/branches?protected=true


# 2) Call https://docs.github.com/en/rest/branches/branch-protection?apiVersion=2022-11-28#get-branch-protection to get settings
# gh api repos/microsoftgraph/microsoft-graph-toolkit/branches/main/protection
# gh api repos/microsoftgraph/microsoft-graph-toolkit/branches/dev/protection



# gh api graphql -F owner='{owner}' -F name='{repo}' -f query='
#   query($name: String!, $owner: String!) {
#     repository(owner: $owner, name: $name) {
#       releases(last: 3) {
#         nodes { tagName }
#       }
#     }
#   }
# '

$JsonContent = & "gh" api graphql -F owner='microsoftgraph' -F name='microsoft-graph-toolkit' -f query='
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



# $hash_Value = ($JsonContent | ConvertFrom-Json)
# $rules = $hash_Value.data.repository.branchProtectionRules.nodes #| ForEach-Object {$_.PsObject.Properties.Pattern}
# $pattern = $rules[0].pattern

# $reponame = "microsoft-graph-toolkit"

$hash_Value = ($JsonContent | ConvertFrom-Json)
$nodes = $hash_Value.data.repository.branchProtectionRules.nodes #| ForEach-Object $_.PsObject.Properties.Pattern
$nodes.count

$reponame = "microsoft-graph-toolkit"
$template = Get-Content 'branchprotectionexporttemplate.txt' -Raw

# Injects locally defined variables into the template
$expanded = Invoke-Expression "@`"`r`n$template`r`n`"@"

$sb = [System.Text.StringBuilder]::new($expanded)


[void]$sb.AppendLine("`n`n# The following GitHub PolicyService properties are not supported: whoCanDismissReviews and whoCanPush")

$nodes | ForEach-Object {

    [void]$sb.AppendLine("`n  - branchNamePattern: $($_.pattern.ToString())")

    [void]$sb.AppendLine("    # Specifies whether this branch can be deleted. boolean")
    [void]$sb.AppendLine("    allowsDeletions: $($_.allowsDeletions.ToString().ToLower())")

    [void]$sb.AppendLine("    # Specifies whether forced pushes are allowed on this branch. boolean")
    [void]$sb.AppendLine("    allowsForcePushes: $($_.allowsForcePushes.ToString().ToLower())")

    [void]$sb.AppendLine("    # Specifies whether new commits pushed to the matching branches dismiss pull request review approvals. boolean")
    [void]$sb.AppendLine("    dismissStaleReviews: $($_.dismissesStaleReviews.ToString().ToLower())")

    [void]$sb.AppendLine("    # Specifies whether admins can overwrite branch protection. boolean")
    [void]$sb.AppendLine("    isAdminEnforced: $($_.isAdminEnforced.ToString().ToLower())")

    [void]$sb.AppendLine("    # Specifies whether approving reviews are required to update matching branches. boolean")
    [void]$sb.AppendLine("    requiresApprovingReviews: $($_.requiresApprovingReviews.ToString().ToLower())")

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

    [void]$sb.AppendLine("    # Requires requiresStrictStatusChecks. Values can be any string, but if the value does not correspond to any existing status check, the status check will be stuck on pending for status since nothing exists to push an actual status")
    [void]$sb.AppendLine("    requiresStatusChecks: $($_.requiresStatusChecks.ToString().ToLower())")

    if ($_.requiresStatusChecks -eq $true) {
        [void]$sb.AppendLine("    # Requires requiresStrictStatusChecks. Values can be any string, but if the value does not correspond to any existing status check, the status check will be stuck on pending for status since nothing exists to push an actual status")
        [void]$sb.AppendLine("    requiredStatusCheckContexts:")
        $_.requiredStatusCheckContexts | ForEach-Object {
            [void]$sb.AppendLine("    - $($_.ToString())")
        }
    }

    [void]$sb.AppendLine("    # The docs conflict. Are branches required to be up to date before merging. Or Require status checks to pass before merging")
    [void]$sb.AppendLine("    requiresStrictStatusChecks: $($_.requiresStrictStatusChecks.ToString().ToLower())")

    [void]$sb.AppendLine("    # Restrict who can push to matching branches")
    [void]$sb.AppendLine("    restrictsPushes: $($_.restrictsPushes.ToString().ToLower())")

    [void]$sb.AppendLine("    # Restrict who can dismiss pull request reviews")
    [void]$sb.AppendLine("    restrictsReviewDismissals: $($_.restrictsReviewDismissals.ToString().ToLower())")
    [void]$sb.AppendLine("")

}

Out-File -FilePath .\output.yml -InputObject $sb.ToString()


# $JsonContent.Data.Repository.BranchProtectionRules.Nodes | ConvertFrom-Json | ForEach-Object {$_.PsObject.Properties.Pattern}

# $JsonContent | ConvertTo-Json
# $hash_Value = ($JsonContent | ConvertFrom-Json)
# $hash_Value.data.repository.branchProtectionRules
# $hash_Value

