function Initialize-OidcIdentity {
    <#
    .SYNOPSIS
        Ensures a User-Assigned Managed Identity exists and returns its identifiers.
    .NOTES
        'az identity create' is an idempotent PUT: no list/branch pre-check needed.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$ResourceGroupName,
        [Parameter(Mandatory)][string]$Location,
        [Parameter(Mandatory)][string]$SubscriptionId,
        [hashtable]$Tags = @{}   # required by the tagging policy (Owner, Environment, CostCenter)
    )

    $tagArgs = @()
    if ($Tags.Count) { $tagArgs = @('--tags') + @($Tags.GetEnumerator() | ForEach-Object { "$($_.Key)=$($_.Value)" }) }

    $json = Invoke-WithRetry -MaxRetries 3 -DelaySeconds 5 -ErrorMessage "Failed to ensure identity '$Name'." -ScriptBlock {
        az identity create --name $Name --resource-group $ResourceGroupName `
            --location $Location --subscription $SubscriptionId @tagArgs --output json
    }

    $identity = $json | ConvertFrom-Json
    [pscustomobject]@{
        Name        = $identity.name
        ResourceId  = $identity.id
        ClientId    = $identity.clientId
        PrincipalId = $identity.principalId
        TenantId    = $identity.tenantId
    }
}