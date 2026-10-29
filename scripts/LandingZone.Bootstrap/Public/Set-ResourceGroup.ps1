function Set-ResourceGroup {
    <#
    .SYNOPSIS
        Idempotently converges a resource group and its tags to the desired state.
    .DESCRIPTION
        Absent        -> create it with the desired tags.
        Present       -> merge only the desired tags that are missing or different
                         (tags added by others are preserved, never removed).
        Already right -> no write at all.
        Knows nothing about workloads.json: callers pass the desired tags (single source of truth).
    .OUTPUTS
        [pscustomobject] Name, Action (Created | TagsConverged | Unchanged), ChangedTags
    #>
    [CmdletBinding()]
    [OutputType([pscustomobject])]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$SubscriptionId,
        [Parameter(Mandatory)][string]$Location,
        [hashtable]$Tags = @{}
    )

    # '--tags k=v k=v' as separate native arguments (safe for values containing spaces).
    function ConvertTo-TagArgument([hashtable]$Table) {
        if ($Table.Count -eq 0) { return @() }
        @('--tags') + @($Table.GetEnumerator() | Sort-Object Key | ForEach-Object { "$($_.Key)=$($_.Value)" })
    }

    $exists = (az group exists --name $Name --subscription $SubscriptionId) -eq 'true'
    if ($LASTEXITCODE -ne 0) { throw "Could not check resource group '$Name' in $SubscriptionId." }

    # --- Absent: create with tags ---
    if (-not $exists) {
        $createTags = ConvertTo-TagArgument $Tags
        Write-Host "Creating resource group '$Name' in $Location..." -ForegroundColor Cyan
        $null = Invoke-WithRetry -ErrorMessage "Could not create resource group '$Name'." -ScriptBlock {
            az group create --name $Name --subscription $SubscriptionId --location $Location @createTags --output none
            if ($LASTEXITCODE -ne 0) { throw "az group create exited with code $LASTEXITCODE." }
        }
        return [pscustomobject]@{ Name = $Name; Action = 'Created'; ChangedTags = @($Tags.Keys | Sort-Object) }
    }

    # --- Present: read current state ---
    $json = az group show --name $Name --subscription $SubscriptionId --query '{location:location, tags:tags}' --output json
    if ($LASTEXITCODE -ne 0) { throw "Could not read resource group '$Name' in $SubscriptionId." }
    $current = $json | ConvertFrom-Json -AsHashtable

    # A resource group's location is immutable: surface it, never try to "fix" it.
    if ($current.location -ne $Location) {
        Write-Warning "Resource group '$Name' exists in '$($current.location)', expected '$Location'. Location cannot be changed in place."
    }

    # --- Compare desired vs actual; write only on drift ---
    $drift = Get-TagDrift -Desired $Tags -Actual $current.tags
    if ($drift.Count -eq 0) {
        Write-Host "Resource group '$Name' already exists with the expected tags. Skipping." -ForegroundColor Green
        return [pscustomobject]@{ Name = $Name; Action = 'Unchanged'; ChangedTags = @() }
    }

    $mergeTags = ConvertTo-TagArgument $drift
    Write-Host "Resource group '$Name' tag drift detected ($($drift.Keys -join ', ')). Merging..." -ForegroundColor Cyan
    $null = Invoke-WithRetry -ErrorMessage "Could not merge tags onto resource group '$Name'." -ScriptBlock {
        az tag update --resource-id "/subscriptions/$SubscriptionId/resourceGroups/$Name" --operation Merge @mergeTags --output none
        if ($LASTEXITCODE -ne 0) { throw "az tag update exited with code $LASTEXITCODE." }
    }
    [pscustomobject]@{ Name = $Name; Action = 'TagsConverged'; ChangedTags = @($drift.Keys | Sort-Object) }
}