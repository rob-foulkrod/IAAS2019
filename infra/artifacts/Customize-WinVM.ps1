# Install Chocolatey

# Set Chocolatey version to 1.4.0 to avoid installing .NET 4.8 Framework (which the newer 2.0 needs, but requires reboot, and blocks CustomScriptExtension

$env:chocolateyVersion = '1.4.0'

Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))

# allow all choco updates automatically 
choco feature enable -n allowGlobalConfirmation

#Install dotnet 6.0 hosting bundle
choco install dotnet-6.0-windowshosting  -confirm:$false

# Install Microsoft Edge
choco install microsoft-edge  -confirm:$false

# Install Google Chrome
choco install googlechrome  -confirm:$false

# Install SQL Server Management Studio
choco install sql-server-management-studio  -confirm:$false
