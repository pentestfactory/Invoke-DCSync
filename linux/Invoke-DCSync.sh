#!/bin/bash

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
GRAY='\033[0;37m'
NC='\033[0m'

# Variables
DATE=$(date +%Y%m%dT%H%M)
BASE_PATH="/tmp/${DATE}_DCSYNC"
LOGFILE="${BASE_PATH}/${DATE}_DCSync_NTLM_LOGFILE.txt"
HASHES="${BASE_PATH}/${DATE}_DCSync_NTLM_Hashes_FINAL.txt"
USERS="${BASE_PATH}/${DATE}_DCSync_NTLM_Users_FINAL.txt"
STATUS="${BASE_PATH}/${DATE}_DCSync_NTLM_Status_FINAL.txt"
PTFHASHES="${BASE_PATH}/${DATE}_DCSync_NTLM_PTF_Hashes_FINAL.csv"
IMPORTFILE="${BASE_PATH}/${DATE}_DCSync_NTLM_CUSTOMER_Importfile_FINAL.csv"

# Banner
echo ""
echo "================================================"
echo "  DCSync Password Audit Tool (Linux Version)"
echo "================================================"
echo ""

# Prompt for credentials and target information
echo -e "${GRAY}[~] Please provide the following information:${NC}"
echo ""
read -p "Domain Name (e.g., CONTOSO.LOCAL): " DOMAIN
read -p "Domain Controller IP Address: " DC_IP
read -p "Domain Admin Username: " USERNAME
read -sp "Domain Admin Password: " PASSWORD
echo ""
echo ""

# Confirmation
echo -e "${RED}[INFO] DCSync will be executed for the domain: ${DOMAIN}${NC}"
echo -e "${RED}[INFO] Target Domain Controller: ${DC_IP}${NC}"
echo ""
read -p "Is this information correct? (y/n): " CONFIRMATION

if [ "$CONFIRMATION" != "y" ]; then
    echo -e "${RED}[!] Script aborted by user.${NC}"
    exit 1
fi

# Check if secretsdump.py is available
if ! command -v secretsdump.py &> /dev/null && ! command -v impacket-secretsdump &> /dev/null; then
    echo -e "${RED}[!] Error: secretsdump.py not found. Please install impacket-scripts:${NC}"
    echo "    sudo apt install python3-impacket"
    echo "    or: pip3 install impacket"
    exit 1
fi

# Determine which command to use
if command -v impacket-secretsdump &> /dev/null; then
    SECRETSDUMP_CMD="impacket-secretsdump"
else
    SECRETSDUMP_CMD="secretsdump.py"
fi

# Create directory structure
echo ""
echo -e "${GRAY}[~] Creating directory structure at ${BASE_PATH}${NC}"
mkdir -p "${BASE_PATH}/PTF"
mkdir -p "${BASE_PATH}/CUSTOMER"

# Execute DCSync using secretsdump with user status
echo -e "${YELLOW}[!] Executing DCSync via secretsdump - this may take a while...${NC}"
echo ""

# Run secretsdump with -user-status flag and capture output
# Format: domain\username:RID:LMhash:NThash::: (status=Enabled/Disabled)
$SECRETSDUMP_CMD -just-dc-ntlm -user-status -dc-ip "${DC_IP}" "${DOMAIN}/${USERNAME}:${PASSWORD}@${DC_IP}" 2>&1 | tee "${LOGFILE}"

# Check if secretsdump was successful
if [ ${PIPESTATUS[0]} -ne 0 ]; then
    echo -e "${RED}[!] Error: secretsdump failed. Check credentials and connectivity.${NC}"
    exit 1
fi

# Check if we got any hashes
if ! grep -q "aad3b435b51404eeaad3b435b51404ee" "${LOGFILE}"; then
    echo -e "${RED}[!] Error: No hashes found in output. DCSync may have failed.${NC}"
    exit 1
fi

echo ""
echo -e "${GRAY}[~] Parsing extracted hashes...${NC}"

# Parse the secretsdump output
# Format is: domain\username:RID:LMhash:NThash::: (status=Enabled/Disabled)
# We want to extract only user accounts (not machine accounts ending with $)

# Extract usernames (excluding machine accounts and header lines)
grep ":::" "${LOGFILE}" | grep -v '\$:' | grep -v "^\[" | cut -d: -f1 | sed 's/.*\\//' > "$USERS"

# Extract NT hashes (excluding machine accounts and header lines)
grep ":::" "${LOGFILE}" | grep -v '\$:' | grep -v "^\[" | cut -d: -f4 > "$HASHES"

# Extract and convert status information
# Convert from (status=Enabled) to NORMAL_ACCOUNT and (status=Disabled) to ACCOUNTDISABLE
grep ":::" "${LOGFILE}" | grep -v '\$:' | grep -v "^\[" | sed 's/.*status=\([^)]*\).*/\1/' | while read status; do
    if [ "$status" = "Enabled" ]; then
        echo "NORMAL_ACCOUNT"
    elif [ "$status" = "Disabled" ]; then
        echo "ACCOUNTDISABLE"
    else
        echo "UNKNOWN"
    fi
done > "$STATUS"

# Create import file for customer (username,hash format)
echo -e "${GRAY}[~] Creating customer import file...${NC}"
echo "samaccountname,nthash" > "$IMPORTFILE"
paste -d, "$USERS" "$HASHES" >> "$IMPORTFILE"

# Create PTF hash file with header and status (matching PowerShell script format)
echo -e "${GRAY}[~] Creating PTF hash file with status...${NC}"
echo "hash,status" > "$PTFHASHES"
paste -d, "$HASHES" "$STATUS" >> "$PTFHASHES"

# Count extracted accounts
USER_COUNT=$(wc -l < "$USERS")

# Move files to appropriate directories
mv "$IMPORTFILE" "${BASE_PATH}/CUSTOMER/"
mv "$LOGFILE" "${BASE_PATH}/CUSTOMER/"
mv "$PTFHASHES" "${BASE_PATH}/PTF/"

# Cleanup temporary files
rm -f "$USERS" "$HASHES" "$STATUS"

# Final message
echo ""
echo -e "${GREEN}[OK] Extraction completed for ${USER_COUNT} user accounts${NC}"
echo -e "${GRAY}  > Please submit the 'PTF' directory to Pentest Factory GmbH${NC}"
echo -e "${GRAY}  > Please consider all files as confidential!${NC}"
echo -e "${GRAY}  > Output directory: ${BASE_PATH}${NC}"
echo ""

# Try to open file manager (if in GUI environment)
if [ -n "$DISPLAY" ]; then
    if command -v xdg-open &> /dev/null; then
        xdg-open "$BASE_PATH" 2>/dev/null
    elif command -v nautilus &> /dev/null; then
        nautilus "$BASE_PATH" 2>/dev/null &
    fi
fi

echo -e "${GRAY}Files created:${NC}"
echo "  - ${BASE_PATH}/PTF/ (for Pentest Factory)"
echo "    - PTF hash file with account status (hash,status)"
echo "  - ${BASE_PATH}/CUSTOMER/ (for customer review)"
echo "    - Import file (username,hash)"
echo "    - Full DCSync log"
echo ""
