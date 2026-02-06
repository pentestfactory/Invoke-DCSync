#!/bin/bash

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
GRAY='\033[0;37m'
BLUE='\033[0;34m'
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
PYADRECON_LOG="${BASE_PATH}/${DATE}_PyADRecon_LOGFILE.txt"

# Banner
echo ""
echo "======================================================="
echo "  DCSync Password Audit Tool (Enhanced Linux Version)"
echo "  with Integrated PyADRecon User Collection"
echo "======================================================="
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

# Set PyADRecon path to current directory
PYADRECON_PATH="./PyADRecon"
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

# Check if PyADRecon exists, if not clone it automatically
if [ ! -d "$PYADRECON_PATH" ]; then
    echo -e "${BLUE}[~] PyADRecon not found. Cloning repository...${NC}"
    git clone https://github.com/pentestfactory/PyADRecon "$PYADRECON_PATH"
    
    if [ $? -ne 0 ]; then
        echo -e "${RED}[!] Failed to clone PyADRecon. Continuing without user metadata collection.${NC}"
        SKIP_PYADRECON=true
    else
        echo -e "${GREEN}[OK] PyADRecon cloned successfully${NC}"
    fi
else
    echo -e "${GREEN}[OK] PyADRecon found at ${PYADRECON_PATH}${NC}"
    echo -e "${BLUE}[~] Updating PyADRecon to latest version...${NC}"
    (cd "$PYADRECON_PATH" && git pull) > /dev/null 2>&1
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}[OK] PyADRecon updated successfully${NC}"
    else
        echo -e "${YELLOW}[!] Warning: Could not update PyADRecon (continuing with existing version)${NC}"
    fi
fi

# Check if pyadrecon.py exists
if [ -z "$SKIP_PYADRECON" ] && [ ! -f "${PYADRECON_PATH}/pyadrecon.py" ]; then
    echo -e "${YELLOW}[!] Warning: pyadrecon.py not found in ${PYADRECON_PATH}${NC}"
    echo -e "${YELLOW}[!] Skipping PyADRecon user collection.${NC}"
    SKIP_PYADRECON=true
fi

# Create directory structure
echo ""
echo -e "${GRAY}[~] Creating directory structure at ${BASE_PATH}${NC}"
mkdir -p "${BASE_PATH}/PTF"
mkdir -p "${BASE_PATH}/CUSTOMER"

# Execute DCSync using secretsdump with user status
echo ""
echo -e "${YELLOW}[!] Step 1/2: Executing DCSync via secretsdump...${NC}"
echo -e "${GRAY}    This may take a while depending on domain size...${NC}"
echo ""

# Run secretsdump in background and show progress spinner
$SECRETSDUMP_CMD -just-dc-ntlm -user-status -dc-ip "${DC_IP}" "${DOMAIN}/${USERNAME}:${PASSWORD}@${DC_IP}" > "${LOGFILE}" 2>&1 &
SECRETSDUMP_PID=$!

# Progress spinner
spin='-\|/'
i=0
echo -n "    [~] Extracting password hashes... "
while kill -0 $SECRETSDUMP_PID 2>/dev/null; do
    i=$(( (i+1) %4 ))
    printf "\r    [${spin:$i:1}] Extracting password hashes... "
    sleep 0.1
done
printf "\r    [✓] Extracting password hashes... "

# Wait for secretsdump to complete and get exit code
wait $SECRETSDUMP_PID
SECRETSDUMP_EXIT_CODE=$?

if [ $SECRETSDUMP_EXIT_CODE -eq 0 ]; then
    echo -e "${GREEN}Done${NC}"
else
    echo -e "${RED}Failed${NC}"
fi

# Check if secretsdump was successful
if [ $SECRETSDUMP_EXIT_CODE -ne 0 ]; then
    echo -e "${RED}[!] Error: secretsdump failed. Check credentials and connectivity.${NC}"
    echo -e "${GRAY}    Full log available at: ${LOGFILE}${NC}"
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

echo -e "${GREEN}[OK] Hash extraction completed for ${USER_COUNT} user accounts${NC}"

# Execute PyADRecon if available
if [ -z "$SKIP_PYADRECON" ]; then
    echo ""
    echo -e "${YELLOW}[!] Step 2/2: Collecting user metadata with PyADRecon...${NC}"
    echo -e "${GRAY}    This may take a while depending on domain size...${NC}"
    echo ""
    
    # Get absolute path for output directory
    ABS_OUTPUT_PATH=$(readlink -f "${BASE_PATH}/PTF/")
    
    # Get absolute path to pyadrecon.py
    ABS_PYADRECON_PATH=$(readlink -f "${PYADRECON_PATH}")
    
    # Execute PyADRecon from its directory in background
    (
        cd "${ABS_PYADRECON_PATH}" && \
        python3 pyadrecon.py \
            -dc "${DC_IP}" \
            -u "${USERNAME}" \
            -p "${PASSWORD}" \
            -d "${DOMAIN}" \
            --collect users,passwordpolicy \
            --no-excel \
            -o "${ABS_OUTPUT_PATH}/" > "${PYADRECON_LOG}" 2>&1
    ) &
    PYADRECON_PID=$!
    
    # Progress spinner
    spin='-\|/'
    i=0
    echo -n "    [~] Collecting user metadata... "
    while kill -0 $PYADRECON_PID 2>/dev/null; do
        i=$(( (i+1) %4 ))
        printf "\r    [${spin:$i:1}] Collecting user metadata... "
        sleep 0.1
    done
    printf "\r    [✓] Collecting user metadata... "
    
    # Wait for PyADRecon to complete
    wait $PYADRECON_PID
    PYADRECON_EXIT_CODE=$?
    
    if [ $PYADRECON_EXIT_CODE -eq 0 ]; then
        echo -e "${GREEN}Done${NC}"
    else
        echo -e "${YELLOW}Completed with warnings${NC}"
    fi
    
    if [ $PYADRECON_EXIT_CODE -eq 0 ]; then
        echo ""
        echo -e "${GREEN}[OK] PyADRecon collection completed${NC}"
        
        # Move Users.csv to PTF root directory
        if [ -f "${BASE_PATH}/PTF/CSV-Files/Users.csv" ]; then
            USER_METADATA_COUNT=$(tail -n +2 "${BASE_PATH}/PTF/CSV-Files/Users.csv" 2>/dev/null | wc -l)
            echo -e "${GRAY}    Collected metadata for ${USER_METADATA_COUNT} users${NC}"
            echo -e "${GRAY}[~] Moving Users.csv to PTF root directory...${NC}"
            mv "${BASE_PATH}/PTF/CSV-Files/Users.csv" "${BASE_PATH}/PTF/Users.csv"
        else
            echo -e "${YELLOW}[!] Warning: Users.csv not found in expected location${NC}"
        fi
        
        # Move PasswordPolicy.csv to PTF root directory
        if [ -f "${BASE_PATH}/PTF/CSV-Files/PasswordPolicy.csv" ]; then
            echo -e "${GRAY}[~] Moving PasswordPolicy.csv to PTF root directory...${NC}"
            mv "${BASE_PATH}/PTF/CSV-Files/PasswordPolicy.csv" "${BASE_PATH}/PTF/PasswordPolicy.csv"
        else
            echo -e "${YELLOW}[!] Warning: PasswordPolicy.csv not found in expected location${NC}"
        fi
        
        # Remove the CSV-Files directory
        if [ -d "${BASE_PATH}/PTF/CSV-Files" ]; then
            rm -rf "${BASE_PATH}/PTF/CSV-Files"
            echo -e "${GRAY}[~] Cleaned up temporary CSV-Files directory${NC}"
        fi
    else
        echo ""
        echo -e "${YELLOW}[!] Warning: PyADRecon completed with errors. Check ${PYADRECON_LOG}${NC}"
        echo -e "${YELLOW}    Hash extraction was successful, but user metadata may be incomplete.${NC}"
    fi
else
    echo ""
    echo -e "${YELLOW}[!] Step 2/2: Skipped (PyADRecon not available)${NC}"
    echo -e "${GRAY}    Only hash data has been collected.${NC}"
fi

# Move files to appropriate directories
echo ""
echo -e "${GRAY}[~] Organizing output files...${NC}"
mv "$IMPORTFILE" "${BASE_PATH}/CUSTOMER/"
mv "$LOGFILE" "${BASE_PATH}/CUSTOMER/"
mv "$PTFHASHES" "${BASE_PATH}/PTF/"

# Move PyADRecon log if it exists
if [ -f "$PYADRECON_LOG" ]; then
    mv "$PYADRECON_LOG" "${BASE_PATH}/CUSTOMER/"
fi

# Cleanup temporary files
rm -f "$USERS" "$HASHES" "$STATUS"

# Final summary
echo ""
echo "======================================================="
echo -e "${GREEN}         PASSWORD AUDIT DATA COLLECTION COMPLETE${NC}"
echo "======================================================="
echo ""
echo -e "${BLUE}Summary:${NC}"
echo -e "  • User accounts processed: ${USER_COUNT}"
echo -e "  • Output directory: ${BASE_PATH}"
echo ""
echo -e "${GRAY}Files created:${NC}"
echo ""
echo -e "${YELLOW}PTF Directory (for analysis):${NC}"
echo "  └─ ${BASE_PATH}/PTF/"
echo "     ├─ $(basename $PTFHASHES)"
echo "     │  └─ Hash file with account status (hash,status)"

if [ -f "${BASE_PATH}/PTF/Users.csv" ]; then
    echo "     ├─ Users.csv"
    echo "     │  └─ User metadata from Active Directory"
else
    echo "     ├─ Users.csv (NOT CREATED - PyADRecon skipped/failed)"
fi

if [ -f "${BASE_PATH}/PTF/PasswordPolicy.csv" ]; then
    echo "     └─ PasswordPolicy.csv"
    echo "        └─ Domain password policy information"
else
    echo "     └─ PasswordPolicy.csv (NOT CREATED - PyADRecon skipped/failed)"
fi

echo ""
echo -e "${YELLOW}CUSTOMER Directory (for review):${NC}"
echo "  └─ ${BASE_PATH}/CUSTOMER/"
echo "     ├─ $(basename $IMPORTFILE)"
echo "     │  └─ Username/hash pairs for import"
echo "     └─ $(basename $LOGFILE)"
echo "        └─ Full DCSync operation log"

if [ -f "${BASE_PATH}/CUSTOMER/$(basename $PYADRECON_LOG)" ]; then
    echo "     └─ $(basename $PYADRECON_LOG)"
    echo "        └─ PyADRecon operation log"
fi

echo ""
echo -e "${RED}⚠ SECURITY REMINDERS:${NC}"
echo -e "  • These files contain sensitive credential data"
echo -e "  • Store securely and encrypt at rest"
echo -e "  • Delete securely when no longer needed (use shred)"
echo -e "  • Ensure proper authorization documentation exists"
echo -e "  • Limit access to authorized personnel only"
echo ""

# Try to open file manager (if in GUI environment)
if [ -n "$DISPLAY" ]; then
    if command -v xdg-open &> /dev/null; then
        xdg-open "$BASE_PATH" 2>/dev/null
    elif command -v nautilus &> /dev/null; then
        nautilus "$BASE_PATH" 2>/dev/null &
    fi
fi

echo -e "${GREEN}[DONE] You can now proceed with password analysis.${NC}"
echo ""
