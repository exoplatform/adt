// Bootstrap sets aria-hidden on a modal that is closing while the button that closed it still has the focus, which
// browsers report ("Blocked aria-hidden on an element because its descendant retained focus"). Let go of the focus
// first: Bootstrap gives it back to the button that opened the modal once the modal is hidden.
document.addEventListener('hide.bs.modal', function(e) {
  var active = document.activeElement;
  if (active && active !== document.body && e.target.contains(active)) active.blur();
});

// Buttons that copy an address nobody can open (JMX URL, LDAP URL, SSH command): the tooltip confirms the copy
document.addEventListener('click', function(e) {
  var btn = e.target.closest && e.target.closest('[data-copy-text]');
  if (!btn) return;
  var title = btn.getAttribute('data-bs-original-title') || btn.getAttribute('title') || '';
  copyText(btn.getAttribute('data-copy-text'), function(ok) {
    var tip = typeof bootstrap !== 'undefined' && bootstrap.Tooltip.getInstance(btn);
    if (!tip) return;
    tip.setContent({ '.tooltip-inner': ok ? 'Copied!' : 'Copy failed' });
    tip.show();
    clearTimeout(btn._copyTimer);
    btn._copyTimer = setTimeout(function() {
      tip.setContent({ '.tooltip-inner': title });
      // Without hover or focus (touch, programmatic) nothing else would close it
      if (!btn.matches(':hover, :focus-visible')) tip.hide();
    }, 1500);
  });
});

// Tooltips and popovers of root (the page, or a part that was swapped in place, see autorefresh.js). Bootstrap comes
// from a CDN: without it the page still works, only the tooltips and popovers are missing.
window.adtInitOverlays = function(root) {
  if (typeof bootstrap === 'undefined' || !root) return;
  // Icon-only tooltip triggers get their tooltip text as aria-label (set by
  // Bootstrap), which is only allowed on an element with a role
  root.querySelectorAll('span[rel=tooltip]:not([role]), i[rel=tooltip]:not([role])').forEach(function(el) {
    if (!el.textContent.trim()) el.setAttribute('role', 'img');
  });
  root.querySelectorAll('[rel=tooltip]').forEach(function(el) {
    if (!bootstrap.Tooltip.getInstance(el)) new bootstrap.Tooltip(el);
  });
  // Popovers with HTML support
  root.querySelectorAll('[rel=popover]').forEach(function(el) {
    if (bootstrap.Popover.getInstance(el)) return;
    new bootstrap.Popover(el, { trigger: 'hover', html: true, sanitize: false, container: 'body', animation: true, delay: { show: 100, hide: 100 } });
  });
};
// Before a part is replaced: its tooltips would stay on screen, attached to nodes that are gone
window.adtDisposeOverlays = function(root) {
  if (typeof bootstrap === 'undefined' || !root) return;
  root.querySelectorAll('[rel=tooltip], [rel=popover], [data-bs-original-title]').forEach(function(el) {
    var t = bootstrap.Tooltip.getInstance(el) || bootstrap.Popover.getInstance(el);
    if (t) t.dispose();
  });
};

document.addEventListener('DOMContentLoaded', function() {
  if (typeof bootstrap === 'undefined') return;
  window.adtInitOverlays(document);

  // On touch devices a tap leaves the tooltip stuck (hover/focus never
  // ends), notably when the tap opens a modal: hide tooltips on tap and
  // whenever a modal opens
  function hideAllTooltips() {
    document.querySelectorAll('[rel=tooltip]').forEach(function(el) {
      var tip = bootstrap.Tooltip.getInstance(el);
      if (tip) tip.hide();
    });
  }
  document.addEventListener('show.bs.modal', hideAllTooltips);
  if (window.matchMedia && window.matchMedia('(hover: none)').matches) {
    document.addEventListener('click', function(e) {
      var trigger = e.target.closest && e.target.closest('[rel=tooltip]');
      if (!trigger) { hideAllTooltips(); return; }
      // Let the action run (modal, link), then drop the tooltip
      setTimeout(function() {
        var tip = bootstrap.Tooltip.getInstance(trigger);
        if (tip) tip.hide();
      }, 0);
    });
  }
});

// Scroll-to-top button
(function() {
  var scrollTopBtn = document.getElementById('scrollTopBtn');
  if (!scrollTopBtn) return;
  function toggleScrollTopBtn() {
    scrollTopBtn.classList.toggle('visible', window.scrollY > 300);
  }
  window.addEventListener('scroll', toggleScrollTopBtn, { passive: true });
  toggleScrollTopBtn();
  scrollTopBtn.addEventListener('click', function() {
    window.scrollTo({ top: 0, behavior: 'smooth' });
  });
})();

// Service Worker registration with update handling
if ('serviceWorker' in navigator) {
  var updateToast = null;

  function showUpdateToast() {
    if (updateToast) return;
    var toast = document.createElement('div');
    toast.id = 'pwa-update-toast';
    toast.innerHTML = '<i class="fas fa-sync-alt"></i> New version available \u2014 click to refresh';
    toast.onclick = function() { window.doUpdate(); };
    document.body.appendChild(toast);
    updateToast = toast;
  }

  window.doUpdate = function() {
    if (window.waitingWorker) {
      window.waitingWorker.postMessage({ action: 'skipWaiting' });
    }
  };

  navigator.serviceWorker.register('/sw.js').then(function(reg) {
    // Installed PWAs can stay open for days: look for a new SW whenever
    // the app is brought back to the foreground
    document.addEventListener('visibilitychange', function() {
      if (document.visibilityState === 'visible') reg.update().catch(function() {});
    });
    if (reg.waiting) {
      window.waitingWorker = reg.waiting;
      showUpdateToast();
    }
    reg.addEventListener('updatefound', function() {
      var newWorker = reg.installing;
      if (!newWorker) return;
      newWorker.addEventListener('statechange', function() {
        if (newWorker.state === 'installed' && navigator.serviceWorker.controller) {
          window.waitingWorker = newWorker;
          showUpdateToast();
        }
      });
    });
  }).catch(function() { /* no service worker (private window, blocked): the site works without it */ });

  var refreshing = false;
  navigator.serviceWorker.addEventListener('controllerchange', function() {
    if (refreshing) return;
    refreshing = true;
    window.location.reload();
  });
}

// PWA Install prompt. The button is shown from the first paint when the browser offered the install on an
// earlier page (remembered in "pwaInstallable", see the head script), so it does not make the sidebar jump.
var deferredPrompt;
var pwaRoot = document.documentElement;
function pwaHide() {
  pwaRoot.classList.remove('pwa-installable');
  setPref('pwaInstallable', '0');
}
window.addEventListener('beforeinstallprompt', function(e) {
  e.preventDefault();
  deferredPrompt = e;
  pwaRoot.classList.add('pwa-installable');
  setPref('pwaInstallable', '1');
});
window.addEventListener('appinstalled', pwaHide);
function pwaInstall() {
  if (!deferredPrompt) return;
  deferredPrompt.prompt();
  deferredPrompt.userChoice.then(function(result) {
    if (result.outcome === 'accepted') pwaHide();
    deferredPrompt = null;
  });
}
// Already running installed (standalone): never show the install button.
if (window.matchMedia && window.matchMedia('(display-mode: standalone)').matches) {
  pwaHide();
} else {
  // The offer did not come back (installed meanwhile, or the browser no longer offers it): forget it
  setTimeout(function() { if (!deferredPrompt) pwaHide(); }, 5000);
}

window.ADT_ACTIONS.pwaInstall = pwaInstall;
