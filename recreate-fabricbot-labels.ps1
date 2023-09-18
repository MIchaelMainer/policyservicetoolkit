# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# GitHub CLI script to make sure the correct labels are set in the remote GitHub repo as are set for MerlinBot
# for issue automation. This script assumes that you are signed in to the GitHub CLI and that you have a valid token.
# This script assumes that you are calling it from the repo root, and that the repo has a resourceManagement.yml file.

# List of common labels with their colors. If you a new label here, make sure to add it to the default labels
# in your GitHub organization so that these are always available for noew repos.
# Using Kiota labels for references https://github.com/microsoft/kiota/labels
$commonLabels = @{}
$commonLabels['Needs: Author Feedback'] = 'D8E13E'
$commonLabels['Needs: Attention :wave:'] = 'ededed'
$commonLabels['Resolution: Duplicate'] = 'D00137'
$commonLabels['Status: No Recent Activity'] = 'ededed'

$text = Get-Content -Path .\.github\policies\resourceManagement.yml
$uniqueLabels = $text | ?{$_.Contains("label:")} | % { $_.Trim().Replace("label: ", "").Trim("'") } | Select-Object -Unique
$existingLabels = ConvertFrom-Json (gh label list --json name) | Select-Object -ExpandProperty name
foreach($uniqueLabel in $uniqueLabels) {
  if($existingLabels.Contains($uniqueLabel) -eq $false) {

    if ($commonLabels.Contains($uniqueLabel) -eq $true)
    {
      $labelColorValue = $commonLabels[$uniqueLabel]
      $color = "--color $labelColorValue"
      Write-Host "Color: $color"
    }
    else {
      $color = ""
    }

    Write-Host "Creating label: $uniqueLabel"


    gh label create "$uniqueLabel" $color
  }
}