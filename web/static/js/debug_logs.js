(function () {
  var form = document.getElementById('logform'), box = document.getElementById('refresh');
  form.querySelectorAll('select').forEach(function (s) { s.addEventListener('change', function () { form.submit(); }); });
  box.addEventListener('change', function () { form.submit(); });
  if (box.checked) setTimeout(function () { form.submit(); }, 5000);
  var pre = document.querySelector('pre.debug-dump');
  if (pre) pre.scrollTop = pre.scrollHeight;
})();
