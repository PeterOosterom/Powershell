#The following script is designed to add an alias to an entire group of users simultaneously, based on their email addresses. For example, everyone with an @companyA.com email address will be assigned an alias of @companyB.com.
#Functionality:

#    Check for Required Tools:
#    The script checks if the Exchange Online tools are installed. If they are not, it installs them.
#    Admin Account Prompt:
#    The script prompts the user to specify which admin account should be used.
#    Domain Information:
#        The script asks for the current domain.
#        It then asks for the domain to be used for the aliases.
#    Logging Option:
#    Finally, the script asks if verbose logging should be enabled.

# Check if the Exchange Online Management module is installed
if (-not (Get-Module -ListAvailable -Name ExchangeOnlineManagement)) {
    Write-Host "Exchange Online Management module is not installed. Installing now..." -ForegroundColor Yellow
    
    try {
        Install-Module -Name ExchangeOnlineManagement -Force -Scope CurrentUser -AllowClobber
        Write-Host "Exchange Online Management module installed successfully." -ForegroundColor Green
    } catch {
        Write-Host "Failed to install the Exchange Online Management module: $_" -ForegroundColor Red
        exit
    }
} else {
    Write-Host "Exchange Online Management module is already installed." -ForegroundColor Green
}

# Import the Exchange Online Management module
Import-Module ExchangeOnlineManagement -ErrorAction Stop

# Prompt for the admin user to use for connecting to Exchange Online
$adminUser = Read-Host "Enter the admin user (e.g., admin@yourdomain.com)"

# Prompt for the primary domain and the alias domain
$primaryDomainInput = Read-Host "Enter the primary domain to search for (e.g., companyA.com)"
$aliasDomainInput = Read-Host "Enter the domain to be added as an alias (e.g., companyB.com)"

# Add '@' to the domains if not already present
$primaryDomain = if ($primaryDomainInput -notlike "@*") { "@$primaryDomainInput" } else { $primaryDomainInput }
$aliasDomain = if ($aliasDomainInput -notlike "@*") { "@$aliasDomainInput" } else { $aliasDomainInput }

# Validate the inputs
if (-not ($primaryDomain -like "@*.*") -or -not ($aliasDomain -like "@*.*")) {
    Write-Host "Invalid domain format. Please ensure domains contain a '.' (e.g., example.com)." -ForegroundColor Red
    exit
}

# Prompt for verbose logging
$enableVerbose = Read-Host "Enable verbose logging? (Yes/No)"
$verboseSwitch = if ($enableVerbose -match "^(Y|y|Yes|yes)$") { $true } else { $false }

# Connect to Exchange Online
if ($verboseSwitch) {
    Connect-ExchangeOnline -UserPrincipalName $adminUser -Verbose
} else {
    Connect-ExchangeOnline -UserPrincipalName $adminUser
}

# Retrieve all mailboxes where the primary domain is in any email address
$testDomainUsers = Get-Mailbox | Where-Object { $_.EmailAddresses -match "$primaryDomain" }

Write-Host "Found $($testDomainUsers.Count) mailboxes with the domain '$primaryDomain'."

# Loop through each user and add the alias if it doesn't exist
foreach ($user in $testDomainUsers) {
    $primaryAddress = $user.PrimarySmtpAddress
    Write-Host "Processing user $($user.DisplayName) with primary address $primaryAddress."

    # Construct the alias with the new domain
    $username = $primaryAddress.Split('@')[0]
    $aliasAddress = "$username$aliasDomain"

    # Check if alias already exists
    $currentAliases = $user.EmailAddresses | ForEach-Object { $_ -replace '^SMTP:', '' -replace '^smtp:', '' }
    if ($currentAliases -notcontains $aliasAddress) {
        Write-Host "Adding alias $aliasAddress to user $($user.DisplayName)."
        try {
            if ($verboseSwitch) {
                Set-Mailbox -Identity $user.Alias -EmailAddresses @{add=$aliasAddress} -Verbose
            } else {
                Set-Mailbox -Identity $user.Alias -EmailAddresses @{add=$aliasAddress}
            }
        } catch {
            Write-Host "Error adding alias to user $($user.DisplayName): $_" -ForegroundColor Red
        }
    } else {
        Write-Host "Alias $aliasAddress already exists for user $($user.DisplayName). Skipping."
    }
}

# Disconnect from Exchange Online
Disconnect-ExchangeOnline -Confirm:$false

Write-Host "Completed adding aliases."
