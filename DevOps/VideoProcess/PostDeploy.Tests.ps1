Install-Module Az.Storage -Force -AllowClobber

Describe "Post depoy tests"{
    BeforeAll{
        $maxTries = 200
        $uploadFileLocation = ".\DevOps\VideoProcess\SampleVideo1MB.mp4"
        $resizeFailed = $false
        $randNumber = [string](Get-Date -Format yyyyMMddHHmmss)
        $uploadFileName = "cdtest_$randNumber.mp4"
        $resultVideoFileName = "cdtest_$randNumber-small.mp4"
        $resultThumbnailFileName = "cdtest_$randNumber-small.jpg"

        $storageAccount = Get-AzStorageAccount -ResourceGroupName $env:ResourceGroup -Name $env:StorageAccount
        Set-AzStorageBlobContent -File $uploadFileLocation -Container $env:ContainerName -Blob $uploadFileName -Context $storageAccount.Context

        $queueMessage = @"
{
    "CallbackUrl": "",
    "Format": "x264.small",
    "Url": "https://$env:StorageAccount.blob.core.windows.net/videoprocess/$($uploadFileName)"
}
"@
        $storageQueue = Get-AzStorageQueue -Name queue -Context $storageAccount.Context

        if(Get-AzStorageBlob -Blob $uploadFileName -Container $env:ContainerName -Context $storageAccount.Context)
        {
            $storageQueue.CloudQueue.AddMessageAsync([Microsoft.Azure.Storage.Queue.CloudQueueMessage]::new($queueMessage))
            
            $tries = 0
            while(!(Get-AzStorageBlob -Blob $resultFileName -Container $env:ContainerName -Context $storageAccount.Context -ErrorAction SilentlyContinue))
            {
                Start-Sleep -Seconds 3
                Write-Output "Waiting for test video to be processed..."
                if($tries -ge $maxTries)
                {
                    $resizeFailed = $true
                    break
                }
                $tries += 1
            }
            if($resizeFailed -eq $false)
            {
                Get-AzStorageBlobContent -Blob $resultVideoFileName -Container $env:ContainerName -Context $storageAccount.Context -Force
                Get-AzStorageBlobContent -Blob $resultThumbnailFileName -Container $env:ContainerName -Context $storageAccount.Context -Force
                
            }
        }
        AfterAll {            
            Remove-AzStorageBlob -Blob $uploadFileName -Container $env:ContainerName -Context $storageAccount.Context
            Remove-AzStorageBlob -Blob $resultVideoFileName -Container $env:ContainerName -Context $storageAccount.Context
            Remove-AzStorageBlob -Blob $resultThumbnailFileName -Container $env:ContainerName -Context $storageAccount.Context
        }
    }
    It "Check if video got processed" {
        $videoInfo = [string]$(.\TaskVideoProcess\src\Components\ffprobe.exe -show_streams -pretty $($resultVideoFileName))
        $videoInfo | Should -Match "codec_name=h264"
    }

    It "Check if thumbnail got generated" {        
        [void][System.Reflection.Assembly]::LoadWithPartialName("System.Drawing")
        $Image = [System.Drawing.Image]::FromFile($(Resolve-Path $resultThumbnailFileName))
        $Image.Width | Should -BeGreaterOrEqual 1
        $image.Height | Should -BeGreaterOrEqual 1
    }
}