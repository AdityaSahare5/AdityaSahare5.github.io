// Shows which build is live. Uses textContent (never innerHTML) to avoid XSS.
(function () {
  "use strict";

  function set(id, value) {
    document.getElementById(id).textContent = value;
  }

  fetch("build.json", { cache: "no-store" })
    .then(function (res) {
      if (!res.ok) throw new Error("HTTP " + res.status);
      return res.json();
    })
    .then(function (info) {
      set("commit", info.commit);
      set("run", "#" + info.run);
      set("built", new Date(info.builtAt).toLocaleString());
    })
    .catch(function () {
      set("commit", "unknown");
      set("run", "unknown");
      set("built", "build.json not found");
    });
})();
