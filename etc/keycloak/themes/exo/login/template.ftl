<#--
 Copyright (C) 2026 eXo Platform SAS.

 This program is free software: you can redistribute it and/or modify
 it under the terms of the GNU Affero General Public License as published by
 the Free Software Foundation, either version 3 of the License, or
 (at your option) any later version.

 This program is distributed in the hope that it will be useful,
 but WITHOUT ANY WARRANTY; without even the implied warranty of
 MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 GNU Affero General Public License for more details.

 You should have received a copy of the GNU Affero General Public License
 along with this program.  If not, see <https://www.gnu.org/licenses/>.
-->
<#import "footer.ftl" as loginFooter>
<#macro registrationLayout bodyClass="" displayInfo=false displayMessage=true displayRequiredFields=false>
<!DOCTYPE html>
<html class="${properties.kcHtmlClass!}" lang="${lang}"<#if realm.internationalizationEnabled> dir="${(locale.rtl)?then('rtl','ltr')}"</#if>>
<head>
    <meta charset="utf-8">
    <meta name="robots" content="noindex, nofollow">
    <meta name="color-scheme" content="light dark">
    <meta name="viewport" content="width=device-width, initial-scale=1">
    <title>${msg("loginTitle",(realm.displayName!''))}</title>
    <link rel="icon" type="image/svg+xml" href="${url.resourcesPath}/img/favicon.svg" />
    <script>
        // Before first paint: an explicit choice wins, otherwise the system preference decides (see custom.css).
        (function () {
            try {
                var stored = localStorage.getItem('exo-theme');
                if (stored === 'dark' || stored === 'light') {
                    document.documentElement.setAttribute('data-theme', stored);
                }
            } catch (e) {}
        })();
    </script>
    <link href="${url.resourcesCommonPath}/vendor/patternfly-v4/patternfly.min.css" rel="stylesheet" />
    <link href="${url.resourcesCommonPath}/vendor/patternfly-v3/css/patternfly.min.css" rel="stylesheet" />
    <link href="${url.resourcesCommonPath}/vendor/patternfly-v3/css/patternfly-additions.min.css" rel="stylesheet" />
    <link href="${url.resourcesCommonPath}/lib/pficon/pficon.css" rel="stylesheet" />
    <link href="${url.resourcesPath}/css/custom.css" rel="stylesheet" />
    <script type="importmap">
        {
            "imports": {
                "rfc4648": "${url.resourcesCommonPath}/vendor/rfc4648/rfc4648.js"
            }
        }
    </script>
    <#if properties.scripts?has_content>
        <#list properties.scripts?split(' ') as script>
            <script src="${url.resourcesPath}/${script}" type="text/javascript"></script>
        </#list>
    </#if>
    <#if scripts??>
        <#list scripts as script>
            <script src="${script}" type="text/javascript"></script>
        </#list>
    </#if>
    <script type="module" src="${url.resourcesPath}/js/passwordVisibility.js"></script>
    <script type="module">
        <#outputformat "JavaScript">
        import { startSessionPolling } from ${(url.resourcesPath + "/js/authChecker.js")?c};

        startSessionPolling(
            ${url.ssoLoginInOtherTabsUrl?c}
        );
        </#outputformat>
    </script>
    <script type="module" src="${url.resourcesPath}/js/onceLinks.js"></script>
    <#if authenticationSession??>
        <script type="module">
            <#outputformat "JavaScript">
            import { checkAuthSession } from ${(url.resourcesPath + "/js/authChecker.js")?c};

            checkAuthSession(
                ${authenticationSession.authSessionIdHash?c}
            );
            </#outputformat>
        </script>
    </#if>
    <script src="${url.resourcesPath}/js/themeToggle.js" defer></script>
</head>

<body class="${properties.kcBodyClass!}" data-page-id="login-${pageId}">
    <div class="exo-split-layout">
        <div class="exo-split-left">
            <div class="exo-split-left-inner">
                <div class="exo-brand">
                    <div class="exo-brand-logo">eXo</div>
                    <p class="exo-brand-name">${msg("brandName")}</p>
                    <p class="exo-brand-desc">${msg("brandTagline")}</p>
                </div>
                <div class="exo-brand-footer">
                    <p>${msg("brandFooter")}</p>
                </div>
            </div>
        </div>
        <main class="exo-split-right">
            <div class="exo-split-right-inner">
                <div class="exo-login-wrapper">
                    <#-- App-initiated actions should not see warning messages about the need to complete the action during login. -->
                    <#if displayMessage && message?has_content && (message.type != 'warning' || !isAppInitiatedAction??)>
                        <div class="exo-alert exo-alert-${message.type}" role="${(message.type = 'error')?then('alert', 'status')}">
                            ${kcSanitize(message.summary)?no_esc}
                        </div>
                    </#if>

                    <div class="exo-login-card">
                        <div class="exo-top-bar">
                            <#if realm.internationalizationEnabled && locale.supported?size gt 1>
                                <nav class="exo-locale-bar" aria-label="${msg("languages")}">
                                    <#list locale.supported as l>
                                        <#if l?index gt 0><span class="exo-locale-sep" aria-hidden="true">|</span></#if>
                                        <a class="exo-locale-link<#if l.languageTag == locale.currentLanguageTag> exo-locale-active</#if>"
                                           href="${l.url}" lang="${l.languageTag}" hreflang="${l.languageTag}" title="${l.label}"
                                           <#if l.languageTag == locale.currentLanguageTag>aria-current="true"</#if>>${l.languageTag?split('-')[0]?upper_case}</a>
                                    </#list>
                                </nav>
                            <#else>
                                <span></span>
                            </#if>
                            <button type="button" class="exo-theme-toggle" data-exo-theme-toggle
                                    data-label-dark="${msg("themeSwitchDark")}" data-label-light="${msg("themeSwitchLight")}"
                                    aria-label="${msg("themeSwitchDark")}" title="${msg("themeSwitchDark")}"></button>
                        </div>

                        <#if displayRequiredFields>
                            <p class="exo-required-note"><span class="exo-required-star" aria-hidden="true">*</span> ${msg("requiredFields")}</p>
                        </#if>

                        <h1 id="kc-page-title" class="exo-page-title"><#nested "header"></h1>

                        <#if auth?has_content && auth.showUsername() && !auth.showResetCredentials()>
                            <#nested "show-username">
                            <div id="kc-username" class="exo-username">
                                <span id="kc-attempted-username">${auth.attemptedUsername}</span>
                                <a id="reset-login" href="${url.loginRestartFlowUrl}" aria-label="${msg("restartLoginTooltip")}" title="${msg("restartLoginTooltip")}">
                                    <i class="${properties.kcResetFlowIcon!}" aria-hidden="true"></i>
                                </a>
                            </div>
                        </#if>

                        <#nested "form">

                        <#if auth?has_content && auth.showTryAnotherWayLink()>
                            <form id="kc-select-try-another-way-form" action="${url.loginAction}" method="post" class="exo-secondary-action">
                                <input type="hidden" name="tryAnotherWay" value="on"/>
                                <a href="#" id="try-another-way"
                                   onclick="document.forms['kc-select-try-another-way-form'].requestSubmit();return false;">${msg("doTryAnotherWay")}</a>
                            </form>
                        </#if>

                        <#if switchOrganizationEnabled?? && switchOrganizationEnabled>
                            <form id="kc-switch-organization-form" action="${url.loginAction}" method="post" class="exo-secondary-action">
                                <input type="hidden" name="switchOrganization" value="true"/>
                                <a href="#" id="switch-organization"
                                   onclick="document.forms['kc-switch-organization-form'].requestSubmit();return false;">${msg("doSwitchOrganization")}</a>
                            </form>
                        </#if>

                        <#nested "socialProviders">
                    </div>

                    <#if displayInfo>
                        <div id="kc-info" class="exo-login-links">
                            <div id="kc-info-wrapper">
                                <#nested "info">
                            </div>
                        </div>
                    </#if>
                </div>
                <div class="exo-page-footer">
                    <p>&copy; ${.now?string('yyyy')} ${msg("brandName")}</p>
                    <@loginFooter.content/>
                </div>
            </div>
        </main>
    </div>
</body>
</html>
</#macro>
