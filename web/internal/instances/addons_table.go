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
		{[]string{"1.5.x"}, "meeds-app-center / meeds-gamification / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-wallet / meeds-notes / meeds-task / meeds-analytics / meeds-poll / meeds-gamification-github / meeds-gamification-twitter"},
		{[]string{"1.4.x"}, "meeds-app-center / meeds-gamification / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-wallet / meeds-notes / meeds-task / meeds-analytics / meeds-poll / meeds-gamification-github"},
		{[]string{"1.3.x"}, "meeds-app-center / meeds-gamification / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-wallet / meeds-notes / meeds-task / meeds-analytics / meeds-poll / meeds-gamification-github"},
		{[]string{"1.2.x"}, "meeds-app-center / meeds-gamification / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-wallet / meeds-notes"},
		{[]string{"1.1.x"}, "meeds-es-embedded / meeds-app-center / meeds-gamification / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-wallet"},
		{[]string{"1.0.x"}, "meeds-es-embedded / meeds-app-center / meeds-gamification / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-wallet"},
	}, dflt: "-no-set-"},
	{products: []string{"plfcom"}, rules: []distribRule{
		{[]string{"7.3.x"}, "exo-agenda / exo-digital-workplace / exo-jcr / exo-jitsi / exo-ecms / exo-web-conferencing / exo-multifactor-authentication / exo-onlyoffice / exo-documents / meeds-app-center / meeds-gamification / meeds-layout / meeds-wallet / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-notes / meeds-task / meeds-analytics / meeds-poll / meeds-matrix / meeds-gamification-twitter / meeds-gamification-crowdin / meeds-pwa / meeds-ide"},
		{[]string{"7.2.x"}, "exo-agenda / exo-digital-workplace / exo-jcr / exo-jitsi / exo-ecms / exo-web-conferencing / exo-multifactor-authentication / exo-onlyoffice / exo-chat / exo-documents / meeds-app-center / meeds-gamification / meeds-layout / meeds-wallet / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-notes / meeds-task / meeds-analytics / meeds-poll / meeds-matrix / meeds-gamification-twitter / meeds-gamification-crowdin / meeds-pwa / meeds-ide"},
		{[]string{"7.1.x"}, "exo-agenda / exo-digital-workplace / exo-jcr / exo-jitsi / exo-ecms / exo-web-conferencing / exo-multifactor-authentication / exo-onlyoffice / exo-chat / exo-documents / meeds-app-center / meeds-gamification / meeds-layout / meeds-wallet / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-notes / meeds-task / meeds-analytics / meeds-poll / meeds-matrix / meeds-gamification-twitter / meeds-gamification-crowdin / meeds-pwa / meeds-ide"},
		{[]string{"7.0.x"}, "exo-agenda / exo-digital-workplace / exo-jcr / exo-jitsi / exo-ecms / exo-web-conferencing / exo-multifactor-authentication / exo-onlyoffice / exo-chat / exo-documents / meeds-app-center / meeds-gamification / meeds-layout / meeds-wallet / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-notes / meeds-task / meeds-analytics / meeds-poll / meeds-matrix / meeds-gamification-twitter / meeds-gamification-crowdin / meeds-pwa / meeds-ide"},
		{[]string{"6.5.x"}, "exo-agenda / exo-digital-workplace / exo-jcr / exo-jitsi / exo-ecms / exo-web-conferencing / exo-multifactor-authentication / exo-layout-management / exo-news / exo-onlyoffice / exo-chat / exo-documents / meeds-app-center / meeds-gamification / meeds-wallet / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-notes / meeds-task / meeds-analytics / meeds-poll"},
		{[]string{"6.4.x"}, "exo-agenda / exo-digital-workplace / exo-jcr / exo-jitsi / exo-ecms / exo-web-conferencing / exo-multifactor-authentication / exo-layout-management / exo-news / exo-onlyoffice / exo-chat / exo-documents / meeds-app-center / meeds-gamification / meeds-wallet / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-notes / meeds-task / meeds-analytics / meeds-poll"},
		{[]string{"6.3.x"}, "exo-agenda / exo-digital-workplace / exo-jcr / exo-jitsi / exo-ecms / exo-web-conferencing / exo-multifactor-authentication / exo-layout-management / exo-news / exo-onlyoffice / exo-chat / exo-documents / meeds-app-center / meeds-gamification / meeds-wallet / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-notes / meeds-task / meeds-analytics / meeds-poll"},
		{[]string{"6.2.x"}, "exo-agenda / exo-analytics / exo-digital-workplace / exo-jcr / exo-jitsi / exo-ecms / exo-tasks / exo-web-conferencing / exo-multifactor-authentication / exo-layout-management / exo-news / exo-onlyoffice / exo-chat / meeds-app-center / meeds-gamification / meeds-wallet / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-notes"},
		{[]string{"6.1.x"}, "exo-agenda / exo-analytics / exo-digital-workplace / exo-jcr / exo-jitsi / exo-ecms / exo-tasks / exo-web-conferencing / exo-layout-management / exo-news / exo-onlyoffice / exo-chat / meeds-app-center / meeds-es-embedded / meeds-gamification / meeds-wallet / meeds-kudos / meeds-perk-store / meeds-push-notifications"},
		{[]string{"6.0.x"}, "exo-digital-workplace / exo-jcr / exo-ecms / exo-calendar / exo-tasks / exo-web-conferencing / exo-layout-management / exo-news / exo-onlyoffice / exo-chat / meeds-app-center / meeds-es-embedded / meeds-gamification / meeds-wallet / meeds-kudos / meeds-perk-store / meeds-push-notifications"},
		{[]string{"5.3.x"}, "exo-es-embedded / exo-kudos / exo-perk-store / exo-wallet / exo-gamification"},
		{[]string{"5.2.x", "5.1.x", "5.0.x", "4.4.x"}, "exo-es-embedded"},
		{[]string{"4.3.x", "4.2.x", "4.1.x", "4.0.x"}, "none"},
	}, dflt: "-no-set-"},
	{products: []string{"plfent", "plfenteap"}, rules: []distribRule{
		{[]string{"7.3.x"}, "exo-agenda / exo-digital-workplace / exo-jcr / exo-jitsi / exo-ecms / exo-web-conferencing / exo-multifactor-authentication / exo-onlyoffice / exo-documents / exo-external-visio-connector / meeds-app-center / meeds-gamification / meeds-layout / meeds-wallet / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-notes / meeds-task / meeds-analytics / meeds-poll / meeds-matrix / meeds-gamification-twitter / meeds-gamification-crowdin / meeds-pwa / meeds-ide"},
		{[]string{"7.2.x"}, "exo-agenda / exo-digital-workplace / exo-jcr / exo-jitsi / exo-ecms / exo-web-conferencing / exo-multifactor-authentication / exo-onlyoffice / exo-chat / exo-documents / exo-external-visio-connector / meeds-app-center / meeds-gamification / meeds-layout / meeds-wallet / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-notes / meeds-task / meeds-analytics / meeds-poll / meeds-matrix / meeds-gamification-twitter / meeds-gamification-crowdin / meeds-pwa / meeds-ide"},
		{[]string{"7.1.x"}, "exo-agenda / exo-digital-workplace / exo-jcr / exo-jitsi / exo-ecms / exo-web-conferencing / exo-multifactor-authentication / exo-onlyoffice / exo-chat / exo-documents / exo-external-visio-connector / meeds-app-center / meeds-gamification / meeds-layout / meeds-wallet / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-notes / meeds-task / meeds-analytics / meeds-poll / meeds-matrix / meeds-gamification-twitter / meeds-gamification-crowdin / meeds-pwa / meeds-ide"},
		{[]string{"7.0.x"}, "exo-agenda / exo-digital-workplace / exo-jcr / exo-jitsi / exo-ecms / exo-web-conferencing / exo-multifactor-authentication / exo-onlyoffice / exo-chat / exo-documents / exo-external-visio-connector / meeds-app-center / meeds-gamification / meeds-layout / meeds-wallet / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-notes / meeds-task / meeds-analytics / meeds-poll / meeds-matrix / meeds-gamification-twitter / meeds-gamification-crowdin / meeds-pwa / meeds-ide"},
		{[]string{"6.5.x"}, "exo-agenda / exo-digital-workplace / exo-jcr / exo-jitsi / exo-ecms / exo-web-conferencing / exo-multifactor-authentication / exo-layout-management / exo-news / exo-onlyoffice / exo-chat / exo-documents / meeds-app-center / meeds-gamification / meeds-wallet / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-notes / meeds-task / meeds-analytics / meeds-poll"},
		{[]string{"6.4.x"}, "exo-agenda / exo-digital-workplace / exo-jcr / exo-jitsi / exo-ecms / exo-web-conferencing / exo-multifactor-authentication / exo-layout-management / exo-news / exo-onlyoffice / exo-chat / exo-documents / meeds-app-center / meeds-gamification / meeds-wallet / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-notes / meeds-task / meeds-analytics / meeds-poll"},
		{[]string{"6.3.x"}, "exo-agenda / exo-digital-workplace / exo-jcr / exo-jitsi / exo-ecms / exo-web-conferencing / exo-multifactor-authentication / exo-layout-management / exo-news / exo-onlyoffice / exo-chat / exo-documents / meeds-app-center / meeds-gamification / meeds-wallet / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-notes / meeds-task / meeds-analytics / meeds-poll"},
		{[]string{"6.2.x"}, "exo-agenda / exo-analytics / exo-digital-workplace / exo-jcr / exo-jitsi / exo-ecms / exo-tasks / exo-web-conferencing / exo-multifactor-authentication / exo-layout-management / exo-news / exo-onlyoffice / exo-chat / meeds-app-center / meeds-gamification / meeds-wallet / meeds-kudos / meeds-perk-store / meeds-push-notifications / meeds-notes"},
		{[]string{"6.1.x"}, "exo-agenda / exo-analytics / exo-digital-workplace / exo-jcr / exo-jitsi / exo-ecms / exo-tasks / exo-web-conferencing / exo-layout-management / exo-news / exo-onlyoffice / exo-chat / meeds-app-center / meeds-es-embedded / meeds-gamification / meeds-wallet / meeds-kudos / meeds-perk-store / meeds-push-notifications"},
		{[]string{"6.0.x"}, "exo-digital-workplace / exo-jcr / exo-ecms / exo-calendar / exo-tasks / exo-web-conferencing / exo-layout-management / exo-news / exo-onlyoffice / exo-chat / meeds-app-center / meeds-es-embedded / meeds-gamification / meeds-wallet / meeds-kudos / meeds-perk-store / meeds-push-notifications"},
		{[]string{"5.3.x"}, "exo-es-embedded / exo-remote-edit / exo-tasks / exo-web-pack / exo-web-conferencing / exo-enterprise-skin / exo-push-notifications / exo-kudos / exo-perk-store / exo-wallet / exo-gamification"},
		{[]string{"5.2.x"}, "exo-es-embedded / exo-remote-edit / exo-tasks / exo-web-pack / exo-web-conferencing / exo-enterprise-skin / exo-push-notifications"},
		{[]string{"5.1.x", "5.0.x"}, "exo-es-embedded / exo-remote-edit / exo-tasks / exo-web-pack / exo-web-conferencing / exo-enterprise-skin"},
		{[]string{"4.4.x"}, "exo-es-embedded"},
		{[]string{"4.3.x", "4.2.x", "4.1.x", "4.0.x"}, "none"},
	}, dflt: "-no-set-"},
	{products: []string{"plfentrial", "plfsales"}, rules: []distribRule{
		{[]string{"5.2.x"}, "exo-es-embedded / exo-remote-edit / exo-tasks / exo-web-pack / exo-web-conferencing / exo-enterprise-skin / exo-push-notifications"},
		{[]string{"5.1.x", "5.0.x"}, "exo-es-embedded / exo-remote-edit / exo-tasks / exo-web-pack / exo-web-conferencing / exo-enterprise-skin / exo-chat"},
		{[]string{"4.4.x"}, "exo-es-embedded / exo-remote-edit / exo-tasks / exo-web-pack / exo-chat"},
		{[]string{"4.3.x"}, "exo-remote-edit / exo-tasks / exo-site-templates / exo-chat / exo-video-calls"},
	}, dflt: "-no-set-"},
}

// distribAddonsDefault is the value of the outer default branch (unknown PRODUCT_NAME).
const distribAddonsDefault = "-no-set-"
