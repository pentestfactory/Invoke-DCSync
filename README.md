<div align="center" width="100%">
    <h1>Invoke-DCSync</h1>
    <p>PowerShell Script to DCSync NT Password Hashes from Active Directory for Password Auditing</p><p>
    <a target="_blank" href="https://github.com/pentestfactory"><img src="https://img.shields.io/badge/maintainer-Pentest%20Factory-orange" /></a>
    <a target="_blank" href="https://github.com/pentestfactory/Invoke-DCSync/graphs/contributors/"><img src="https://img.shields.io/github/contributors/pentestfactory/Invoke-DCSync.svg" /></a><br>
    <a target="_blank" href="https://github.com/pentestfactory/Invoke-DCSync/commits/"><img src="https://img.shields.io/github/last-commit/pentestfactory/Invoke-DCSync.svg" /></a>
    <a target="_blank" href="https://github.com/pentestfactory/Invoke-DCSync/issues/"><img src="https://img.shields.io/github/issues/pentestfactory/Invoke-DCSync.svg" /></a>
    <a target="_blank" href="https://github.com/pentestfactory/Invoke-DCSync/issues?q=is%3Aissue+is%3Aclosed"><img src="https://img.shields.io/github/issues-closed/pentestfactory/Invoke-DCSync.svg" /></a><br>
        <a target="_blank" href="https://github.com/pentestfactory/Invoke-DCSync/stargazers"><img src="https://img.shields.io/github/stars/pentestfactory/Invoke-DCSync.svg?style=social&label=Star" /></a>
    <a target="_blank" href="https://github.com/pentestfactory/Invoke-DCSync/network/members"><img src="https://img.shields.io/github/forks/pentestfactory/Invoke-DCSync.svg?style=social&label=Fork" /></a>
    <a target="_blank" href="https://github.com/pentestfactory/Invoke-DCSync/watchers"><img src="https://img.shields.io/github/watchers/pentestfactory/Invoke-DCSync.svg?style=social&label=Watch" /></a><p>
</div>

## 💎 Features

Invoke-DCSync is a PowerShell wrapper script around popular tools such as PowerView, Invoke-Mimikatz and ADRecon. 

It automates the task of dumping NT password hashes from an Active Directory environment. The script was designed for Active Directory password audits, where extracted password hashes undergo a cracking process in order to outline password strength and policy weaknesses. 

The script will parse the output of Mimikatz's DCSync and create two separate folders with output files:
- A directory `CUSTOMER` with detailed information about Active Directory users and their NT password hashes. The import file in this directory will later be used to establish a reference between an AD user and a cracked password hash.
- A directory `PTF` with information about NT password hashes only. This folder may be shared with an external security vendor that conducts offline password cracking. User information from ADRecon are not linked to an extracted NT password hash.

## 🎓 Usage

To utilize this PowerShell script, it's recommended to disable Antivirus/EDR. Alternatively, if no advanced EDR is in use, it may be sufficient to bypass AMSI for the current PowerShell process.

The script must be run in the context of an Active Directory domain user with DCSync rights. Usually, a Domain Administrator (DA) user account is privileged enough and recommended for ease of use. You may obtain a PowerShell terminal in the context of such domain user via the following PowerShell command:

````powershell
runas.exe /netonly /noprofile /user:example.com\dcsyncuser "powershell.exe -ep bypass"
````

Other from that, it's a matter of running the PowerShell .PS1 script:

````powershell
iex(new-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/pentestfactory/Invoke-DCSync/main/Invoke-DCSync.ps1')
````

You will be prompted about the target AD domain. Confirm to start the DCSync extraction process of NT password hashes. 

As soon as the script finishes, a new Windows file explorer will open automatically and display the relevant output directories.

## 🔎 FAQ

**Q**: Why do I have to disable Antivirus/EDR/AMSI?

**A**: This PowerShell wrapper script heavily relies on popular tooling such as PowerView, Mimikatz and ADRecon. Those tools are known and flagged by AV vendors to be malicious. If you run this PowerShell script with enabled AV/EDR/AMSI, the script will likely be detected as malicious and blocked from being executed.

---

**Q**: Why are there two separate directories?

**A**: This PowerShell wrapper script was designed to automate the initial process of extracting NT password hashes in order to conduct password cracking. The script will parse Mimikatz's DCSync output into separate directories to establish some kind of privacy. The `CUSTOMER` folder can remain on the customer side, which contains sensitive information about AD users and the belonging password hashes. The `PTF` folder on the other hand 'only' contains NT password hashes without a reference to the actual AD user account that is linked to this password hash.

---

**Q**: On which IT system must this script be run?

**A**: This PowerShell wrapper script can be run on any domain-joined computer in the target AD environment. It's also possible to execute it from an unjoined computer system. Just make sure that your IT system can talk to the Domain Controller (DC), uses the proper DNS servers to resolve hostnames and that you spawn a PowerShell terminal in the context of a DCSync privileged AD account (e.g. Domain Administrator).

---

**Q**: The computer on which the PowerShell script shall run does not have an Internet connection. How can I run the script?

**A**: You can download the GitHub repo locally onto disk. However, AV/EDR must be disabled as the scripts will likely be flagged as malicious. Then proceed by executing the `/run-locally/Invoke-DCSync-Locally.ps1` script.

---

**Q**: The computer on which the PowerShell script shall run uses a company proxy that blocks the GitHub domain. How can I run the script?

**A**: You can host the script on a different domain under your control, which is not blacklisted. Alternatively, you can download/copy the GitHub repo locally onto disk. However, AV/EDR must be disabled as the scripts will likely be flagged as malicious. Then proceed by executing the `/run-locally/Invoke-DCSync-Locally.ps1` script.

---

**Q**: Do I have to conduct some form of cleanup after the script was run?

**A**: Please re-active any AV/EDR solutions, which were previously deactivated. Furthermore, you may want to restart the computer on which the script was run. This ensures that all scripts, which were loaded into memory, are removed completely. Finally, ensure that the exported data is treated as very sensitive and stored securely. Only authorized personell should be able to access the DCSync exports.
