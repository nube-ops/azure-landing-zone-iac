$entry = (Get-Content $ConfigPath -Raw | ConvertFrom-Json).workloads.$Workload
if (-not $entry) { throw "No entry for workload '$Workload' in $ConfigPath." }
foreach ($p in $entry.tags.PSObject.Properties) { $tags[$p.Name] = $p.Value }