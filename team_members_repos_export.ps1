# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.












# GraphQL query to get the branch protection rules
# https://docs.github.com/en/graphql/reference/objects#branchprotectionrule
$JsonContent = & "gh" api graphql -f query='
query {
    organization(login: "microsoftgraph") {
      teams(first: 80) {
        edges {
          node {
            name
            members {
              edges {
                node {
                  name
                  login
                }
              }
            }
            repositories {
              edges {
                node {
                  name
                }
              }
            }
          }
        }
      }
    }
  }
'

$json_object = ($JsonContent | ConvertFrom-Json)
$edges = $json_object.data.organization.teams.edges


$sb = [System.Text.StringBuilder]::new()

$edges | ForEach-Object {
  [void]$sb.AppendLine("Team name: $($_.node.name.ToString())")

  $_.node.members.edges | ForEach-Object {
    if ($_.node.name)
    {
      [void]$sb.Append("  User Name: $($_.node.name.ToString())`t`t`t`t")
    }
    if ($_.node.login)
    {
      [void]$sb.AppendLine("  GitHub Handle:$($_.node.login.ToString())")
    }
  }

  $_.node.repositories.edges | ForEach-Object {
    [void]$sb.AppendLine("  Repository: $($_.node.name.ToString())")
  }

}

Out-File -FilePath ".\teams.txt" -InputObject $sb.ToString()