/*
 * S02 press-rig verification (headless). Builds the whole film with build_launch_film.jsx,
 * then reports the rig's structure and evaluated values, saves the project and renders
 * S02_KEYS as a PNG sequence into preview/verify_s02/ (git-ignored).
 *
 * Run from a shell (AE must be open):
 *   osascript -e 'tell application "Adobe After Effects 2026" to DoScriptFile "<abs path>/verify_s02.jsx"'
 * DoScriptFile returns nothing, and the script does not write files itself (so it works with
 * "Allow Scripts to Write Files and Access Network" OFF). The report goes to AE's own settings
 * (section "MiniTerminalVerify", keys line_000…, "count"), flushed with app.preferences.saveToDisk();
 * read it from ~/Library/Preferences/Adobe/After Effects/<ver>/*環境設定.txt / *Prefs.txt.
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
    var report_lines;
    try { report_lines = (function () {
    var ROOT = File($.fileName).parent.parent.parent; // launch-video/
    var out = [];
    function say(s) { out.push(s); }
    function find(name) {
        for (var i = 1; i <= app.project.numItems; i++) if (app.project.item(i).name === name) return app.project.item(i);
        return null;
    }
    function r2(v) { return Math.round(v * 100) / 100; }
    function fmt(v) {
        if (v instanceof Array) { var a = []; for (var i = 0; i < v.length; i++) a.push(r2(v[i])); return "[" + a.join(",") + "]"; }
        return String(r2(v));
    }
    function xf(l, m) { return l.property("ADBE Transform Group").property(m); }

    $.global.MT_HEADLESS = true;
    // The build calls app.newProject(); drop the previous (unsaved) verification project first so AE does not prompt.
    if (app.project) app.project.close(CloseOptions.DO_NOT_SAVE_CHANGES);
    try {
        $.evalFile(File(ROOT.fsName + "/ae/scripts/build_launch_film.jsx"));
    } catch (e) {
        return ["BUILD_ERROR " + e.toString() + " (line " + e.line + ")"];
    }
    say("BUILD_OK items=" + app.project.numItems);

    var rig = find("PC_H2R_RIG");
    var shot = find("S02_KEYS");
    if (!rig || !shot) { say("MISSING rig/shot comp"); return out; }
    var fps = rig.frameRate;

    say("RIG layers (top→bottom):");
    for (var i = 1; i <= rig.numLayers; i++) {
        var l = rig.layer(i);
        var masks = l.property("ADBE Mask Parade") ? l.property("ADBE Mask Parade").numProperties : 0;
        var tm = "";
        try { if (l.hasTrackMatte) tm = " matte=" + (l.trackMatteLayer ? l.trackMatteLayer.name : "(adjacent)") + " type=" + l.trackMatteType; } catch (e1) {}
        var src = "";
        try { if (l.source && l.source.mainSource && l.source.mainSource.file) src = " src=" + l.source.name + " " + l.source.width + "x" + l.source.height; } catch (e2) {}
        say("  " + i + " " + l.name + " enabled=" + l.enabled + " masks=" + masks + tm + src);
    }

    var ctrl = rig.layer("CTRL_Press");
    var press = ctrl.property("ADBE Effect Parade").property("press").property("ADBE Slider Control-0001");
    var travel = ctrl.property("ADBE Effect Parade").property("travel px").property("ADBE Slider Control-0001").value;
    say("travel px=" + travel);
    var frames = [0, 52, 53, 54, 55, 56, 57, 58, 70, 89];
    var capO = rig.layer("CAP_option"), capS = rig.layer("CAP_space"), plate = rig.layer("PLATE");
    var errs = [];
    // Every expression on every rig layer (transform + effects), not only the ones we expect.
    var nExpr = 0;
    function scan(group, layerName) {
        for (var q = 1; q <= group.numProperties; q++) {
            var pr = group.property(q);
            if (pr.propertyType === PropertyType.PROPERTY) {
                if (pr.canSetExpression && pr.expression !== "") { nExpr++; if (pr.expressionError) errs.push(layerName + "." + pr.name + ": " + pr.expressionError); }
            } else scan(pr, layerName);
        }
    }
    for (var li = 1; li <= rig.numLayers; li++) {
        scan(rig.layer(li).property("ADBE Transform Group"), rig.layer(li).name);
        if (rig.layer(li).property("ADBE Effect Parade")) scan(rig.layer(li).property("ADBE Effect Parade"), rig.layer(li).name);
    }
    say("expressions=" + nExpr + " errors: " + (errs.length ? errs.join(" | ") : "none"));
    var fillO = rig.layer("FILL_well_option");
    say("FILL_well_option opacity f0=" + fmt(xf(fillO, "ADBE Opacity").valueAtTime(0, false)) + " f54=" + fmt(xf(fillO, "ADBE Opacity").valueAtTime(54 / fps, false)) + " f57=" + fmt(xf(fillO, "ADBE Opacity").valueAtTime(57 / fps, false)));
    say("frame | press | CAP_option pos | CAP_space pos | PLATE pos (static ref) | shade opacity");
    for (var f = 0; f < frames.length; f++) {
        var t = frames[f] / fps;
        say("  f" + frames[f] + " | " + fmt(press.valueAtTime(t, false)) + " | " + fmt(xf(capO, "ADBE Position").valueAtTime(t, false)) +
            " | " + fmt(xf(capS, "ADBE Position").valueAtTime(t, false)) + " | " + fmt(xf(plate, "ADBE Position").valueAtTime(t, false)) +
            " | " + fmt(xf(rig.layer("SHADE_command_sides"), "ADBE Opacity").valueAtTime(t, false)));
    }

    var adj = shot.layer("ADJ_ImpactPulse");
    var ev = adj.property("ADBE Effect Parade").property(1);
    var evp = null;
    for (var k = 1; k <= ev.numProperties; k++) if (ev.property(k).numKeys > 0) evp = ev.property(k);
    var pulse = [];
    for (var g = 55; g <= 61; g++) pulse.push("f" + g + "=" + fmt(evp.valueAtTime(g / fps, false)));
    say("ImpactPulse (" + evp.name + "): " + pulse.join(" "));
    var base = shot.layer("BASE");
    say("BASE scale f0=" + fmt(xf(base, "ADBE Scale").valueAtTime(0, false)) + " f89=" + fmt(xf(base, "ADBE Scale").valueAtTime(89 / fps, false)));

    // Save + render (AE writes these, not the script).
    try {
        app.project.save(File(ROOT.fsName + "/ae/project/verify_S02.aep"));
        say("SAVED ae/project/verify_S02.aep");
    } catch (e3) { say("SAVE_FAILED " + e3.toString()); }

    var rq = app.project.renderQueue;
    while (rq.numItems > 0) rq.item(1).remove();
    var item = rq.items.add(shot);
    var om = item.outputModule(1);
    var tpl = null;
    // Lossless stills for pixel diffs: PNG if the install has it, else the TIFF sequence.
    var prefer = [/PNG/i, /TIFF/i];
    for (var pi = 0; pi < prefer.length && !tpl; pi++)
        for (var n = 0; n < om.templates.length; n++) if (prefer[pi].test(om.templates[n])) { tpl = om.templates[n]; break; }
    if (tpl) om.applyTemplate(tpl);
    var dir = Folder(ROOT.fsName + "/preview/verify_s02");
    try { if (!dir.exists) dir.create(); } catch (e5) {}
    om.file = File(dir.fsName + "/S02_[####]");
    say("RENDER template=" + tpl + (tpl ? "" : " (available: " + om.templates.join(" / ") + ")"));
    try {
        rq.render();
        say("RENDER_DONE status=" + item.status);
    } catch (e4) { say("RENDER_FAILED " + e4.toString()); }
    return out;
})(); } catch (err) { report_lines = ["VERIFY_ERROR " + err.toString() + " (line " + err.line + ")"]; }
    report(report_lines instanceof Array ? report_lines : [String(report_lines)]);
})();
