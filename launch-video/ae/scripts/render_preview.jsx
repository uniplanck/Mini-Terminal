/*
 * Headless preview build + render (AE must be open):
 *   osascript -e 'tell application "Adobe After Effects 2026" to DoScriptFile "<abs>/ae/scripts/render_preview.jsx"'
 *
 * 1. Builds the project with build_launch_film.jsx (MT_HEADLESS, no alerts)
 * 2. Checks every comp: missing footage, expression errors, text layers whose font AE did not apply
 * 3. Saves ae/project/LaunchFilm_preview.aep
 * 4. Renders MAIN (H.264, with audio) → preview/launch_film_preview.mp4 and README_LOOP_6s → preview/readme_loop_6s.mp4
 *
 * The report goes to AE's settings (section "MiniTerminalVerify"), as in verify_s02.jsx: the script
 * never writes files itself, so it works with "Allow Scripts to Write Files and Access Network" OFF.
 */
(function () {
    function report(lines) {
        var n = 0;
        for (var i = 0; i < lines.length; i++) {
            var parts = String(lines[i]).split("\n");
            for (var j = 0; j < parts.length; j++) app.settings.saveSetting("MiniTerminalVerify", "line_" + ("00" + n++).slice(-3), parts[j]);
        }
        app.settings.saveSetting("MiniTerminalVerify", "count", String(n));
        app.preferences.saveToDisk();
    }
    app.settings.saveSetting("MiniTerminalVerify", "count", "0");
    var out = [];
    function say(s) { out.push(s); }
    try {
        var ROOT = File($.fileName).parent.parent.parent; // launch-video/
        $.global.MT_HEADLESS = true;
        try {
            $.evalFile(File(ROOT.fsName + "/ae/scripts/build_launch_film.jsx"));
        } catch (e) {
            say("BUILD_ERROR " + e.toString() + " (line " + e.line + ")");
            report(out);
            return;
        }
        say("BUILD_OK items=" + app.project.numItems);

        var comps = [], missing = [], exprErr = [], fontMiss = [], nExpr = 0, nText = 0;
        for (var i = 1; i <= app.project.numItems; i++) {
            var it = app.project.item(i);
            if (it instanceof CompItem) comps.push(it);
            else if (it instanceof FootageItem && it.footageMissing) missing.push(it.name);
        }
        function scan(group, where) {
            for (var q = 1; q <= group.numProperties; q++) {
                var pr = group.property(q);
                if (pr.propertyType === PropertyType.PROPERTY) {
                    if (pr.canSetExpression && pr.expression !== "") { nExpr++; if (pr.expressionError) exprErr.push(where + ": " + pr.expressionError); }
                } else scan(pr, where);
            }
        }
        var compLine = [];
        for (var c = 0; c < comps.length; c++) {
            var cp = comps[c];
            if (/^(S0\d_|MAIN_|PC_)/.test(cp.name)) compLine.push(cp.name + "(" + cp.numLayers + ")");
            for (var l = 1; l <= cp.numLayers; l++) {
                var ly = cp.layer(l);
                scan(ly, cp.name + "/" + ly.name);
                if (ly instanceof TextLayer) {
                    nText++;
                    var doc = ly.property("ADBE Text Properties").property("ADBE Text Document").value;
                    var fo = null;
                    try { fo = doc.fontObject; } catch (eF) {}
                    if (fo && fo.isSubstitute) fontMiss.push(cp.name + "/" + ly.name + " → substitute for " + doc.font);
                }
            }
        }
        say("comps: " + compLine.join(", "));
        say("missing footage: " + (missing.length ? missing.join(", ") : "none"));
        say("expressions=" + nExpr + " errors: " + (exprErr.length ? exprErr.join(" | ") : "none"));
        say("text layers=" + nText + " font substitutions: " + (fontMiss.length ? fontMiss.join(" | ") : "none"));

        try {
            app.project.save(File(ROOT.fsName + "/ae/project/LaunchFilm_preview.aep"));
            say("SAVED ae/project/LaunchFilm_preview.aep");
        } catch (e3) { say("SAVE_FAILED " + e3.toString()); }

        function find(name) {
            for (var i2 = 1; i2 <= app.project.numItems; i2++) if (app.project.item(i2).name === name) return app.project.item(i2);
            return null;
        }
        var rq = app.project.renderQueue;
        while (rq.numItems > 0) rq.item(1).remove();
        var jobs = [["MAIN_LaunchFilm_1920x1080_60", "launch_film_preview"], ["README_LOOP_6s", "readme_loop_6s"]];
        for (var j = 0; j < jobs.length; j++) {
            var comp = find(jobs[j][0]);
            var item = rq.items.add(comp);
            var om = item.outputModule(1);
            var tpl = null;
            for (var n = 0; n < om.templates.length; n++) if (/H\.264/.test(om.templates[n]) && /40 Mbps/.test(om.templates[n])) { tpl = om.templates[n]; break; }
            if (tpl) om.applyTemplate(tpl);
            om.file = File(ROOT.fsName + "/preview/" + jobs[j][1]);
            say("queue " + jobs[j][0] + " template=" + tpl);
        }
        rq.render();
        for (var r = 1; r <= rq.numItems; r++) say("RENDER " + rq.item(r).comp.name + " status=" + rq.item(r).status + " (DONE=" + RQItemStatus.DONE + ")");
    } catch (err) {
        say("ERROR " + err.toString() + " (line " + err.line + ")");
    }
    report(out);
})();
