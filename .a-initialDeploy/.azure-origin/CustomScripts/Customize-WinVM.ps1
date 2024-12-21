# Install Chocolatey

Set-ExecutionPolicy Bypass -Scope Process -Force; [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072; iex ((New-Object System.Net.WebClient).DownloadString ('https://chocolatey.org/install.ps1'))

#Install dotnet 6.0 hosting bundle
choco install dotnet-6.0-windowshosting

# Install Microsoft Edge
choco install microsoft-edge

# Install Google Chrome
choco install googlechrome

