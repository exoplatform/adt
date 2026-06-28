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
<#macro registrationLayout displayInfo=false displayMessage=true displayRequiredFields=false>
<!DOCTYPE html>
<html lang="${(locale.currentLanguageTag)!'en'}">
<head>
    <meta charset="utf-8">
    <meta name="robots" content="noindex, nofollow">
    <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1">
    <title>${msg("loginTitle",(realm.displayName!''))}</title>
    <link rel="icon" href="${url.resourcesPath}/img/favicon.ico" />
    <link href="${url.resourcesCommonPath}/vendor/patternfly-v4/patternfly.min.css" rel="stylesheet" />
    <link href="${url.resourcesCommonPath}/vendor/patternfly-v3/css/patternfly.min.css" rel="stylesheet" />
    <link href="${url.resourcesCommonPath}/vendor/patternfly-v3/css/patternfly-additions.min.css" rel="stylesheet" />
    <link href="${url.resourcesCommonPath}/lib/pficon/pficon.css" rel="stylesheet" />
    <link href="${url.resourcesPath}/css/custom.css" rel="stylesheet" />
    <script type="importmap">
        {
            "imports": {
                "rfc4648": "${url.resourcesCommonPath}/node_modules/rfc4648/lib/rfc4648.js"
            }
        }
    </script>
    <#if properties.scripts?has_content>
        <#list properties.scripts?split(' ') as script>
            <script src="${url.resourcesPath}/${script}" type="text/javascript"></script>
        </#list>
    </#if>
</head>

<body>
    <div class="exo-split-layout">
        <div class="exo-split-left">
            <div class="exo-split-left-inner">
                <div class="exo-brand">
                    <div class="exo-brand-logo">eXo</div>
                    <h1 class="exo-brand-name">eXo Platform</h1>
                    <p class="exo-brand-desc">Open Source Digital Workplace</p>
                </div>
                <div class="exo-brand-footer">
                    <p>Secure enterprise collaboration</p>
                </div>
            </div>
        </div>
        <div class="exo-split-right">
            <div class="exo-split-right-inner">
                <div class="exo-login-wrapper">
                    <#if displayMessage && message?has_content && (message.type != 'warning' || !isAppInitiatedAction??)>
                        <div class="exo-alert exo-alert-${message.type}">
                            ${kcSanitize(message.summary)?no_esc}
                        </div>
                    </#if>

                    <#if !(auth?has_content && auth.showUsername() && !auth.showResetCredentials())>
                        <div class="exo-login-card">
                            <div class="exo-top-bar">
                                <div class="exo-locale-bar">
                                    <a class="exo-locale-link" data-locale="en" onclick="switchLocale('en')" href="#">EN</a>
                                    <span class="exo-locale-sep">|</span>
                                    <a class="exo-locale-link" data-locale="fr" onclick="switchLocale('fr')" href="#">FR</a>
                                </div>
                                <button class="exo-theme-toggle" onclick="toggleTheme()" aria-label="Toggle dark mode" title="Toggle dark mode">&#9788;</button>
                            </div>
                            <#nested "header">
                            <#nested "form">
                        </div>
                    <#else>
                        <#nested "header">
                        <#nested "form">
                    </#if>

                    <#if displayInfo>
                        <div class="exo-login-links">
                            <#nested "info">
                        </div>
                    </#if>
                </div>
                <div class="exo-page-footer">
                    <p>&copy; ${.now?string('yyyy')} eXo Platform</p>
                </div>
            </div>
    </div>
</div>
<script>
function switchLocale(locale) {
    var u = new URL(window.location.href);
    u.searchParams.set('kc_locale', locale);
    window.location.href = u.toString();
}
(function(){
    var cur = new URL(window.location.href).searchParams.get('kc_locale') || 'en';
    var active = document.querySelector('.exo-locale-link[data-locale="' + cur + '"]');
    if (active) {
        document.querySelectorAll('.exo-locale-link').forEach(function(l){ l.classList.remove('exo-locale-active'); });
        active.classList.add('exo-locale-active');
    }
})();
(function(){
    var html = document.documentElement;
    var stored = null;
    try { stored = localStorage.getItem('exo-theme'); } catch(e){}
    if (stored === 'dark' || stored === 'light') {
        html.setAttribute('data-theme', stored);
    }
    function toggleTheme() {
        var current = html.getAttribute('data-theme');
        var next = (current === 'dark') ? 'light' : 'dark';
        html.setAttribute('data-theme', next);
        try { localStorage.setItem('exo-theme', next); } catch(e){}
        updateToggleIcon(next);
    }
    function updateToggleIcon(theme) {
        var btn = document.querySelector('.exo-theme-toggle');
        if (btn) btn.innerHTML = theme === 'dark' ? '&#9789;' : '&#9788;';
    }
    updateToggleIcon(html.getAttribute('data-theme') || 'light');
    window.toggleTheme = toggleTheme;
})();
</script>
</body>
</html>
</#macro>
