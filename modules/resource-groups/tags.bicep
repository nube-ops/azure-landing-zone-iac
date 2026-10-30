// Governance tag contract: tag values come from workloads.json; Environment and Domain are injected.
@export()
func resolveTags(workloads object, workload string, environment string) object =>
  union({ Owner: workloads[workload].team.name }, workloads[workload].tags, { Environment: environment, Domain: workload })
