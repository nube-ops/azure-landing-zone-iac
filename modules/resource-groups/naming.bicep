@export()
func rgName(domain string, purpose string, env string, regionCode string, instance int) string =>
  'rg-${domain}-${purpose}-${env}-${regionCode}-${padLeft(string(instance), 2, '0')}'
