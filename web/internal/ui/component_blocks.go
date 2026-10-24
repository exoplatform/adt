package ui

// AccessInfoCards renders the JMX / Keycloak / LDAP access-info card row shared by
// the dashboard and every instance-listing page.
func AccessInfoCards() string { return tpl.Raw("comp_access_info.html") }

// DebugMenu renders the "Debug Menu" navigation card of the debug pages.
func DebugMenu() string { return tpl.Raw("comp_debug_menu.html") }
