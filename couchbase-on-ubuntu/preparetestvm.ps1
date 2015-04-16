New-AzureQuickVM -Linux -ServiceName erctstcb -Name cb -ImageName "b39f27a8b8c64d52b05eac6a62ebad85__Ubuntu-12_04_5_LTS-amd64-server-20150413-en-us-30GB" -Password P@ssword1 -LinuxUser azureuser -WaitForBoot -InstanceSize Small
$vm = Get-AzureVM -ServiceName erctstcb -Name cb 
$vm = $vm | Add-AzureDataDisk -CreateNew -DiskSizeInGB 1023 -DiskLabel "d1" -LUN 0 | Add-AzureDataDisk -CreateNew -DiskSizeInGB 1023 -DiskLabel "d2" -LUN 1 

$PublicConfiguration = '{"fileUris":["http://packages.couchbase.com/releases/3.0.3/couchbase-server-enterprise_3.0.3-ubuntu12.04_amd64.deb", "https://raw.githubusercontent.com/azurermtemplates/azurermtemplates/master/shared_scripts/ubuntu/vm-disk-utils-0.1.sh"] }'


  $ExtensionName = 'CustomScriptForLinux'  
        $Publisher = 'Microsoft.OSTCExtensions'  
        $Version = '1.*' 

        Set-AzureVMExtension -ExtensionName $ExtensionName -VM  $vm -Publisher $Publisher -Version $Version -PublicConfiguration $PublicConfiguration  | Update-AzureVM

        $vm.vm.ConfigurationSets[0].InputEndpoints