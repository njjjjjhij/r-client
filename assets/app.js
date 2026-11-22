(function () {
  var btn = document.getElementById("copyBtn");
  var code = document.getElementById("loadstring");
  if (!btn || !code) return;
  btn.addEventListener("click", function () {
    var text = code.textContent.trim();
    function done() {
      btn.textContent = "Copied";
      setTimeout(function () { btn.textContent = "Copy"; }, 1600);
    }
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(done, done);
      return;
    }
    var area = document.createElement("textarea");
    area.value = text;
    document.body.appendChild(area);
    area.select();
    try { document.execCommand("copy"); } catch (e) {}
    document.body.removeChild(area);
    done();
  });
})();
