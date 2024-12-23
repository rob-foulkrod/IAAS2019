
# Analyze Azure resources using PSRule for Azure
$modules = @('PSRule.Rules.Azure')
# uncomment to install the first time
# Install-Module -Name $modules -Scope CurrentUser -Force -ErrorAction Stop;
Assert-PSRule -InputPath '.' -Module $modules -Format File -ErrorAction Stop;
