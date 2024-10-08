# Policy Service Toolkit

This repository will hold scripts and other tools that make it easier to manage and define policy for the GitHub Policy Service. 

## Branch Protection Export

**Prerequisites**:
1. Logged in with GitHub CLI
2. Admin access to the repositories.

The **branch_protection_export.ps1** script is used to export existing branch protection rules into the yaml format supported by the GitHub Policy Service.

The **branch_protection_bulk_export.ps1** script is used to export bulk existing branch protection rules into the yaml format supported by the GitHub Policy Service.

**Workflow**

The suggested workflow is:

1. Export existing branch protection rules in the yaml file.
2. Check-in existing branch protection rules file at /.github/policies/.
3. Validate the rules are working as expected.
4. Update the branch protection rules in the yaml file and open PR.

Now you have gitop enabled your branch protection rules.
