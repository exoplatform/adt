package instances

// distribAddons is the table of the add-ons distribution: product -> PRODUCT_BRANCH -> value, with a per-product default.
type distribRule struct {
	branches []string
	value    string
}

type distribProduct struct {
	products []string
	rules    []distribRule
	dflt     string
}

var distribAddons = []distribProduct{
	{products: []string{"meeds"}, rules: []distribRule{
		{[]string{"7.3.x"}, "meeds-layout / meeds-app-center / meeds-gamification / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-wallet / meeds-notes / meeds-task / meeds-auth-server / meeds-mcp-server / meeds-analytics / meeds-poll / meeds-matrix / meeds-ai / meeds-gamification-github / meeds-gamification-twitter / meeds-gamification-crowdin / meeds-content / meeds-pwa  / meeds-ide / meeds-deeds-tenant"},
		{[]string{"7.2.x"}, "meeds-layout / meeds-app-center / meeds-gamification / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-wallet / meeds-notes / meeds-task / meeds-auth-server / meeds-mcp-server / meeds-analytics / meeds-poll / meeds-matrix / meeds-ai / meeds-gamification-github / meeds-gamification-twitter / meeds-gamification-crowdin / meeds-content / meeds-pwa  / meeds-ide / meeds-deeds-tenant"},
		{[]string{"7.1.x"}, "meeds-layout / meeds-app-center / meeds-gamification / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-wallet / meeds-notes / meeds-task / meeds-analytics / meeds-poll / meeds-matrix / meeds-gamification-github / meeds-gamification-twitter / meeds-gamification-crowdin / meeds-content / meeds-pwa  / meeds-ide / meeds-deeds-tenant"},
		{[]string{"7.0.x"}, "meeds-layout / meeds-app-center / meeds-gamification / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-wallet / meeds-notes / meeds-task / meeds-analytics / meeds-poll / meeds-matrix / meeds-gamification-github / meeds-gamification-twitter / meeds-gamification-crowdin / meeds-content / meeds-pwa  / meeds-ide / meeds-deeds-tenant"},
	}, dflt: "-no-set-"},
	{products: []string{"plfcom"}, rules: []distribRule{
		{[]string{"7.3.x"}, "exo-agenda / exo-digital-workplace / exo-jcr / exo-jitsi / exo-ecms / exo-web-conferencing / exo-multifactor-authentication / exo-onlyoffice / exo-documents / meeds-app-center / meeds-gamification / meeds-layout / meeds-wallet / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-notes / meeds-task / meeds-analytics / meeds-poll / meeds-matrix / meeds-gamification-twitter / meeds-gamification-crowdin / meeds-pwa / meeds-ide"},
		{[]string{"7.2.x"}, "exo-agenda / exo-digital-workplace / exo-jcr / exo-jitsi / exo-ecms / exo-web-conferencing / exo-multifactor-authentication / exo-onlyoffice / exo-chat / exo-documents / meeds-app-center / meeds-gamification / meeds-layout / meeds-wallet / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-notes / meeds-task / meeds-analytics / meeds-poll / meeds-matrix / meeds-gamification-twitter / meeds-gamification-crowdin / meeds-pwa / meeds-ide"},
		{[]string{"7.1.x"}, "exo-agenda / exo-digital-workplace / exo-jcr / exo-jitsi / exo-ecms / exo-web-conferencing / exo-multifactor-authentication / exo-onlyoffice / exo-chat / exo-documents / meeds-app-center / meeds-gamification / meeds-layout / meeds-wallet / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-notes / meeds-task / meeds-analytics / meeds-poll / meeds-matrix / meeds-gamification-twitter / meeds-gamification-crowdin / meeds-pwa / meeds-ide"},
		{[]string{"7.0.x"}, "exo-agenda / exo-digital-workplace / exo-jcr / exo-jitsi / exo-ecms / exo-web-conferencing / exo-multifactor-authentication / exo-onlyoffice / exo-chat / exo-documents / meeds-app-center / meeds-gamification / meeds-layout / meeds-wallet / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-notes / meeds-task / meeds-analytics / meeds-poll / meeds-matrix / meeds-gamification-twitter / meeds-gamification-crowdin / meeds-pwa / meeds-ide"},
	}, dflt: "-no-set-"},
	{products: []string{"plfent"}, rules: []distribRule{
		{[]string{"7.3.x"}, "exo-agenda / exo-digital-workplace / exo-jcr / exo-jitsi / exo-ecms / exo-web-conferencing / exo-multifactor-authentication / exo-onlyoffice / exo-documents / exo-external-visio-connector / meeds-app-center / meeds-gamification / meeds-layout / meeds-wallet / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-notes / meeds-task / meeds-analytics / meeds-poll / meeds-matrix / meeds-gamification-twitter / meeds-gamification-crowdin / meeds-pwa / meeds-ide"},
		{[]string{"7.2.x"}, "exo-agenda / exo-digital-workplace / exo-jcr / exo-jitsi / exo-ecms / exo-web-conferencing / exo-multifactor-authentication / exo-onlyoffice / exo-chat / exo-documents / exo-external-visio-connector / meeds-app-center / meeds-gamification / meeds-layout / meeds-wallet / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-notes / meeds-task / meeds-analytics / meeds-poll / meeds-matrix / meeds-gamification-twitter / meeds-gamification-crowdin / meeds-pwa / meeds-ide"},
		{[]string{"7.1.x"}, "exo-agenda / exo-digital-workplace / exo-jcr / exo-jitsi / exo-ecms / exo-web-conferencing / exo-multifactor-authentication / exo-onlyoffice / exo-chat / exo-documents / exo-external-visio-connector / meeds-app-center / meeds-gamification / meeds-layout / meeds-wallet / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-notes / meeds-task / meeds-analytics / meeds-poll / meeds-matrix / meeds-gamification-twitter / meeds-gamification-crowdin / meeds-pwa / meeds-ide"},
		{[]string{"7.0.x"}, "exo-agenda / exo-digital-workplace / exo-jcr / exo-jitsi / exo-ecms / exo-web-conferencing / exo-multifactor-authentication / exo-onlyoffice / exo-chat / exo-documents / exo-external-visio-connector / meeds-app-center / meeds-gamification / meeds-layout / meeds-wallet / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-notes / meeds-task / meeds-analytics / meeds-poll / meeds-matrix / meeds-gamification-twitter / meeds-gamification-crowdin / meeds-pwa / meeds-ide"},
	}, dflt: "-no-set-"},
}

// distribAddonsDefault is the value of the outer default branch (unknown PRODUCT_NAME).
const distribAddonsDefault = "-no-set-"
