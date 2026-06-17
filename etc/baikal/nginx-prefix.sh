#!/bin/sh

# Strip /baikal prefix added by reverse proxy, before nginx routing
sed -i '/^\s*listen\s.*80;/a \    rewrite ^/baikal(/.*) \$1 last;' /etc/nginx/conf.d/default.conf

# Fix well-known redirects to include /baikal prefix so clients follow correct URL through proxy
sed -i 's|/dav.php redirect;|/baikal/dav.php redirect;|' /etc/nginx/conf.d/default.conf

# Block access to sensitive admin settings pages (insert before closing server brace)
sed -i '/^}$/i \  location ~ /admin/\\?/settings/ {\n    deny all;\n    return 404;\n  }\n' /etc/nginx/conf.d/default.conf
