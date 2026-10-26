package gitx

import (
	"os"
	"strings"
)

// Repo is one tracked repository: its directory name (ADT_DATA/sources/<Name>.git) and its label.
type Repo struct{ Name, Label string }

var repositories = []Repo{
	{"maven-depmgt-pom", "DEPMGT POM"},
	{"gatein-wci", "GateIn WCI"},
	{"kernel", "Kernel"},
	{"core", "Core"},
	{"ws", "WS"},
	{"portlet-container", "Portlet Container"},
	{"gatein-sso", "GateIn SSO"},
	{"portal", "Portal"},
	{"platform-ui", "PLF UI"},
	{"commons", "Commons"},
	{"social", "Social"},
	{"layout", "Layout"},
	{"gamification", "Gamification"},
	{"kudos", "Kudos"},
	{"perk-store", "Perk store"},
	{"wallet", "Wallet"},
	{"push-notifications", "Push notifications"},
	{"app-center", "App Center"},
	{"auth-server", "Auth Server"},
	{"mcp-server", "Mcp Server"},
	{"analytics", "Analytics"},
	{"notes", "Notes"},
	{"content", "Content"},
	{"poll", "Poll"},
	{"ai", "AI"},
	{"matrix", "Matrix"},
	{"task", "TASK"},
	{"gamification-github", "Gamification Github"},
	{"gamification-twitter", "Gamification Twitter"},
	{"gamification-crowdin", "Gamification Crowdin"},
	{"gamification-evm", "Gamification EVM"},
	{"pwa", "Progressive Web App"},
	{"ide", "Integrated Dev Env"},
	{"deeds-tenant", "Deeds Tenant"},
	{"addons-manager", "Addons Manager"},
	{"meeds", "Meeds Distribution"},
	{"maven-exo-depmgt-pom", "DEPMGT POM EXO"},
	{"commons-exo", "Commons eXo"},
	{"jcr", "JCR"},
	{"ecms", "ECMS"},
	{"mail-integration", "Mail Integration"},
	{"email-connector", "Email Connector"},
	{"dlp", "Data Leak Prevention"},
	{"agenda", "Agenda"},
	{"agenda-connectors", "Agenda Connectors"},
	{"caldav-integration", "Caldav Integration"},
	{"chat-application", "Chat application"},
	{"digital-workplace", "Digital Workplace"},
	{"onlyoffice", "Only Office"},
	{"saml2-addon", "SAML2"},
	{"web-conferencing", "Web conferencing"},
	{"jitsi-call", "Jitsi Call"},
	{"jitsi", "Jitsi"},
	{"external-visio-connector", "Ext Visio Connector"},
	{"multifactor-authentication", "Multifactor Authentication"},
	{"documents", "Documents"},
	{"forms", "Forms"},
	{"processes", "Processes"},
	{"automatic-translation", "Automatic Translation"},
	{"anti-bruteforce", "Anti Brute Force"},
	{"anti-malware", "Anti Malware"},
	{"data-upgrade", "Data upgrade"},
	{"platform-private-distributions", "PLF Private Dist"},
}

// Repositories returns the tracked repositories, in display order.
func Repositories() []Repo { return append([]Repo(nil), repositories...) }

// RepositoryNames returns the names of the tracked repositories, in display order.
func RepositoryNames() []string {
	names := make([]string, len(repositories))
	for i, r := range repositories {
		names[i] = r.Name
	}
	return names
}

// RepositoryLabel returns the label of a tracked repository.
func RepositoryLabel(name string) (string, bool) {
	for _, r := range repositories {
		if r.Name == name {
			return r.Label, true
		}
	}
	return "", false
}

var moduleCiPrefix = map[string]string{
	"agenda":                     "addon-",
	"agenda-connectors":          "addon-",
	"caldav-integration":         "addon-",
	"dlp":                        "addon-",
	"mail-integration":           "addon-",
	"email-connector":            "addon-",
	"anti-bruteforce":            "addon-",
	"anti-malware":               "addon-",
	"analytics":                  "meeds-addon-",
	"poll":                       "meeds-addon-",
	"ai":                         "meeds-addon-",
	"matrix":                     "meeds-addon-",
	"gamification-github":        "meeds-addon-",
	"gamification-twitter":       "meeds-addon-",
	"gamification-crowdin":       "meeds-addon-",
	"gamification-evm":           "meeds-addon-",
	"pwa":                        "meeds-addon-",
	"ide":                        "meeds-addon-",
	"deeds-tenant":               "meeds-addon-",
	"automatic-translation":      "addon-",
	"gatein-wci":                 "meeds-",
	"kernel":                     "meeds-",
	"core":                       "meeds-",
	"documents":                  "addon-",
	"forms":                      "addon-",
	"ws":                         "meeds-",
	"portlet-container":          "meeds-",
	"gatein-sso":                 "meeds-",
	"portal":                     "meeds-",
	"maven-depmgt-pom":           "meeds-",
	"platform-ui":                "meeds-",
	"commons":                    "meeds-",
	"social":                     "meeds-",
	"layout":                     "meeds-addon-",
	"auth-server":                "meeds-addon-",
	"mcp-server":                 "meeds-addon-",
	"gamification":               "meeds-addon-",
	"wallet":                     "meeds-addon-",
	"app-center":                 "meeds-addon-",
	"kudos":                      "meeds-addon-",
	"perk-store":                 "meeds-addon-",
	"push-notifications":         "meeds-addon-",
	"notes":                      "meeds-addon-",
	"content":                    "meeds-addon-",
	"addons-manager":             "meeds-",
	"meeds":                      "meeds-",
	"jitsi":                      "addon-",
	"external-visio-connector":   "addon-",
	"chat-application":           "addon-",
	"data-upgrade":               "addon-",
	"digital-workplace":          "addon-",
	"onlyoffice":                 "addon-",
	"processes":                  "addon-",
	"saml2-addon":                "addon-",
	"task":                       "meeds-addon-",
	"web-conferencing":           "addon-",
	"microservices":              "addon-",
	"multifactor-authentication": "addon-",
}

// ModuleCiPrefix returns the CI job prefix of a module, "" when it has none.
func ModuleCiPrefix(item string) string { return moduleCiPrefix[item] }

// translationIgnored lists the projects skipped by TranslationBranches (addons with a version different
// from the product, see ACC-144).
var translationIgnored = map[string]bool{
	"agenda":                         true,
	"agenda-connectors":              true,
	"caldav-integration":             true,
	"dlp":                            true,
	"mail-integration":               true,
	"email-connector":                true,
	"anti-bruteforce":                true,
	"anti-malware":                   true,
	"analytics":                      true,
	"poll":                           true,
	"ai":                             true,
	"matrix":                         true,
	"gamification-github":            true,
	"gamification-twitter":           true,
	"gamification-crowdin":           true,
	"gamification-evm":               true,
	"pwa":                            true,
	"ide":                            true,
	"deeds-tenant":                   true,
	"automatic-translation":          true,
	"documents":                      true,
	"ecms":                           true,
	"app-center":                     true,
	"gamification":                   true,
	"gatein-portal":                  true,
	"wallet":                         true,
	"kudos":                          true,
	"perk-store":                     true,
	"push-notifications":             true,
	"notes":                          true,
	"content":                        true,
	"commons":                        true,
	"chat-application":               true,
	"digital-workplace":              true,
	"layout":                         true,
	"auth-server":                    true,
	"mcp-server":                     true,
	"meeds":                          true,
	"onlyoffice":                     true,
	"platform-ui":                    true,
	"platform-private-distributions": true,
	"saml2-addon":                    true,
	"social":                         true,
	"processes":                      true,
	"task":                           true,
	"wcm-template-pack":              true,
	"jitsi":                          true,
	"jitsi-call":                     true,
	"web-conferencing":               true,
	"external-visio-connector":       true,
	"multifactor-authentication":     true,
	"microservices":                  true,
}

// GitDirectoriesList returns the entries of dir whose name contains ".git" at a
// position > 0, in readdir order.
func GitDirectoriesList(dir string) ([]string, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}
	var res []string
	for _, e := range entries {
		if i := strings.Index(e.Name(), ".git"); i > 0 {
			res = append(res, e.Name())
		}
	}
	return res, nil
}

// DirectoryList returns all entries of dir except "." and "..".
func DirectoryList(dir string) ([]string, error) {
	entries, err := os.ReadDir(dir)
	if err != nil {
		return nil, err
	}
	res := make([]string, 0, len(entries))
	for _, e := range entries {
		res = append(res, e.Name())
	}
	return res, nil
}

// BaseBranchToCompareWith returns the branch to compare with: always "develop" (the translation branches).
func BaseBranchToCompareWith(org, repo, branch string) string { return DefaultBaseBranch }
