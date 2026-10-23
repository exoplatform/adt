package ui

import (
	"regexp"
	"strconv"
	"strings"
	"time"

	"github.com/exoplatform/adt/web/internal/instances"
)

// CardOpts are the options of an instance card. Start from NewCardOpts(): its zero-value-unsafe fields
// carry the defaults (info icon on, all badges, addon style, actions on).
type CardOpts struct {
	// RichName shows visibility + app-server icons inside the product link.
	RichName bool
	// InfoIcon shows the product info popover icon (ignored when RichName).
	InfoIcon bool
	// ShowVisibilityIcon / VisibilityIcon: false = hidden, else the color, "" = none.
	ShowVisibilityIcon bool
	VisibilityIcon     string
	// LinkText overrides the link text of ProductOpenLink (ignored when RichName).
	LinkText string
	// EnforceSSL enforces SSL on the product link (ignored when RichName).
	EnforceSSL bool
	// MetaDownloadFirst shows the download icon before the version.
	MetaDownloadFirst bool
	// ActionsTop is the pre-rendered html of the top-right action icons.
	ActionsTop string
	// ShowBuiltAge also shows "built X ago".
	ShowBuiltAge bool
	// FeatureLabel shows the FB SCM branch label (feature branches only).
	FeatureLabel bool
	// FBBadges shows the FB status/issue/edit/deploy row (feature branches only).
	FBBadges bool
	// Badges is the ordered subset of: upgrade, patch, certbot, dev, staging, debug, addons.
	Badges []string
	// BadgesAddonStyle: badge-pill style (true) vs bare tooltipped icon (false).
	BadgesAddonStyle bool
	// Labels shows Labels().
	Labels bool
	// Actions shows the DeploymentActions() button group.
	Actions bool
}

// NewCardOpts returns the default options of an instance card.
func NewCardOpts() CardOpts {
	return CardOpts{
		InfoIcon:         true,
		Badges:           []string{"upgrade", "patch", "certbot", "dev", "staging", "debug", "addons"},
		BadgesAddonStyle: true,
		Actions:          true,
	}
}

var artifactDateRe = regexp.MustCompile(`-(20\d{2})(\d{2})(\d{2})(?:\D|$)`)

type artifactAge struct{ String, Class, Title string }

// artifactAgeFromVersion gives the age relative to today of the build day found in a version
// string (-YYYYMMDD).
func artifactAgeFromVersion(versions string, now time.Time) artifactAge {
	if m := artifactDateRe.FindStringSubmatch(versions); m != nil {
		y, _ := strconv.Atoi(m[1])
		mo, _ := strconv.Atoi(m[2])
		d, _ := strconv.Atoi(m[3])
		built := time.Date(y, time.Month(mo), d, 0, 0, 0, 0, time.UTC)
		if built.Year() == y && int(built.Month()) == mo && built.Day() == d {
			ny, nm, nd := now.Date()
			today := time.Date(ny, nm, nd, 0, 0, 0, 0, time.UTC)
			days := int(today.Sub(built).Hours() / 24)
			if days < 0 {
				days = -days // %a is the absolute difference
			}
			a := artifactAge{Title: "Built on " + built.Format("2006-01-02") + " (from the version)"}
			if days == 0 {
				a.String = "today"
			} else {
				a.String = strconv.Itoa(days) + " day(s) ago"
			}
			switch {
			case days > 5:
				a.Class = "red"
			case days > 2:
				a.Class = "orange"
			default:
				a.Class = "green"
			}
			return a
		}
	}
	return artifactAge{}
}

// InstanceCard renders the one shared implementation of the `.instance-card` markup.
func (c *Ctx) InstanceCard(inst instances.Instance, o CardOpts) string {
	var badges strings.Builder
	for _, badge := range o.Badges {
		switch badge {
		case "upgrade":
			badges.WriteString(UpgradeEligibility(inst, o.BadgesAddonStyle))
		case "patch":
			badges.WriteString(PatchInstallation(inst, o.BadgesAddonStyle))
		case "certbot":
			badges.WriteString(CertbotEnabled(inst, o.BadgesAddonStyle))
		case "dev":
			badges.WriteString(DevModeEnabled(inst, o.BadgesAddonStyle))
		case "staging":
			badges.WriteString(StagingModeEnabled(inst, o.BadgesAddonStyle))
		case "debug":
			badges.WriteString(DebugModeEnabled(c, inst, o.BadgesAddonStyle))
		case "addons":
			badges.WriteString(AddonsTags(inst))
		}
	}
	if o.Labels {
		badges.WriteString(Labels(inst))
	}
	badgeMarkup := badges.String()

	isFB := instances.IsFeatureBranch(inst)

	// Edit/restart controls always live in the top-right tools slot, in the same order everywhere
	tools := o.ActionsTop
	if o.FBBadges && isFB {
		tools += FBDeployIcon(inst) + FBEditIcon(c, inst)
	}

	sortVersion := inst.Str("PRODUCT_VERSION")
	if inst.Has("ARTIFACT_TIMESTAMP") {
		sortVersion = inst.Str("ARTIFACT_TIMESTAMP")
	}
	sortStatus := "0"
	up := inst.Str("DEPLOYMENT_STATUS") == "Up"
	if up {
		sortStatus = "1"
	}
	card := cardData{
		SortStatus: sortStatus, SortVersion: sortVersion, SortDeployed: inst.Str("DEPLOYMENT_DATE"),
		Up: up, RichName: o.RichName, MetaDownloadFirst: o.MetaDownloadFirst,
		Download: DownloadIcon(inst), Version: ProductVersion(inst),
		Tools: tools, Database: DatabaseIcon(inst), ShowBuilt: o.ShowBuiltAge,
		DeployedAge: inst.Str("DEPLOYMENT_AGE_STRING"), Badges: badgeMarkup,
		FBBadges: o.FBBadges && isFB, Actions: o.Actions,
	}
	if o.RichName {
		color := "success"
		if !inst.Truthy("DEPLOYMENT_APACHE_VHOST_ALIAS") {
			color = ""
		}
		label := VisibilityIcon(inst, color)
		label += " " + AppServerIcon(inst)
		label += " " + ProductHtmlLabel(inst, false)
		card.InfoIcon = ProductInfoIcon(inst)
		card.Link = ProductOpenLink(inst, label, false)
	} else {
		if o.InfoIcon {
			card.InfoIcon = ProductInfoIcon(inst)
		}
		if o.ShowVisibilityIcon {
			card.Visibility = VisibilityIcon(inst, o.VisibilityIcon)
		}
		card.Link = ProductOpenLink(inst, o.LinkText, o.EnforceSSL)
	}
	if o.FeatureLabel && isFB {
		card.FeatureLabel = FBScmLabel(inst)
	}
	if o.ShowBuiltAge {
		// Servers not yet updated still send "Unknown" for releases: derive it here too
		if !inst.Truthy("ARTIFACT_AGE_STRING") || inst.Str("ARTIFACT_AGE_STRING") == "Unknown" {
			card.Built = artifactAgeFromVersion(inst.Str("ARTIFACT_TIMESTAMP")+" "+inst.Str("PRODUCT_VERSION"), c.now())
		} else {
			card.Built = artifactAge{String: inst.Str("ARTIFACT_AGE_STRING"), Class: inst.Str("ARTIFACT_AGE_CLASS"), Title: "Time since artifact was built"}
			if inst.Has("ARTIFACT_AGE_TITLE") {
				card.Built.Title = inst.Str("ARTIFACT_AGE_TITLE")
			}
		}
	}
	if card.FBBadges {
		card.FBStatus = FBStatusLabel(inst)
		if inst.Truthy("ISSUE_NUM") {
			card.FBIssue = FBIssueLabel(inst)
		}
	}
	if o.Actions {
		card.ActionsMarkup = DeploymentActions(inst)
	}
	return tpl.Must("card.tmpl", card)
}

// cardData is what card.tmpl prints: the pre-rendered parts of an instance card.
type cardData struct {
	SortStatus, SortVersion, SortDeployed string
	Up, RichName, MetaDownloadFirst       bool
	InfoIcon, Visibility, Link            string
	Download, Version, Tools, Database    string
	FeatureLabel                          string
	ShowBuilt                             bool
	Built                                 artifactAge
	DeployedAge                           string
	FBBadges                              bool
	FBStatus, FBIssue, Badges             string
	Actions                               bool
	ActionsMarkup                         string
}
