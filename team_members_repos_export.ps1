# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# GraphQL query to get the team members in the the microsoftgraph GitHub organization.
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
                role
              }
            }
            repositories {
              edges {
                node {
                  name
                  url
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
  [void]$sb.AppendLine("$($_.node.name.ToString())")

  $_.node.members.edges | ForEach-Object {
    if ($_.node.login)
    {
      [void]$sb.Append("`t$($_.node.login.ToString()) ($($_.role.ToString()))")
    }
    if ($_.node.name)
    {
      [void]$sb.AppendLine("`t($($_.node.name.ToString()))")
    }
    else {
      [void]$sb.AppendLine()
    }
  }

  # Add the repositories
  if ($_.node.repositories.edges.Count -eq 0)
  {
    [void]$sb.AppendLine("`tNo repositories")
  }
  else {
    <# Action when all if and elseif conditions are false #>
    $list = [System.Collections.Generic.List[string]]::new()

    $_.node.repositories.edges | ForEach-Object {
      $list.Add($_.node.url.ToString())
    }

    $list.Sort()

    $list | ForEach-Object {
      [void]$sb.AppendLine("`tRepository: $_")
    }
  }
}

Out-File -FilePath ".\teams.txt" -InputObject $sb.ToString()