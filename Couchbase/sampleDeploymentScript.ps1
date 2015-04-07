Add-AzureAccount
Switch-AzureMode -Name "AzureResourceManager" 

# Make sure you are pointing to the correct subscription
Get-AzureSubscription -Current

$parameters = @{
adminUsername=  "couchadmin";
adminPassword=  "P@ssword1";
dnsNameforLBIP= "fs180cbdeploy";
storageAccountName = "fs180armdeploy";
subscriptionId=  "b4249f2a-2378-4c3e-8e5a-214140d7f1c0";
targetRegion=  "West US";
virtualNetworkName=  "couchVnet";
cbClusterName=  "couchbase-fullscale";
vmSizeNodes= "Standard_A2";
couchNodes= 2;
creationDateFormatted = (Get-Date).ToString("MMddyyhhmm")
}