(function () {
  var modal = document.getElementById('remoteDebugModal');
  if (!modal) return;
  // Fill the commands with the host of the instance whose badge was clicked
  modal.addEventListener('show.bs.modal', function (ev) {
    var host = (ev.relatedTarget && ev.relatedTarget.getAttribute('data-host')) || '';
    modal.querySelectorAll('.rd-host').forEach(function (el) { el.textContent = host || '<instance-host>'; });
    modal.querySelector('.rd-host-title').textContent = host;
    // Open the tab matching the visitor's system
    var win = /Win/i.test(navigator.platform || navigator.userAgent || '');
    var tab = document.getElementById(win ? 'rdTabWin' : 'rdTabUnix');
    if (tab && window.bootstrap) bootstrap.Tab.getOrCreateInstance(tab).show();
  });
  modal.querySelectorAll('[data-copy]').forEach(function (btn) {
    btn.addEventListener('click', function () {
      var text = document.getElementById(btn.getAttribute('data-copy')).textContent;
      var done = function (ok) {
        btn.innerHTML = ok ? '<i class="fas fa-check me-1"></i>Copied' : '<i class="fas fa-xmark me-1"></i>Copy failed';
        setTimeout(function () { btn.innerHTML = '<i class="fas fa-copy me-1"></i>Copy'; }, 1800);
      };
      copyText(text, done);
    });
  });
})();
