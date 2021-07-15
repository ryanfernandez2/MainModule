#Install-Module Az.Functions
#Install-Module Az.Storage

#Get-AzSubscription
$subscriptionName = "Igloo Dev - Subscription A" # Input
$subscriptionShortName = "suba"
$AppStorageUniqueName = "videoprocess"
$AppStorageUniqueName_8L = "vidiproc"

# Needs to be passed in. Check if these can be made into modules.
$randString = "fdzap"
$resourceGroupName = "igusp-$subscriptionShortName-rg-$randString"

$subscriptionID = (Get-AzSubscription -SubscriptionName $subscriptionName).SubscriptionId
Set-AzContext $subscriptionID

# Naming scheme <Company short name: ig><Region short name: ca/us/eu/me/as/al><Environment: p/s/d>(-)<Subscription short name>(-)<Resource type short>(-)<resource name>(-)<Random string>
# TODO: Make sure the name conforms to 3-24 letters.
$storageAccountName = "igusp$($subscriptionShortName)sa$($AppStorageUniqueName_8L)$($randString)"
$functionName = "igusp-$($subscriptionShortName)-fn-$($AppStorageUniqueName)-$($randString)"
$queueName = "queue"
$blobName = "videoprocess"
$tempPath = 'D:\local\temp'
$componentsPath = "D:\home\site\wwwroot\$($functionName)\Components"

$location = "eastus"
$saSkuName = "Standard_LRS"
$saKind = "StorageV2"
$runTime = "DotNet"
$runTimeVersion = "3"
$osType = "Windows"

try
{
    # Create storage account
    if(!(Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName -ErrorAction SilentlyContinue))
    {
        New-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName -Location $location -SkuName $saSkuName -Kind $saKind
    }

    # Create queue and a blob storage inside the storage account
    $storageAccount = Get-AzStorageAccount -ResourceGroupName $resourceGroupName -Name $storageAccountName
    if(!(Get-AzStorageQueue -Name $queueName -Context $storageAccount.Context -ErrorAction SilentlyContinue))
    {
        New-AzStorageQueue -Name $queueName -Context $storageAccount.Context
    }
    if(!(Get-AzStorageContainer -Name $blobName -Context $storageAccount.Context -ErrorAction SilentlyContinue))
    {
        New-AzStorageContainer -Name $blobName -Permission Blob -Context $storageAccount.Context
    }

    # Create function app
    Register-AzResourceProvider -ProviderNamespace 'Microsoft.Web' # TODO: Check requirement
    # TODO: Application insights was not enabled by default. Message:WARNING: Unable to create the Application Insights for the function app. Creation of Application Insights will help you monitor and diagnose your function apps in the Azure Portal. Use the 'New-AzApplicationInsights' cmdlet or the Azure Portal to create a new Application Insights project. After that, use the 'Update-AzFunctionApp' cmdlet to update Application Insights for your function app.
    if(!(Get-AzFunctionApp -Name $functionName -ResourceGroupName $resourceGroupName))
    {
        New-AzFunctionApp -ResourceGroupName $resourceGroupName -Name $functionName -StorageAccountName $storageAccountName -Location $location -Runtime $runTime -FunctionsVersion $runTimeVersion -OSType $osType
    }
    # Update function application settings
    $saKey = (Get-AzStorageAccountKey -ResourceGroupName $resourceGroupName -Name $storageAccountName | Where-Object {$_.KeyName -eq "key1"}).Value
    $connectionString = "DefaultEndpointsProtocol=https;AccountName=$($storageAccountName);AccountKey=$($saKey);EndpointSuffix=core.windows.net"
    Update-AzFunctionAppSetting -Name $functionName -ResourceGroupName $resourceGroupName -AppSetting @{"ConnectionString" = $connectionString; "TempPath" = $tempPath; "ComponentsPath" = $componentsPath}
    # Update function app managed identity
    Update-AzFunctionApp -Name $functionName -ResourceGroupName $resourceGroupName -IdentityType SystemAssigned
    $managedIdentityId = (Get-AzADServicePrincipal -DisplayNameBeginsWith $functionName).Id
    New-AzRoleAssignment -ObjectId $managedIdentityId -RoleDefinitionName "Storage Blob Data Contributor" -Scope "/subscriptions/$subscriptionID"

    Write-Output @"
    Add these to the TenantList.json file in workflows.
    functionname = $functionName
    resourcegroup = $resourceGroupName
    storageaccount = $storageAccountName
    queuename = $queueName
    blobname = $blobName

    Full string:
    { "functionname": "$functionName", "secretname": "$($subscriptionShortName.ToUpper())_AZURE_CREDENTIALS", "resourcegroup": "$resourceGroupName", "storageaccount": "$storageAccountName", "queuename": "$queueName", "blobname": "$blobName" }
"@

}
catch
{
    throw
    # TODO: Remove all created configs.
}