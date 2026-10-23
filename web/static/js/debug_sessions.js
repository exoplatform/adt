(function () {
  var box = document.getElementById('autorefresh'), timer = null;
  function get() { try { return localStorage.getItem('sessionsRefresh') === '1'; } catch (e) { return false; } }
  function set(v) { try { localStorage.setItem('sessionsRefresh', v ? '1' : '0'); } catch (e) {} }
  function apply() {
    clearTimeout(timer);
    // Reload as a plain GET so a pending POST result is never resubmitted
    if (box.checked) timer = setTimeout(function () { location.href = location.pathname; }, 10000);
  }
  box.checked = get();
  box.addEventListener('change', function () { set(box.checked); apply(); });
  apply();
})();
