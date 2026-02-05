This script can be run on Linux.

It prompts for domain details such as:

- domain name
- ip address of domain controller
- username with dcsync rights
- password of the username

It will then use `impacket-secretsdump` to extract NT hashes from the domain controller as well as `PyADRecon` to obtain user details from LDAP.

The script will parse the output and create two separate folders with output files:

- A directory `CUSTOMER` with detailed information about Active Directory users and their NT password hashes. The import file in this directory will later be used to establish a reference between an AD user and a cracked password hash.
- A directory `PTF` with information about NT password hashes and a separate user CSV file. This folder may be shared with an external security vendor that conducts offline password cracking. User information are not linked to an extracted NT password hash.
