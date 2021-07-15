Install-Module Az.Storage -Force -AllowClobber

Describe "Post depoy test(s)"{
    It "Check if function is running" {

    }

    It "Test Image resize sample" {
        $maxTries = 100
        $resizeFailed = $false
        $randNumber = [string](Get-Date -Format yyyyMMddHHmmss)
        $uploadFileName = "cdtest_$randNumber.jpg"
        $resultFileName = "cdtest_$randNumber-100x100.jpg"

        $storageAccount = Get-AzStorageAccount -ResourceGroupName $env:ResourceGroup -Name $env:StorageAccount
        Set-AzStorageBlobContent -File .\DevOps\ImageResize\TestDrawing.jpg -Container $env:ContainerName -Blob $uploadFileName -Context $storageAccount.Context

        $queueMessage = @"
{
    "CallbackUrl": "",
    "Format": {
        "Dimensions": {
            "Height": "100",
            "Width": "100"
        },
        "Input": "JPG",
        "Output": "JPG",
        "ProcessMethod": "CroppedSquare"
    },
    "Url": "https://$env:StorageAccount.blob.core.windows.net/imageresize/cdtest_$randNumber.jpg"
}
"@
        $storageQueue = Get-AzStorageQueue -Name queue -Context $storageAccount.Context

        if(Get-AzStorageBlob -Blob cdtest_$randNumber.jpg -Container $env:ContainerName -Context $storageAccount.Context)
        {
            $storageQueue.CloudQueue.AddMessageAsync([Microsoft.Azure.Storage.Queue.CloudQueueMessage]::new($queueMessage))
            
            $tries = 0
            while(!(Get-AzStorageBlob -Blob cdtest_$randNumber-100x100.jpg -Container $env:ContainerName -Context $storageAccount.Context -ErrorAction SilentlyContinue))
            {
                Start-Sleep -Seconds 3
                Write-Output "Waiting for test image to be processed..."
                if($tries -ge $maxTries)
                {
                    $resizeFailed = $true
                    break
                }
                $tries += 1
            }
            if($resizeFailed -eq $false)
            {
                Get-AzStorageBlobContent -Blob $resultFileName -Container $env:ContainerName -Context $storageAccount.Context -Force
                [void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
                $Image = [System.Drawing.Image]::FromFile($(Resolve-Path $resultFileName))
                $Image.Width | Should -Be 100
                $image.Height | Should -Be 100
            }
            else {
                "" | Should -Not -BeNullOrEmpty
            }
            # Removing test files
            Remove-AzStorageBlob -Blob $uploadFileName -Container $env:ContainerName -Context $storageAccount.Context
            Remove-AzStorageBlob -Blob $resultFileName -Container $env:ContainerName -Context $storageAccount.Context
        }
    }
}