Install-Module Az.Functions -Force -AllowClobber
Install-Module Az.Storage -Force -AllowClobber
Install-Module Az.Resources -Force -AllowClobber
Install-Module Az.Accounts -Force -AllowClobber

Describe "Testing subscription configurations"{
    
    Context "Making sure environment variables were passed successfully" {
        It "Check Function name env"{
            $env:FunctionName | Should -Not -BeNullOrEmpty
        }
        It "Check Resource Group env"{
            $env:ResourceGroup | Should -Not -BeNullOrEmpty
        }
        It "Check Storage Account env"{
            $env:StorageAccount | Should -Not -BeNullOrEmpty
        }
        It "Check Queue name env"{
            $env:QueueName | Should -Not -BeNullOrEmpty
        }
        It "Check Blob name env"{
            $env:BlobName | Should -Not -BeNullOrEmpty
        }
    }
    
    Context "Testing non-function configurations" {
        It "Check if Resource Group exists"{
            (Get-AzResourceGroup).ResourceGroupName -contains $env:ResourceGroup | Should -Be $true
        }
        It "Check if Storage Account exists"{
            (Get-AzStorageAccount -Name $env:StorageAccount -ResourceGroupName $env:ResourceGroup).StorageAccountName | Should -Be $env:StorageAccount
        }
        It "Check if Storage Queue exists" {
            $storageContext = (Get-AzStorageAccount -Name $env:StorageAccount -ResourceGroupName $env:ResourceGroup).Context
            (Get-AzStorageQueue -Name $env:QueueName -Context $storageContext).Name -contains "$($env:QueueName)" | Should -Be $true
        }
        It "Check if Storage Blob exists" {
            $storageContext = (Get-AzStorageAccount -Name $env:StorageAccount -ResourceGroupName $env:ResourceGroup).Context
            (Get-AzStorageContainer -Name $env:BlobName -Context $storageContext).Name -contains "$($env:BlobName)" | Should -Be $true
        }
    }

    Context "Testing Function App configurations" {
        It "Check if Function App exists"{
            (Get-AzFunctionApp -Name $env:FunctionName -ResourceGroupName $env:ResourceGroup).Name | Should -Be $env:FunctionName
        }
        It "Check if Function App identity type is system assigned"{
            (Get-AzFunctionApp -Name $env:FunctionName -ResourceGroupName $env:ResourceGroup).IdentityType | Should -Be 'SystemAssigned'
        }
        <#
        It "Check if Function App identity has 'Storage Blob Data Contributor' role"{
            $id = (Get-AzFunctionApp -Name $env:FunctionName -ResourceGroupName $env:ResourceGroup).IdentityPrincipalId
            (Get-AzRoleAssignment -ObjectId $id).RoleDefinitionName -contains 'Storage Blob Data Contributor' | Should -Be $true
        }
        #>
        It "Check TempPath app setting"{
            (Get-AzFunctionAppSetting -Name $env:FunctionName -ResourceGroupName $env:ResourceGroup)['TempPath'] | Should -Be 'D:\local\temp'
        }        
        It "Check ConnctionString app setting"{
            (Get-AzFunctionAppSetting -Name $env:FunctionName -ResourceGroupName $env:ResourceGroup)['ConnectionString'] | Should -Not -BeNullOrEmpty
        }
    }
}
