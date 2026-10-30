function Initialize-DeployerIdentity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$ResourceGroupName,
        [Parameter(Mandatory)][string]$SubscriptionId,
        [Parameter(Mandatory)][string]$Location,
        [hashtable]$Tags = @{},
        [Parameter(Mandatory)][pscustomobject]$Repository,   # .Owner / .Repository
        [string]$Branch = 'main',
        [Parameter(Mandatory)][hashtable[]]$RoleAssignment   # @{ Role; Scope }
    )
    $rg       = Set-ResourceGroup -Name $ResourceGroupName -SubscriptionId $SubscriptionId -Location $Location -Tags $Tags
    $umi      = Set-UserAssignedIdentity -Name $Name -ResourceGroupName $ResourceGroupName -SubscriptionId $SubscriptionId -Location $Location -Tags $Tags
    $subject  = Get-OidcSubject -Owner $Repository.Owner -Repository $Repository.Repository -Branch $Branch
    Set-FederatedCredential -IdentityName $Name -ResourceGroupName $ResourceGroupName -SubscriptionId $SubscriptionId -Subject $subject
    foreach ($r in $RoleAssignment) {
        Set-RoleAssignment -PrincipalId $umi.PrincipalId -Role $r.Role -Scope $r.Scope
    }
    [pscustomobject]@{ Name = $Name; ResourceGroup = $rg.Name; ClientId = $umi.ClientId; PrincipalId = $umi.PrincipalId }
}