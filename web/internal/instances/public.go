package instances

import "strings"

// What leaves this server through /rest/local-instances and /rest/all-instances.
//
// The descriptors hold secrets (JMX passwords, LDAP/CMIS/Matrix/Jitsi/CalDAV secrets, OAuth client secrets,
// certbot EAB keys, ...). They are filtered at
// this boundary (Local() keeps everything for internal rendering). The rule is deny-by-pattern on the key
// name, so a secret added to config.j2 later is still covered as long as it is named like one.
//
// No page reads any of these keys except INSTANCE_TOKEN, used as an
// on/off flag by componentUpgradeEligibility, which is why it is replaced by "1" instead of dropped.

// secretKeyFragments are matched anywhere in the upper-cased key.
var secretKeyFragments = []string{
	"PASSWORD", "PASSWD", "PASSPHRASE", "PWD", "SECRET", "TOKEN", "HMAC", "CREDENTIAL", "PRIVATE",
	"ENCRYPTION", "APIKEY", "API_KEY", "ACCESS_KEY", "EAB_", "_KEY_", "KEYSTORE",
}

// neverPublished are free-form values that may carry secrets (JVM options such as -Dxxx.password=...).
var neverPublished = map[string]bool{"DEPLOYMENT_OPTS": true}

// IsSecretKey reports whether a descriptor key must not be published. INSTANCE_KEY is an identifier, not a
// secret. Any key ending in KEY is dropped (..._SHARED_KEY, ..._ENCRYPTION_KEY, ...).
func IsSecretKey(key string) bool {
	k := strings.ToUpper(key)
	if k == "INSTANCE_KEY" {
		return false
	}
	if neverPublished[k] || strings.HasSuffix(k, "KEY") {
		return true
	}
	for _, f := range secretKeyFragments {
		if strings.Contains(k, f) {
			return true
		}
	}
	return false
}

// Public returns the instance as it may be published: secret keys dropped, INSTANCE_TOKEN reduced to a
// "1"/"" flag. The input is not modified.
func (i Instance) Public() Instance {
	out := make(Instance, len(i))
	for k, v := range i {
		if k == "INSTANCE_TOKEN" {
			if i.Truthy(k) {
				out[k] = "1"
			} else {
				out[k] = ""
			}
			continue
		}
		if IsSecretKey(k) {
			continue
		}
		out[k] = v
	}
	return out
}

// Public returns a copy of the branches whose instances are safe to publish (see Instance.Public).
func (b *Branches) Public() *Branches {
	out := NewBranches()
	if b == nil {
		return out
	}
	for _, k := range b.order {
		list := make([]Instance, len(b.m[k]))
		for n, i := range b.m[k] {
			list[n] = i.Public()
		}
		out.set(k, list)
	}
	return out
}
