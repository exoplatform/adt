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
                            <div class="exo-locale-bar">
                                <a class="exo-locale-link exo-locale-active" onclick="switchLocale('en')" href="#">EN</a>
                                <span class="exo-locale-sep">|</span>
                                <a class="exo-locale-link" onclick="switchLocale('fr')" href="#">FR</a>
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
</script>
</body>
</html>
</#macro>
