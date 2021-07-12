#Install-Module Az.Functions
#Install-Module Az.Storage

#Get-AzSubscription
$subscriptionName = "Igloo Dev - Subscription C" # Input
$subscriptionShortName = "subc"
$subscriptionShortNameCC = "SubC"

$subscriptionID = (Get-AzSubscription -SubscriptionName $subscriptionName).SubscriptionId
Set-AzContext $subscriptionID


$randString = -join((97..122) | Get-Random -Count 5 | ForEach-Object {[char]$_})
# Naming scheme <Company short name: ig><Region short name: ca/us/eu/me/as/al><Environment: p/s/d>(-)<Subscription short name>(-)<Resource type short>(-)<Random string>
$resourceGroupName = "igusp-$($subscriptionShortName)-rg-$randString"
$location = "eastus"

try{
    # Create resource group
    if(!(Get-AzResourceGroup -Name $resourceGroupName -ErrorAction SilentlyContinue))
    {
        New-AzResourceGroup -Name $resourceGroupName -Location $location
    }

    # Create service principal for GitHub CICD integration
    $SPName = "GitHub$($subscriptionShortNameCC)Connection"
    $subscription = Get-AzSubscription -SubscriptionId $subscriptionID
    
    # Talk about it later. Reset is not an option.
    if(!(Get-AzADServicePrincipal -DisplayName $SPName).DisplayName)
    {
        $servicePrincipal = New-AzADServicePrincipal -DisplayName $SPName

        $bstr = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($servicePrincipal.Secret)
        $plaintext = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($bstr)

        $OutputObject = [PSCustomObject]@{
            clientId = $servicePrincipal.ApplicationId
            clientSecret = $plaintext
            subscriptionId = $subscription.Id
            tenantId = $subscription.TenantId
        }

        Write-Output "Add this to Github secrets. Name= $($subscriptionShortName.ToUpper())_AZURE_CREDENTIALS"
        $OutputObject | ConvertTo-Json
    }
    else
    {
        Write-Output "Service Principal already exists."
    }

}
catch
{
    throw
    # TODO: Remove all created configs.
}