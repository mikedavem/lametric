Function Get-HourMinute{
    [CmdletBinding()]
    Param(
        [string]$HourString
    )

    If ($HourString -match '^([0-9]|0[0-9]|1[0-9]|2[0-3]):[0-5][0-9]$') {
        return $HourString
    }
    Else {
        return $null
    }
}

Function SendNotificationLaMetric{
    Param(
        [Parameter(Mandatory=$true)]
        [System.Net.mail.mailaddress]$From
        ,
        [Parameter(Mandatory=$true)]
        [String]$Subject
        ,
        [Parameter(Mandatory=$true)]
        [ValidateSet('Low','Normal','High')]
        [String]$Importance
        ,
        [Parameter(Mandatory=$true)]
        [String]$ApiKey
        ,
        [Parameter(Mandatory=$true)]
        [System.Net.IPAddress]$LametricIP
    )

    #Alert settings
    # Priority = "info, warning, critical
    Switch ($Importance){
        'Low'    { $Priority = 'info'; $Icon = "620"    }
        'Normal' { $Priority = 'warning'; $Icon = "1077" }
        'High'   { $Priority = 'critical'; $Icon ="1237" }
    }

    $SoundCategory="notifications" #notifications, alarms
    $SoundId="notification4"
    $SoundRepeat="2"

    $DisplayCount=1

    #Code
    #Build JSon
    $json=@"
{
    "priority":"$Priority",
    "model": {
        "frames": [
            {
                "icon":$Icon,
                "text":"$Subject"

            }
        ],
        "sound": {
            "category": "$SoundCategory",
            "id": "$SoundId",
            "repeat":$SoundRepeat
        },
        "cycles":$DisplayCount
    }

}
"@

    $base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("dev:$ApiKey")))
    $header = @{
        Authorization=("Basic {0}" -f $base64AuthInfo)
    }

    Invoke-RestMethod `
        -Method POST `
        -Uri ("http://"+$LametricIP+":8080/api/v2/device/notifications") `
        -ContentType "application/json" `
        -Headers $header `
        -UseBasicParsing `
        -Body $json | Out-Null
}

Function CheckAlertMailBox{
    [CmdletBinding()]
        Param(
        [Parameter(Mandatory=$true)]
        [String]$SQLFolderToSearch
        ,
        [Parameter(Mandatory=$true)]
        [System.Net.mail.mailaddress]$RecipientName
        ,
        [Parameter(Mandatory=$true)]
        [String]$RecipientPwd
        ,
        [Parameter(Mandatory=$true)]
        [Int]$TimeIntervalReadEmail
        ,
        [Parameter(Mandatory=$true)]
        [Int]$TimeIntervalSendAlert
        ,
        [Parameter(Mandatory=$true)]
        [String]$ApiKey
        ,
        [Parameter(Mandatory=$true)]
        [System.Net.IPAddress]$LametricIP
        ,
        [Parameter(Mandatory=$true)]
        [String]$StartCheckHour
        ,
        [Parameter(Mandatory=$true)]
        [String]$EndCheckHour
    )

    Try{
        [String]$dllpath = "/usr/local/share/PackageManagement/NuGet/Packages/Exchange.WebServices.Managed.Api.2.2.1.2/lib/net35/Microsoft.Exchange.WebServices.dll"
        # Windows => [String]$dllpath = "C:\Program Files\Microsoft\Exchange\Web Services\2.0\Microsoft.Exchange.WebServices.dll"
        Add-Type -Path $dllpath

        # Check if Lametric is reacheable
        SendNotificationLaMetric `
            -ApiKey $ApiKey `
            -LametricIP $LametricIP `
            -From 'TEST@domain.com' `
            -Subject 'Lametric notification is starting' `
            -Importance 'Low'

        Start-Sleep -Seconds 10

        While (1 -eq 1){
            If (-Not (Get-HourMinute $StartCheckHour) -Or -Not (Get-HourMinute $EndCheckHour)){
                Throw "($(Get-Date))StartCheckHour:$StartCheckHour or EndCheckHour:$EndCheckHour are not valid time"
            }
            Else {
                $MinCheck = Get-Date $StartCheckHour
                $MaxCheck = Get-Date $EndCheckHour
                $Now = Get-Date

                If (($MinCheck.TimeOfDay -le $Now.TimeOfDay -and $MaxCheck.TimeOfDay -ge $Now.TimeOfDay) -And `
                    (Get-Date).DayOfWeek -notin ('Saturday','Sunday')) {

                    $s = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService([Microsoft.Exchange.WebServices.Data.ExchangeVersion]::Exchange2007_SP1)
                    $s.Credentials = New-Object Net.NetworkCredential($RecipientName, $RecipientPwd)
                    $s.Url = New-Object Uri("https://outlook.office365.com/EWS/Exchange.asmx")
                    $inbox = [Microsoft.Exchange.WebServices.Data.Folder]::Bind($s,[Microsoft.Exchange.WebServices.Data.WellKnownFolderName]::Inbox)
                    # Folder
                    $fv = new-object Microsoft.Exchange.WebServices.Data.FolderView(100)
                    $fv.Traversal = [Microsoft.Exchange.WebServices.Data.FolderTraversal]::Deep
                    $SfSearchFilter = New-Object Microsoft.Exchange.WebServices.Data.SearchFilter+IsEqualTo([Microsoft.Exchange.WebServices.Data.FolderSchema]::Displayname,$SQLFolderToSearch)
                    $SQLFolder = $inbox.FindFolders($SfSearchFilter,$fv)
                    # Email
                    $iv = New-Object Microsoft.Exchange.WebServices.Data.ItemView(500)
                    $inboxfilter = New-Object Microsoft.Exchange.WebServices.Data.SearchFilter+SearchFilterCollection([Microsoft.Exchange.WebServices.Data.LogicalOperator]::And)
                    $ifisread = New-Object Microsoft.Exchange.WebServices.Data.SearchFilter+IsEqualTo([Microsoft.Exchange.WebServices.Data.EmailMessageSchema]::IsRead,$False)
                    $inboxfilter.add($ifisread)

                    Write-Host "($(Get-Date))Checking new emails in $SQLFolderToSearch ..."
                    $msgs = $s.FindItems($SQLFolder.Id, $inboxfilter, $iv)

                    # Display alerts for debugging
                    $msgs | Format-Table DateTimeCreated, Subject, Sender, DisplayTo, Importance -AutoSize

                    # Send notification to Lametric
                    foreach ($msg in $msgs.Items)
                    {
                        SendNotificationLaMetric `
                            -ApiKey $ApiKey `
                            -LametricIP $LametricIP `
                            -From $msg.Sender.Address `
                            -Subject $msg.Subject `
                            -Importance $msg.Importance | Out-Null

                        Start-Sleep -Seconds $TimeIntervalReadEmail
                    }
                }
                Else{
                    Write-Host "($(Get-Date))Outside office hours. Stop checking ..."
                }

            }

            Start-Sleep -Seconds $TimeIntervalSendAlert
        }
    }
    Catch{
        Throw $_.Exception.Message
    }
}

################################################
Register-PackageSource -Name MyNuGet -Location https://www.nuget.org/api/v2 -ProviderName NuGet | Out-Null
Install-Package Exchange.WebServices.Managed.Api -RequiredVersion 2.2.1.2 -Force | Out-Null

CheckAlertMailBox `
    -ApiKey $env:API_KEY `
    -LametricIP $env:LAMETRIC_IP `
    -SQLFolderToSearch $env:SQL_FOLDER_TOSEARCH `
    -RecipientName $env:RECIPIENT_NAME `
    -RecipientPwd $env:RECIPIENT_PWD `
    -TimeIntervalReadEmail $env:TIME_INTERVAL_READ_MAIL_S `
    -TimeIntervalSendAlert $env:TIME_INTERVAL_SEND_ALERT_S `
    -StartCheckHour $env:START_CHECK_HOUR `
    -EndCheckHour $env:END_CHECK_HOUR








