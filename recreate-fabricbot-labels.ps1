# Copyright (c) Microsoft Corporation.
# Licensed under the MIT License.

# GitHub CLI script to make sure the correct labels are set in the remote GitHub repo as are set for MerlinBot
# for issue automation. This script assumes that you are signed in to the GitHub CLI and that you have a valid token.
# This script assumes that you are calling it from the repo root, and that the repo has a resourceManagement.yml file.



$text = Get-Content -Path .\.github\policies\resourceManagement.yml
$uniqueLabels = $text | ?{$_.Contains("label:")} | % { $_.Trim().Replace("label: ", "").Trim("'") } | Select-Object -Unique
$existingLabels = ConvertFrom-Json (gh label list --json name) | Select-Object -ExpandProperty name
foreach($uniqueLabel in $uniqueLabels) {
  if($existingLabels.Contains($uniqueLabel) -eq $false) {
    gh label create $uniqueLabel
  }
}