function Set-CIPPCPVConsent {
    [CmdletBinding()]
    param(
        $Tenantfilter,
        $APIName = "CPV Consent",
        $ExecutingUser
    )
    $Results = [System.Collections.ArrayList]@()
    $Tenant = Get-Tenants -IncludeAll -IncludeErrors | Where-Object -Property defaultDomainName -EQ $Tenantfilter
    $TenantName = $Tenant.defaultDomainName
    $TenantFilter = $Tenant.customerId

    try {
        $AppBody = @"
{
  "ApplicationGrants":[ {"EnterpriseApplicationId":"00000003-0000-0000-c000-000000000000","Scope":"Application.ReadWrite.all,DelegatedPermissionGrant.ReadWrite.All,Directory.ReadWrite.All"}],
  "ApplicationId": "$($ENV:applicationId)"
}
"@
        $CPVConsent = New-GraphpostRequest -body $AppBody -Type POST -noauthcheck $true -uri "https://api.partnercenter.microsoft.com/v1/customers/$($TenantFilter)/applicationconsents" -scope "https://api.partnercenter.microsoft.com/.default" -tenantid $env:TenantID
        $Table = Get-CIPPTable -TableName cpvtenants
        $unixtime = [int64](([datetime]::UtcNow) - (Get-Date "1/1/1970")).TotalSeconds
        $GraphRequest = @{
            LastApply     = "$unixtime"
            applicationId = "$($ENV:applicationId)"
            Tenant        = "$($tenantfilter)"
            PartitionKey  = 'Tenant'
            RowKey        = "$($tenantfilter)"
        }    
        Add-CIPPAzDataTableEntity @Table -Entity $GraphRequest -Force
        $Results.add("Successfully added CPV Application to tenant $($TenantName)") | Out-Null
        Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME  -message "Added our Service Principal to $($TenantName): $($_.Exception.message)" -Sev "Info" -tenant $($Tenantfilter)

    } 
    catch {
        $ErrorMessage = $_.Exception.Message
        if ($ErrorMessage -like '*409 (Conflict)*') { return @("We've already added our Service Principal to $($TenantName)") }

        Write-LogMessage -user $request.headers.'x-ms-client-principal' -API $APINAME  -message "Could not add our Service Principal to the client tenant $($TenantName): $($_.Exception.message)" -Sev "Error" -tenant $($Tenantfilter)
        return @("Could not add our Service Principal to the client tenant $($TenantName): $($_.Exception.message)")
    }
    return $Results
}
