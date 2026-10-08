/*
 * Mini-Terminal Launch Film — After Effects project builder.
 *
 * Run: After Effects > File > Scripts > Run Script File… > this file.
 * Reads ../../planning/timeline.json and ../../assets/manifest.json, then builds
 * bins, shot pre-comps, the main/loop comps, beat + narration markers, a grid guide,
 * Japanese copy layers and placeholders for every asset that does not exist yet.
 * Idempotent per run: it always builds into a NEW project (never touches an open one).
 *
 * ExtendScript is ES3: no let/const, arrow functions or native JSON.
 */
(function () {
    var SCRIPT_DIR = File($.fileName).parent;
    var ROOT = SCRIPT_DIR.parent.parent; // launch-video/

    function readJSON(relPath) {
        var f = File(ROOT.fsName + "/" + relPath);
        if (!f.exists) throw new Error("Missing " + f.fsName);
        f.encoding = "UTF-8";
        f.open("r");
        var text = f.read();
        f.close();
        // Trusted local file written by this repo.
        return eval("(" + text + ")");
    }

    function hexToRGB(hex) {
        var h = hex.replace("#", "");
        return [parseInt(h.substr(0, 2), 16) / 255, parseInt(h.substr(2, 2), 16) / 255, parseInt(h.substr(4, 2), 16) / 255];
    }

    function folder(name, parent) {
        var f = app.project.items.addFolder(name);
        if (parent) f.parentFolder = parent;
        return f;
    }

    function addComp(name, dur, parent) {
        var c = app.project.items.addComp(name, T.width, T.height, 1, dur, T.fps);
        c.bgColor = hexToRGB(T.colors.bg);
        if (parent) c.parentFolder = parent;
        return c;
    }

    function addMarker(layerOrComp, time, label) {
        var mv = new MarkerValue(label);
        if (layerOrComp instanceof CompItem) layerOrComp.markerProperty.setValueAtTime(time, mv);
        else layerOrComp.property("Marker").setValueAtTime(time, mv);
    }

    function addText(comp, name, text, font, size, color, pos) {
        var layer = comp.layers.addText(text);
        layer.name = name;
        var prop = layer.property("Source Text");
        var doc = prop.value;
        doc.resetCharStyle();
        doc.font = font;
        doc.fontSize = size;
        doc.fillColor = hexToRGB(color);
        doc.applyFill = true;
        doc.justification = ParagraphJustification.LEFT_JUSTIFY;
        doc.tracking = size >= 72 ? -20 : 0;
        prop.setValue(doc);
        layer.property("Position").setValue(pos);
        return layer;
    }

    // expo-out reveal: slide up 24px + fade, starting at `t` (comp time).
    function revealIn(layer, t) {
        var p = layer.property("Position");
        var o = layer.property("Opacity");
        var end = p.value;
        p.setValueAtTime(t, [end[0], end[1] + 24]);
        p.setValueAtTime(t + 0.45, end);
        o.setValueAtTime(t, 0);
        o.setValueAtTime(t + 0.3, 100);
        var ease = new KeyframeEase(0, 90);
        var easeIn = new KeyframeEase(0, 10);
        p.setTemporalEaseAtKey(1, [easeIn], [ease]);
        p.setTemporalEaseAtKey(2, [ease], [easeIn]);
    }

    function gridGuide(comp) {
        var g = T.grid;
        var layer = comp.layers.addShape();
        layer.name = "GUIDE_Grid12";
        layer.guideLayer = true;
        var contents = layer.property("Contents");
        var colW = (T.width - g.margin * 2 - g.gutter * (g.columns - 1)) / g.columns;
        for (var i = 0; i < g.columns; i++) {
            var grp = contents.addProperty("ADBE Vector Group");
            grp.name = "col" + (i + 1);
            var rect = grp.property("Contents").addProperty("ADBE Vector Shape - Rect");
            rect.property("Size").setValue([colW, T.height - g.margin * 2]);
            var x = g.margin + i * (colW + g.gutter) + colW / 2;
            rect.property("Position").setValue([x - T.width / 2, 0]);
            var fill = grp.property("Contents").addProperty("ADBE Vector Graphic - Fill");
            fill.property("Color").setValue([1, 0.2, 0.4]);
            fill.property("Opacity").setValue(8);
        }
        layer.property("Position").setValue([T.width / 2, T.height / 2]);
        return layer;
    }

    function placeholder(comp, label, dur) {
        var solid = comp.layers.addSolid([0.12, 0.12, 0.13], "PLACEHOLDER " + label, T.width, T.height, 1, dur);
        var t = addText(comp, "PH_LABEL", "[ " + label + " ]", T.fonts.mono, 28, T.colors.muted, [T.grid.margin, T.height - T.grid.margin]);
        t.guideLayer = true;
        return solid;
    }

    function findAsset(id) {
        for (var i = 0; i < M.assets.length; i++) if (M.assets[i].id === id) return M.assets[i];
        return null;
    }

    // Final file first; `tempPath` (a stand-in plate) only while the final one is missing.
    function importAsset(id, bin) {
        var a = findAsset(id);
        if (!a) return null;
        var paths = a.tempPath ? [a.path, a.tempPath] : [a.path];
        for (var i = 0; i < paths.length; i++) {
            var f = File(ROOT.fsName + "/" + paths[i]);
            if (!f.exists) continue;
            var item = app.project.importFile(new ImportOptions(f));
            item.parentFolder = bin;
            return item;
        }
        return null;
    }

    // ------------------------------------------------------------------ S02 key-press rig
    // planning/h2-redesign.md §4–5. One CTRL_Press slider drives option AND space, so the two keys
    // can only sink on the same frames; command (between them) never moves. Key outlines come from
    // timeline.json S02.press.masks[<plate file name>] in source-image px, so each plate carries its
    // own traced set. Property access uses matchNames so the script also runs on a non-English AE.

    function xform(layer, matchName) {
        return layer.property("ADBE Transform Group").property(matchName);
    }

    function addSlider(layer, name, value) {
        var fx = layer.property("ADBE Effect Parade").addProperty("ADBE Slider Control");
        fx.name = name;
        fx.property("ADBE Slider Control-0001").setValue(value);
        return fx.property("ADBE Slider Control-0001");
    }

    // Exposure's master value. matchName first; scan by name as a fallback.
    function addExposure(layer) {
        var fx = layer.property("ADBE Effect Parade").addProperty("ADBE Exposure2");
        var byMatch = null;
        try { byMatch = fx.property("ADBE Exposure2-0003"); } catch (e) {}
        if (byMatch) return byMatch;
        for (var i = 2; i <= fx.numProperties; i++) {
            if (/^(Exposure|露光量|露出)$/.test(fx.property(i).name)) return fx.property(i);
        }
        throw new Error("Exposure parameter not found on " + layer.name);
    }

    // quad = [TL, TR, BR, BL] in the layer's own px; r rounds the corners (bezier, 0.552 ≈ circle).
    function addQuadMask(layer, quad, r, feather, expansion) {
        var v = [], tin = [], tout = [];
        for (var i = 0; i < 4; i++) {
            var p = quad[i], a = quad[(i + 3) % 4], b = quad[(i + 1) % 4];
            if (!r) { v.push(p); tin.push([0, 0]); tout.push([0, 0]); continue; }
            var la = Math.sqrt(Math.pow(a[0] - p[0], 2) + Math.pow(a[1] - p[1], 2));
            var lb = Math.sqrt(Math.pow(b[0] - p[0], 2) + Math.pow(b[1] - p[1], 2));
            var v1 = [p[0] + (a[0] - p[0]) * r / la, p[1] + (a[1] - p[1]) * r / la];
            var v2 = [p[0] + (b[0] - p[0]) * r / lb, p[1] + (b[1] - p[1]) * r / lb];
            v.push(v1); tin.push([0, 0]); tout.push([(p[0] - v1[0]) * 0.552, (p[1] - v1[1]) * 0.552]);
            v.push(v2); tin.push([(p[0] - v2[0]) * 0.552, (p[1] - v2[1]) * 0.552]); tout.push([0, 0]);
        }
        var shape = new Shape();
        shape.vertices = v;
        shape.inTangents = tin;
        shape.outTangents = tout;
        shape.closed = true;
        var m = layer.property("ADBE Mask Parade").addProperty("ADBE Mask Atom");
        m.property("ADBE Mask Shape").setValue(shape);
        if (feather) m.property("ADBE Mask Feather").setValue([feather, feather]);
        if (expansion) m.property("ADBE Mask Offset").setValue(expansion);
        return m;
    }

    function setMatte(layer, matte) {
        if (layer.setTrackMatte) layer.setTrackMatte(matte, TrackMatteType.ALPHA); // AE 2023+
        else layer.trackMatteType = TrackMatteType.ALPHA; // legacy: matte must sit directly above
        matte.enabled = false;
    }

    function buildS02Rig(shot, item, bin) {
        var P = shot.press;
        var dur = shot.end - shot.start;
        var rig = addComp("PC_H2R_RIG", dur, bin);
        var srcW = item ? item.width : T.width;
        var srcH = item ? item.height : T.height;
        var s = item ? Math.max(T.width / srcW, T.height / srcH) : 1; // cover-fit
        var M = P.masks[item ? item.name : "_placeholder"];

        // Plate px → comp px (plate layers are centred and uniformly scaled by s).
        function toComp(q) {
            var out = [];
            for (var i = 0; i < q.length; i++) out.push([(q[i][0] - srcW / 2) * s + T.width / 2, (q[i][1] - srcH / 2) * s + T.height / 2]);
            return out;
        }
        function plateLayer(name) {
            var l = item ? rig.layers.add(item) : rig.layers.addSolid([0.12, 0.12, 0.13], name, T.width, T.height, 1, dur);
            l.name = name;
            xform(l, "ADBE Scale").setValue([s * 100, s * 100]);
            return l;
        }
        function solid(name, hex) {
            return rig.layers.addSolid(hexToRGB(hex), name, T.width, T.height, 1, dur);
        }

        // Bottom → top (layers.add inserts at the top).
        plateLayer("PLATE");
        if (!item) addText(rig, "PH_LABEL", "[ PLATE_H2R_keyrow — see planning/h2-redesign.md §3 ]", T.fonts.mono, 28, T.colors.muted, [T.grid.margin, T.height - T.grid.margin]).guideLayer = true;
        if (!M) {
            // A new plate without a traced mask set: show it unanimated rather than with wrong masks.
            addMarker(rig, 0, "NO MASK SET for " + item.name + " — add timeline.json S02.press.masks entry");
            return rig;
        }

        // Controller first so the expressions below never point at a missing layer; moved to the top at the end.
        var ctrl = rig.layers.addNull(dur);
        ctrl.name = "CTRL_Press";
        addSlider(ctrl, "press", 0);
        addSlider(ctrl, "travel px", M.travelPx);
        addSlider(ctrl, "cap exposure", P.capExposureAtBottom);

        var keys = P.keys; // ["option", "space"]
        for (var k = 0; k < keys.length; k++) {
            // 3px wider than the cap so the original key's rim never shows beside the sunk cap; invisible
            // at rest (opacity follows the press) so the untouched plate is shown until the key moves.
            var fill = solid("FILL_well_" + keys[k], M.wellFill || P.wellFill);
            addQuadMask(fill, toComp(M[keys[k]]), M.radius * s, 0, 3);
            xform(fill, "ADBE Opacity").expression = 'Math.min(1, thisComp.layer("CTRL_Press").effect("press")(1) * 4) * 100';
        }
        for (var j = 0; j < keys.length; j++) {
            var q = M[keys[j]];
            var cap = plateLayer("CAP_" + keys[j]);
            addQuadMask(cap, q, M.radius, 0, 1);
            // sinkDir: the key's "down" on screen for this plate's camera (default straight down).
            var dir = M.sinkDir || [0, 1];
            xform(cap, "ADBE Position").expression = 'var c = thisComp.layer("CTRL_Press"); value + [' + dir[0] + ', ' + dir[1] + '] * (c.effect("press")(1) * c.effect("travel px")(1))';
            addExposure(cap).expression = 'var c = thisComp.layer("CTRL_Press"); c.effect("press")(1) * c.effect("cap exposure")(1)';
            // Everything above the lip (BL–BR): the cap's lower edge disappears below it as it sinks.
            var lip = toComp(q);
            var matte = solid("MATTE_well_" + keys[j], "#FFFFFF");
            addQuadMask(matte, [[lip[0][0] - 24, lip[0][1] - 200], [lip[1][0] + 24, lip[1][1] - 200], [lip[2][0] + 24, lip[2][1]], [lip[3][0] - 24, lip[3][1]]], 0, 0);
            setMatte(cap, matte);
        }

        // Both neighbours drop, exposing a sliver of command's side walls: darken them.
        var c = toComp(M.command);
        var shade = solid("SHADE_command_sides", "#000000");
        addQuadMask(shade, [[c[0][0] - 6, c[0][1]], [c[0][0] + 6, c[0][1]], [c[3][0] + 6, c[3][1]], [c[3][0] - 6, c[3][1]]], 0, 4);
        addQuadMask(shade, [[c[1][0] - 6, c[1][1]], [c[1][0] + 6, c[1][1]], [c[2][0] + 6, c[2][1]], [c[2][0] - 6, c[2][1]]], 0, 4);
        xform(shade, "ADBE Opacity").expression = 'thisComp.layer("CTRL_Press").effect("press")(1) * ' + P.commandSideShadeOpacity;

        ctrl.moveToBeginning();
        // Adding an effect invalidates earlier property handles on the layer: look "press" up again.
        var press = ctrl.property("ADBE Effect Parade").property("press").property("ADBE Slider Control-0001");
        var t0 = P.startFrame / T.fps;
        var t1 = P.impactFrame / T.fps;
        press.setValueAtTime(t0, 0);
        press.setValueAtTime(t1, 1); // bottom-out, no bounce; held until the cut
        press.setInterpolationTypeAtKey(1, KeyframeInterpolationType.HOLD, KeyframeInterpolationType.BEZIER);
        press.setInterpolationTypeAtKey(2, KeyframeInterpolationType.LINEAR, KeyframeInterpolationType.HOLD);
        press.setTemporalEaseAtKey(1, [new KeyframeEase(0, 33)], [new KeyframeEase(0, 33)]);
        addMarker(rig, t1, "IMPACT (S02 f" + P.impactFrame + ") — SFX + kick");
        if (!item) addMarker(rig, 0, "Placeholder plate: masks follow h2-framing-guide.svg");
        return rig;
    }

    // ------------------------------------------------------------------ animation helpers

    // Stop-at-each-key easing. outInfl/inInfl are influences (%) for the segment between keys.
    function ease(prop, outInfl, inInfl) {
        function arr(n, infl) { var a = []; for (var i = 0; i < n; i++) a.push(new KeyframeEase(0, infl)); return a; }
        for (var k = 1; k <= prop.numKeys; k++) {
            var done = false, dims = [1, 2, 3];
            if (!prop.isSpatial && prop.value instanceof Array) dims = [prop.value.length, 2, 3, 1];
            for (var d = 0; d < dims.length && !done; d++) {
                try { prop.setTemporalEaseAtKey(k, arr(dims[d], k === 1 ? 33 : inInfl), arr(dims[d], k === prop.numKeys ? 33 : outInfl)); done = true; } catch (e) {}
            }
        }
    }
    function keys(prop, times, values, outInfl, inInfl) {
        for (var i = 0; i < times.length; i++) prop.setValueAtTime(times[i], values[i]);
        if (outInfl !== undefined) ease(prop, outInfl, inInfl);
    }
    function hold(prop) { for (var k = 1; k <= prop.numKeys; k++) prop.setInterpolationTypeAtKey(k, KeyframeInterpolationType.HOLD, KeyframeInterpolationType.HOLD); }
    var EXPO_OUT = [5, 85];   // fast start, long settle
    var IN_OUT = [60, 60];

    // Reveal: up dy px + fade in, expo-out.
    function revealUp(layer, t, dy, dur) {
        var p = xform(layer, "ADBE Position"), o = xform(layer, "ADBE Opacity"), v = p.value;
        keys(p, [t, t + dur], [[v[0], v[1] + dy], [v[0], v[1]]], EXPO_OUT[0], EXPO_OUT[1]);
        keys(o, [t, t + Math.min(dur, 0.3)], [0, 100]);
    }
    function exitUp(layer, t, dy, dur) {
        var p = xform(layer, "ADBE Position"), o = xform(layer, "ADBE Opacity");
        var v = p.valueAtTime(t, false);
        p.setValueAtTime(t, v); p.setValueAtTime(t + dur, [v[0], v[1] - dy]);
        o.setValueAtTime(t, 100); o.setValueAtTime(t + dur, 0);
    }
    function fadeIn(layer, t, dur) { keys(xform(layer, "ADBE Opacity"), [t, t + dur], [0, 100]); }

    function text(comp, name, str, font, size, hex, pos, right) {
        var l = addText(comp, name, str, font, size, hex, pos);
        if (right) {
            var prop = l.property("ADBE Text Properties").property("ADBE Text Document");
            var doc = prop.value;
            doc.justification = ParagraphJustification.RIGHT_JUSTIFY;
            prop.setValue(doc);
        }
        return l;
    }
    function width(layer) { return layer.sourceRectAtTime(0, false).width; }

    function rect(comp, name, w, h, r, fillHex, fillOp, strokeHex, strokeW, strokeOp) {
        var l = comp.layers.addShape();
        l.name = name;
        var g = l.property("ADBE Root Vectors Group").addProperty("ADBE Vector Group");
        var rc = g.property("ADBE Vectors Group").addProperty("ADBE Vector Shape - Rect");
        rc.property("ADBE Vector Rect Size").setValue([w, h]);
        rc.property("ADBE Vector Rect Roundness").setValue(r);
        if (strokeHex) {
            var st = g.property("ADBE Vectors Group").addProperty("ADBE Vector Graphic - Stroke");
            st.property("ADBE Vector Stroke Color").setValue(hexToRGB(strokeHex));
            st.property("ADBE Vector Stroke Width").setValue(strokeW);
            st.property("ADBE Vector Stroke Opacity").setValue(strokeOp === undefined ? 100 : strokeOp);
        }
        if (fillHex) {
            var fl = g.property("ADBE Vectors Group").addProperty("ADBE Vector Graphic - Fill");
            fl.property("ADBE Vector Fill Color").setValue(hexToRGB(fillHex));
            fl.property("ADBE Vector Fill Opacity").setValue(fillOp);
        }
        return l;
    }
    // Rectangle given by its top-left corner (comp px).
    function rectAt(comp, name, x, y, w, h, r, fillHex, fillOp, strokeHex, strokeW, strokeOp) {
        var l = rect(comp, name, w, h, r, fillHex, fillOp, strokeHex, strokeW, strokeOp);
        xform(l, "ADBE Position").setValue([x + w / 2, y + h / 2]);
        return l;
    }

    // UI stills (states.json from FilmFrameRenderTests) and the HUD chips rendered alongside them.
    var stillCache = {};
    function still(file) {
        if (!stillCache[file]) {
            var f = File(ROOT.fsName + "/" + T.ui.stillsDir + "/" + file);
            if (!f.exists) throw new Error("Missing UI still " + f.fsName + " — run FilmFrameRenderTests");
            var it = app.project.importFile(new ImportOptions(f));
            it.parentFolder = binUIStills;
            stillCache[file] = it;
        }
        return stillCache[file];
    }
    function state(name) {
        if (!U[name]) throw new Error("UI state " + name + " not in states.json");
        return U[name];
    }
    // A UI state hung from its top-centre (the real panel keeps its top edge when it resizes).
    // k = film px per UI point, so every state of a shot shares one scale.
    function uiState(comp, name, tIn, tOut, cx, top, k) {
        var it = still(state(name).file);
        var l = comp.layers.add(it);
        l.name = "UI_" + name;
        xform(l, "ADBE Anchor Point").setValue([it.width / 2, 0]);
        xform(l, "ADBE Position").setValue([cx, top]);
        var pct = k / T.ui.pxPerPoint * 100;
        xform(l, "ADBE Scale").setValue([pct, pct]);
        l.inPoint = tIn;
        l.outPoint = tOut;
        return l;
    }
    // UI point (x, y) inside a state placed by uiState → comp px.
    function uiPoint(name, cx, top, k, x, y) {
        return [cx - state(name).points[0] * k / 2 + x * k, top + y * k];
    }
    function chip(comp, slug, x, y, tIn, tOut) {
        var it = still("hud_chip_" + slug + ".png");
        var l = comp.layers.add(it);
        l.name = "HUD_" + slug;
        xform(l, "ADBE Anchor Point").setValue([0, 0]);
        xform(l, "ADBE Position").setValue([x, y]);
        xform(l, "ADBE Scale").setValue([50, 50]);
        l.inPoint = tIn;
        l.outPoint = tOut;
        return l;
    }
    function chipWidth(slug) { return state("hud_chip_" + slug).points[0]; }

    // Vector arrow cursor (original asset). path = [[t, x, y], ...] (hotspot), clicks = [t, ...].
    function cursor(comp, path, clicks, tOut) {
        var f = File(ROOT.fsName + "/" + T.ui.cursor.file);
        var it = app.project.importFile(new ImportOptions(f));
        it.parentFolder = binGFX;
        var l = comp.layers.add(it);
        l.name = "CURSOR";
        xform(l, "ADBE Anchor Point").setValue(T.ui.cursor.hotspotPx);
        var sc = T.ui.cursor.scale;
        xform(l, "ADBE Scale").setValue([sc, sc]);
        var p = xform(l, "ADBE Position");
        if (path.length === 1) p.setValue([path[0][1], path[0][2]]);
        else {
            for (var i = 0; i < path.length; i++) p.setValueAtTime(path[i][0], [path[i][1], path[i][2]]);
            ease(p, IN_OUT[0], IN_OUT[1]);
        }
        var s = xform(l, "ADBE Scale");
        for (var c = 0; c < clicks.length; c++) {
            s.setValueAtTime(clicks[c] - 0.04, [sc, sc]);
            s.setValueAtTime(clicks[c], [sc * 0.9, sc * 0.9]);
            s.setValueAtTime(clicks[c] + 0.08, [sc, sc]);
        }
        l.inPoint = path[0][0];
        if (tOut !== undefined) l.outPoint = tOut;
        return l;
    }

    function shotBase(id, dur) {
        var c = addComp("PC_BASE_" + id, dur, binPre);
        return c;
    }
    // Precomp layer used as a "world" the camera moves over; collapse keeps off-frame content.
    function addBase(sc, comp, anchor) {
        var l = sc.layers.add(comp);
        l.name = "BASE";
        l.collapseTransformation = true;
        if (anchor) {
            xform(l, "ADBE Anchor Point").setValue(anchor);
            xform(l, "ADBE Position").setValue(anchor);
        }
        return l;
    }
    function push(layer, t0, t1, from, to) {
        keys(xform(layer, "ADBE Scale"), [t0, t1], [[from, from], [to, to]]);
    }

    // ------------------------------------------------------------------ shots
    // Each builder fills the shot comp `sc` (picture, HUD) and the type comp `tc` (label + copy, MAIN only).

    var B = {};

    B.S01 = function (shot, sc, tc, dur) {
        var E = shot.events;
        var item = importAsset(shot.asset, binHF);
        var base;
        if (item) {
            base = sc.layers.add(item);
            base.startTime = -E.source.inSec;
            base.audioEnabled = false;            // the generated take carries an audio track
            base.frameBlendingType = FrameBlendingType.PIXEL_MOTION;   // 24 → 60 fps
            sc.frameBlending = true;
            push(base, 0, dur, E.source.scale * E.push[0] / 100, E.source.scale * E.push[1] / 100);
        } else base = placeholder(sc, shot.asset, dur);
        base.name = "BASE";

        // Word-unit reveal, 0.10 s stagger, 0.45 s expo-out; exit up 16 px from 1.75 s.
        function line(spec, font, name) {
            var x = E.x;
            for (var i = 0; i < spec.segments.length; i++) {
                var seg = spec.segments[i];
                var f = seg[1] === "latin" ? T.fonts.latin : font;
                var l = addText(tc, name + "_" + (i + 1), seg[0], f, spec.size, T.colors.ink, [x, spec.y]);
                x += width(l) + (seg[1] === "latin" ? spec.size * 0.06 : 0);
                revealUp(l, spec.at + i * E.stagger, 24, E.reveal);
                exitUp(l, E.exit, 16, dur - E.exit);
            }
        }
        line(E.line1, T.fonts.jpDisplay, "TYPE_L1");
        line(E.line2, T.fonts.jpText, "TYPE_L2");
    };

    B.S02 = function (shot, sc, tc, dur) {
        var E = shot.events;
        var item = importAsset(shot.asset, binPlate);
        var base = sc.layers.add(buildS02Rig(shot, item, binPre)); // still plate + AE press rig
        base.name = "BASE";
        finishS02(sc, base, shot);
        // ⌥ Space chip: appears, then sinks 2 px on exactly the frames the keys go down.
        var c = chip(sc, "option_space", E.chip.x, E.chip.y, 0, dur);
        revealUp(c, E.chip.at, 12, 0.3);
        xform(c, "ADBE Position").expression =
            'value + [0, comp("PC_H2R_RIG").layer("CTRL_Press").effect("press")(1) * ' + E.chip.sinkPx + ']';
        c.moveToBeginning();
    };

    B.S03 = function (shot, sc, tc, dur) {
        var E = shot.events, P = E.panel, k = P.widthPx / UIParameters.compactWidth;
        var w = shotBase("S03", dur);
        var typed = "git rev-parse --short HEAD";
        var t = E.typeStart;
        uiState(w, "s03_idle", 0, t, 960, P.top, k);
        for (var i = 1; i <= typed.length; i++) {
            var next = (i < typed.length) ? t + ((typed.charAt(i) === " " ? E.spaceFrames : E.typeFrames) / T.fps) : E.execute + state("s03_result").durationMs / 1000;
            uiState(w, "s03_type_" + (i < 10 ? "0" : "") + i, t, next, 960, P.top, k);
            t = next;
        }
        var done = E.execute + state("s03_result").durationMs / 1000;
        uiState(w, "s03_result", done, Math.min(dur, done + 1.0), 960, P.top, k);
        if (done + 1.0 < dur) uiState(w, "s03_result_settled", done + 1.0, dur, 960, P.top, k);
        var b = addBase(sc, w, [960, P.top + 48 * k]);
        push(b, 0, dur, E.push[0], E.push[1]);
        chip(sc, "cmd_return", 96, 904, E.runChip.at, E.runChip.at + E.runChip.dur);

        var copy = addText(tc, "TYPE_COPY", shot.copy[0], T.fonts.jpDisplay, E.copy.size, T.colors.ink, [E.copy.x, E.copy.y]);
        revealUp(copy, 0.15, 24, 0.45);
    };

    B.S04 = function (shot, sc, tc, dur) {
        var E = shot.events, P = E.panel, k = P.widthPx / UIParameters.compactWidth;
        var w = shotBase("S04", dur);
        // Fictional memo card (AE): title + the one command line, selected by the cursor.
        var C = E.card;
        var card = rectAt(w, "CARD", C.x, C.y, C.w, C.h, 16, "#1C1C1E", 100, T.colors.hairline, 1);
        var title = addText(w, "CARD_TITLE", C.title, T.fonts.jpText, 26, T.colors.muted, [C.x + 32, C.y + 64]);
        var cmd = addText(w, "CARD_LINE", C.line, T.fonts.mono, C.monoSize || 20, T.colors.ink, [C.x + 32, C.y + 150]);
        var lw = width(cmd);
        var sel = rectAt(w, "CARD_SELECTION", C.x + 28, C.y + 124, lw + 8, 36, 4, T.colors.accent, 38);
        sel.moveAfter(cmd);
        xform(sel, "ADBE Anchor Point").setValue([-(lw + 8) / 2, 0]);
        xform(sel, "ADBE Position").setValue([C.x + 28, C.y + 142]);
        keys(xform(sel, "ADBE Scale"), [E.select[0], E.select[1]], [[0, 100], [100, 100]], IN_OUT[0], IN_OUT[1]);
        var cardLayers = [card, title, cmd, sel];
        for (var c = 0; c < cardLayers.length; c++) keys(xform(cardLayers[c], "ADBE Opacity"), [E.cardFade[0], E.cardFade[1]], [100, 0]);
        cursor(w, [[0, C.x + 30, C.y + 136], [E.select[0], C.x + 30, C.y + 136], [E.select[1], C.x + 36 + lw, C.y + 140]], [E.select[0]], E.chips[1].at);

        // Hotkey → auto paste → run → copy happens inside the app within one frame (real timing).
        var done = E.summon + state("s04_result").durationMs / 1000;
        uiState(w, "s04_result", E.summon, Math.min(dur, E.summon + 1.0), 960, P.top, k);
        uiState(w, "s04_result_settled", E.summon + 1.0, dur, 960, P.top, k);
        // Accent ring around the "出力をコピーしました" feedback.
        var R = E.ring.rectPx, tl = uiPoint("s04_result", 960, P.top, k, R[0] / 2, R[1] / 2);
        var ring = rectAt(w, "FEEDBACK_RING", tl[0], tl[1], (R[2] - R[0]) / 2 * k, (R[3] - R[1]) / 2 * k, 8, null, 0, T.colors.accent, 2);
        ring.inPoint = E.ring.at;
        ring.outPoint = E.ring.at + E.ring.dur;
        keys(xform(ring, "ADBE Opacity"), [E.ring.at, E.ring.at + 0.08, E.ring.at + E.ring.dur], [0, 100, 0]);

        var b = addBase(sc, w, [960, P.top + 48 * k]);
        var pos = xform(b, "ADBE Position"), anc = [960, P.top + 48 * k];
        keys(pos, [0, E.pan[0], E.pan[1]], [[anc[0] + E.pan[2], anc[1]], [anc[0] + E.pan[2], anc[1]], anc], IN_OUT[0], IN_OUT[1]);
        push(b, E.push[0], E.push[1], E.push[2], E.push[3]);
        chip(sc, "cmd_c", 96, 904, E.chips[0].at, E.chips[0].at + E.chips[0].dur);
        chip(sc, "option_space", 96 + chipWidth("cmd_c") + 16, 904, E.chips[1].at, E.chips[1].at + E.chips[1].dur);

        // 貼る。実行。コピー。 — muted, each lit on its beat.
        var W = E.words, x = W.x;
        for (var i = 0; i < shot.copy.length; i++) {
            var dim = addText(tc, "TYPE_WORD_" + (i + 1) + "_muted", shot.copy[i], T.fonts.jpDisplay, W.size, T.colors.hairline, [x, W.y]);
            var lit = addText(tc, "TYPE_WORD_" + (i + 1), shot.copy[i], T.fonts.jpDisplay, W.size, T.colors.ink, [x, W.y]);
            keys(xform(lit, "ADBE Opacity"), [W.at[i] - 0.001, W.at[i] + 0.12], [0, 100]);
            fadeIn(dim, 0.15, 0.3);
            x += width(dim) + W.gap;
        }
    };

    B.S05 = function (shot, sc, tc, dur) {
        var E = shot.events, P = E.panel, k = P.widthPx / UIParameters.compactWidth;
        var w = shotBase("S05", dur);
        uiState(w, "s05_compact", 0, E.click, 960, P.top, k);
        uiState(w, "s05_split_ready", E.click, E.execute + state("s05_split_result").durationMs / 1000, 960, P.top, k);
        var done = E.execute + state("s05_split_result").durationMs / 1000;
        uiState(w, "s05_split_result", done, Math.min(dur, done + 1.0), 960, P.top, k);
        if (done + 1.0 < dur) uiState(w, "s05_split_result_settled", done + 1.0, dur, 960, P.top, k);
        // Split button: 5th toolbar button from the right edge of the compact bar (gear, split, …).
        var btn = uiPoint("s05_compact", 960, P.top, k, UIParameters.compactWidth - 68, 28);
        // The real window widens on the click, so the button slides away from the pointer: hide it right after.
        cursor(w, [[E.cursor.t[0], E.cursor.from[0], E.cursor.from[1]], [E.cursor.t[1], btn[0], btn[1]]], [E.click], E.click + (E.cursorHideAfterClick || 0.5));
        // Callout underlines under "exit 0" and "N ms" (measured on the render, 2x px).
        for (var i = 0; i < E.callouts.length; i++) {
            var cr = E.callouts[i], a = uiPoint("s05_split_result", 960, P.top, k, cr.rectPx[0] / 2, cr.rectPx[1] / 2);
            var line = rectAt(w, "CALLOUT_" + (i + 1), a[0], a[1], (cr.rectPx[2] - cr.rectPx[0]) / 2 * k, 2, 0, T.colors.accent, 100);
            var lw = (cr.rectPx[2] - cr.rectPx[0]) / 2 * k;
            xform(line, "ADBE Anchor Point").setValue([-lw / 2, 0]);
            xform(line, "ADBE Position").setValue([a[0], a[1] + 1]);
            keys(xform(line, "ADBE Scale"), [cr.at, cr.at + 0.35], [[0, 100], [100, 100]], EXPO_OUT[0], EXPO_OUT[1]);
            line.inPoint = cr.at;
        }
        var R = E.ring.rectPx, tl = uiPoint("s05_split_result", 960, P.top, k, R[0] / 2, R[1] / 2);
        var ring = rectAt(w, "FEEDBACK_RING", tl[0], tl[1], (R[2] - R[0]) / 2 * k, (R[3] - R[1]) / 2 * k, 8, null, 0, T.colors.accent, 2);
        ring.inPoint = done;
        ring.outPoint = done + E.ring.dur;
        keys(xform(ring, "ADBE Opacity"), [done, done + 0.08, done + E.ring.dur], [0, 100, 0]);

        var b = addBase(sc, w, E.pushAnchorPx);
        push(b, E.push[0], E.push[1], E.push[2], E.push[3]);
        chip(sc, "cmd_return", E.runChip.x, E.runChip.y, E.runChip.at, E.runChip.at + E.runChip.dur);

        var copy = addText(tc, "TYPE_COPY", shot.copy[0], T.fonts.jpDisplay, E.copy.size, T.colors.ink, [E.copy.x, E.copy.y]);
        revealUp(copy, done + 0.05, 24, 0.45);
    };

    B.S06 = function (shot, sc, tc, dur) {
        var E = shot.events, P = E.panel, k = P.widthPx / UIParameters.compactWidth;
        var w = shotBase("S06", dur);
        uiState(w, "s06_compact", 0, E.click, 960, P.top, k);
        uiState(w, "s06_history", E.click, E.cut, 960, P.top, k);
        var hist = uiPoint("s06_compact", 960, P.top, k, UIParameters.compactWidth - 148, 28);
        cursor(w, [[E.cursor.t[0], E.cursor.from[0], E.cursor.from[1]], [E.cursor.t[1], hist[0], hist[1]]], [E.click], E.cut);

        // Hard cut on beat 26 to the destructive-command confirmation.
        uiState(w, "s06_alert_panel", E.cut, dur, 960, P.top, k);
        var A = E.alert, a0 = uiPoint("s06_alert_panel", 960, P.top, k, (UIParameters.compactWidth - A.pointsSize[0]) / 2, A.topOffsetPt);
        // RECONSTRUCTED frame + buttons (the offscreen render cannot capture the alert's vibrancy layers).
        var frame = rectAt(w, "ALERT_FRAME_reconstructed", a0[0], a0[1], A.pointsSize[0] * k, A.pointsSize[1] * k, A.radiusPt * k, "#2A2A2C", 98, "#FFFFFF", 1, 12);
        frame.inPoint = E.cut;
        var txt = w.layers.add(still(state(A.text).file));   // real AppKit drawing of the alert's text
        txt.name = "ALERT_TEXT_real";
        xform(txt, "ADBE Anchor Point").setValue([0, 0]);
        xform(txt, "ADBE Position").setValue(a0);
        xform(txt, "ADBE Scale").setValue([k / T.ui.pxPerPoint * 100, k / T.ui.pxPerPoint * 100]);
        txt.inPoint = E.cut;
        var hoverPt = null;
        for (var i = 0; i < A.buttons.length; i++) {
            var bt = A.buttons[i], r = bt.rectPt;
            var destructive = bt.role === "destructive";
            var br = rectAt(w, "ALERT_BUTTON_" + (i + 1) + "_reconstructed", a0[0] + r[0] * k, a0[1] + r[1] * k, (r[2] - r[0]) * k, (r[3] - r[1]) * k,
                            (r[3] - r[1]) * k / 2, destructive ? T.colors.danger : "#5A5A5E", destructive ? 22 : 70);
            br.inPoint = E.cut;
            var lb = addText(w, "ALERT_LABEL_" + (i + 1), bt.label, T.fonts.uiJp, 13 * k, destructive ? T.colors.danger : T.colors.ink,
                             [a0[0] + (r[0] + r[2]) / 2 * k, a0[1] + (r[1] + r[3]) / 2 * k + 4.5 * k]);
            var prop = lb.property("ADBE Text Properties").property("ADBE Text Document"), doc = prop.value;
            doc.justification = ParagraphJustification.CENTER_JUSTIFY;
            prop.setValue(doc);
            lb.inPoint = E.cut;
            if (i === E.hover.button) hoverPt = [a0[0] + (r[0] + r[2]) / 2 * k, a0[1] + (r[1] + r[3]) / 2 * k];
        }
        // Cursor ends hovering キャンセル (the click happens after the cut).
        cursor(w, [[E.cut, hoverPt[0] + 260, hoverPt[1] + 180], [E.hover.t[0], hoverPt[0] + 260, hoverPt[1] + 180], [E.hover.t[1], hoverPt[0] + 6, hoverPt[1] + 4]], [], dur);

        var b = addBase(sc, w, [960, 540]);
        var pos = xform(b, "ADBE Position");
        // Slow vertical track over the history, then the cut resets the frame (hold, no move back).
        keys(pos, [E.track[0], Math.min(E.track[1], E.cut - 1 / T.fps)], [[960, 540], [960, 540 + E.track[2]]], IN_OUT[0], IN_OUT[1]);
        pos.setValueAtTime(E.cut, [960, 540]);
        pos.setInterpolationTypeAtKey(2, KeyframeInterpolationType.BEZIER, KeyframeInterpolationType.HOLD);

        var c1 = addText(tc, "TYPE_COPY_1", shot.copy[0], T.fonts.jpDisplay, E.copy.size, T.colors.ink, [E.copy.x, E.copy.y]);
        revealUp(c1, 0.15, 24, 0.45);
        c1.outPoint = E.copy.second;
        var c2 = addText(tc, "TYPE_COPY_2", shot.copy[1], T.fonts.jpDisplay, E.copy.size, T.colors.ink, [E.copy.x, E.copy.y]);
        c2.inPoint = E.copy.second;
        revealUp(c2, E.copy.second, 24, 0.45);
    };

    function ribbonLayer(comp, item, E, dur) {
        var l = comp.layers.add(item);
        var cover = Math.max(T.width / item.width, T.height / item.height) * 100;
        keys(xform(l, "ADBE Scale"), [0, dur], [[cover * E.scale[0] / 100, cover * E.scale[0] / 100], [cover * E.scale[1] / 100, cover * E.scale[1] / 100]]);
        keys(xform(l, "ADBE Position"), [0, dur], [[960 + E.drift[0], 540 + E.drift[1]], [960, 540]]);
        return l;
    }

    B.S07 = function (shot, sc, tc, dur) {
        var E = shot.events;
        var item = importAsset(shot.asset, binHF);
        if (!item) { placeholder(sc, shot.asset, dur).name = "BASE"; return; }
        var rib = ribbonLayer(sc, item, E, dur);
        rib.name = "BASE_RIBBON";
        // Light pass: reveal along the ribbon (bottom-left → top-right), then brighten for the luma wipe.
        var wipe = rib.property("ADBE Effect Parade").addProperty("ADBE Linear Wipe");
        wipe.property("ADBE Linear Wipe-0002").setValue(E.wipeAngle === undefined ? 225 : E.wipeAngle);
        wipe.property("ADBE Linear Wipe-0003").setValue(420);
        keys(rib.property("ADBE Effect Parade").property(1).property("ADBE Linear Wipe-0001"), [E.wipeIn[0], E.wipeIn[1]], [100, 0], EXPO_OUT[0], EXPO_OUT[1]);
        keys(addExposure(rib), [E.bright[0], E.bright[1]], [E.bright[2], E.bright[3]], 40, 60);

        // The last S06 frame (panel after cancel) shrinks into the light.
        var k = shots.S06.events.panel.widthPx / UIParameters.compactWidth;
        var ui = uiState(sc, E.freeze, 0, dur, 960, shots.S06.events.panel.top, k);
        var pct = k / T.ui.pxPerPoint * 100;
        var anchorY = state(E.freeze).pixels[1] / 2;
        xform(ui, "ADBE Anchor Point").setValue([state(E.freeze).pixels[0] / 2, anchorY]);
        xform(ui, "ADBE Position").setValue([960, shots.S06.events.panel.top + anchorY * pct / 100]);
        keys(xform(ui, "ADBE Scale"), [E.uiShrink[0], E.uiShrink[1]], [[pct * E.uiShrink[2] / 100, pct * E.uiShrink[2] / 100], [pct * E.uiShrink[3] / 100, pct * E.uiShrink[3] / 100]], 40, 70);
        keys(xform(ui, "ADBE Opacity"), [E.uiFade[0], E.uiFade[1]], [100, 0]);
    };

    B.S08 = function (shot, sc, tc, dur) {
        var E = shot.events, P = E.panel, k = P.widthPx / UIParameters.compactWidth;
        var w = shotBase("S08", dur);
        uiState(w, "s08_idle", 0, dur, P.centerX, P.top, k);
        chip(w, "option_space", E.chip.x, E.chip.y, 0, dur);
        addBase(sc, w);

        var label = addText(tc, "TYPE_LABEL_S08", shot.label, T.fonts.mono, 18, T.colors.muted, [E.label.x, E.label.y]);
        var mark = addText(tc, "TYPE_WORDMARK", shot.copy[0], T.fonts.latin, E.wordmark.size, T.colors.ink, [E.wordmark.x, E.wordmark.y]);
        var prop = mark.property("ADBE Text Properties").property("ADBE Text Document"), doc = prop.value;
        doc.tracking = -30;
        prop.setValue(doc);
        var line = addText(tc, "TYPE_LINE", shot.copy[1], T.fonts.jpText, E.line.size, T.colors.ink, [E.line.x, E.line.y]);
        var url = text(tc, "TYPE_URL", shot.copy[2], T.fonts.mono, E.url.size, T.colors.muted, [E.url.rightX, E.url.y], true);
        var seq = [mark, line, url];
        for (var i = 0; i < seq.length; i++) revealUp(seq[i], E.firstIn + i * E.stagger, 24, 0.45);
        fadeIn(label, E.firstIn, 0.3);
    };

    // Luma wipe S07 → S08: S08 shows through the ribbon's brightest areas first, then fully on the cut.
    function addLumaWipe(mainComp, s07, s08, s08Comp) {
        var E = s07.events;
        var item = importAsset(s07.asset, binHF);
        if (!item) return;
        // Same ribbon move as S07 (same duration and start), so matte and picture stay registered.
        var s07dur = s07.end - s07.start;
        var mc = addComp("PC_RIBBON_LUMA_MATTE", s07dur, binPre);
        var rib = ribbonLayer(mc, item, E, s07dur);
        // Inverted luma: the end card shows first where the ribbon is darkest (its edges) and last in
        // the bright core, so the light recedes into the dark end card instead of burning to black.
        var ex = E.lumaExposure || [-4, 5];
        keys(addExposure(rib), [E.lumaWipe[0], E.lumaWipe[1]], [ex[0], ex[1]], 30, 60);
        var inLayer = mainComp.layers.add(s08Comp);
        inLayer.name = "S08_LUMA_IN";
        inLayer.startTime = s07.start + E.lumaWipe[0];
        inLayer.outPoint = s07.end;
        var matte = mainComp.layers.add(mc);
        matte.name = "MATTE_RIBBON_LUMA";
        matte.startTime = s07.start;
        var mt = E.lumaInverted ? TrackMatteType.LUMA_INVERTED : TrackMatteType.LUMA;
        if (inLayer.setTrackMatte) inLayer.setTrackMatte(matte, mt);
        else { matte.moveBefore(inLayer); inLayer.trackMatteType = mt; }
        matte.enabled = false;
    }

    // Exposure pulse on the impact frame and the still-plate push, inside the S02 shot comp.
    function finishS02(sc, base, shot) {
        var P = shot.press;
        var dur = shot.end - shot.start;
        push(base, 0, dur, P.push.from, P.push.to);
        var adj = sc.layers.addSolid([1, 1, 1], "ADJ_ImpactPulse", T.width, T.height, 1, dur);
        adj.adjustmentLayer = true;
        adj.moveToBeginning();
        var ev = addExposure(adj);
        var a = P.pulse.frame / T.fps;
        var b = (P.pulse.frame + P.pulse.frames) / T.fps;
        ev.setValueAtTime(a - 1 / T.fps, 0);
        ev.setValueAtTime(a, P.pulse.exposure);
        ev.setValueAtTime(b, 0);
        hold(ev);
    }

    // ------------------------------------------------------------------ build
    var T = readJSON("planning/timeline.json");
    var M = readJSON("assets/manifest.json");
    var UIParameters = { compactWidth: 720 };   // LauncherView compact width (Sources/MiniTerminal/DesignSystem.swift)
    var U = {};
    (function () {
        var states = readJSON(T.ui.states).states;
        for (var i = 0; i < states.length; i++) if (states[i].state) U[states[i].state] = states[i];
    })();
    var shots = {};
    for (var si = 0; si < T.shots.length; si++) shots[T.shots[si].id] = T.shots[si];

    if (app.project) app.project.close(CloseOptions.DO_NOT_SAVE_CHANGES);
    app.newProject();
    app.beginUndoGroup("Build Mini-Terminal Launch Film");
    app.project.bitsPerChannel = 16;

    var binOut = folder("00_OUTPUT");
    var binShots = folder("01_SHOTS");
    var binPre = folder("02_PRECOMPS");
    var binAssets = folder("03_ASSETS");
    var binUI = folder("UI", binAssets);
    var binUIStills = folder("UI_STILLS_offscreen", binUI);
    var binHF = folder("HF", binAssets);
    var binPlate = folder("PLATE", binAssets);
    var binAudio = folder("AUDIO", binAssets);
    var binGFX = folder("GFX", binAssets);
    var binGuides = folder("04_GUIDES");

    var main = addComp("MAIN_LaunchFilm_1920x1080_60", T.duration, binOut);
    var textless = addComp("MAIN_LaunchFilm_textless", T.duration, binOut);
    var shotComps = {};

    for (var s = 0; s < T.shots.length; s++) {
        var shot = T.shots[s];
        var dur = shot.end - shot.start;
        var sc = addComp(shot.id + "_" + shot.name, dur, binShots);
        sc.layers.addSolid(hexToRGB(T.colors.bg), "BG", T.width, T.height, 1, dur);
        // TYPE lives in its own pre-comp and is layered in MAIN only,
        // so MAIN_textless and the README loops share the same shot comps without copy.
        var tc = addComp("PC_TYPE_" + shot.id, dur, binPre);
        if (shot.label && shot.id !== "S08") addText(tc, "TYPE_LABEL", shot.label, T.fonts.mono, 18, T.colors.muted, [T.grid.margin, T.grid.margin + 18]);
        B[shot.id](shot, sc, tc, dur);
        shotComps[shot.id] = sc;

        var l = main.layers.add(sc);
        l.startTime = shot.start;
        l.outPoint = shot.end;
        var typeLayer = main.layers.add(tc);
        typeLayer.name = "TYPE_" + shot.id;
        typeLayer.startTime = shot.start;
        typeLayer.outPoint = shot.end;
        addMarker(main, shot.start, shot.id + " " + shot.name);

        var lt = textless.layers.add(sc);
        lt.startTime = shot.start;
        lt.outPoint = shot.end;
    }
    addLumaWipe(main, shots.S07, shots.S08, shotComps.S08);
    addLumaWipe(textless, shots.S07, shots.S08, shotComps.S08);

    // End: 0.4 s to black (MAIN only; loops use the textless comp, which never goes black).
    var fade = main.layers.addSolid([0, 0, 0], "FADE_OUT", T.width, T.height, 1, T.duration);
    var fo = shots.S08.events.fadeOut;
    keys(xform(fade, "ADBE Opacity"), [shots.S08.start + fo[0], shots.S08.start + fo[1]], [0, 100]);
    fade.moveToBeginning();

    // Beat + narration markers on MAIN
    var beat = 0;
    for (var t = 0; t < T.duration - 0.0001; t += T.beatSeconds) {
        beat++;
        addMarker(main, t, (beat - 1) % 4 === 0 ? "bar b" + beat : "b" + beat);
    }

    // The default cut has no narration (audioVersions NOVO): cue layers are disabled
    // and only switched on when building the VO_STANDARD / VO_KANSAI versions.
    var voStd = main.layers.addNull(T.duration);
    voStd.name = "VO_CUES_standard";
    voStd.enabled = false;
    var voKan = main.layers.addNull(T.duration);
    voKan.name = "VO_CUES_kansai";
    voKan.enabled = false;
    for (var n = 0; n < T.narration.standard.length; n++) {
        addMarker(voStd, T.narration.standard[n].start, T.narration.standard[n].id + " " + T.narration.standard[n].text);
        addMarker(voKan, T.narration.kansai[n].start, T.narration.kansai[n].id + " " + T.narration.kansai[n].text);
    }

    // TEMP music + SFX (ae/scripts/make-temp-audio.py). VO tracks are not imported (NOVO cut).
    var audioFile = File(ROOT.fsName + "/" + T.audio.temp);
    if (audioFile.exists) {
        var aItem = app.project.importFile(new ImportOptions(audioFile));
        aItem.parentFolder = binAudio;
        var aLayer = main.layers.add(aItem);
        aLayer.name = "AUDIO_TEMP_mix";
        aLayer.startTime = 0;
    }

    var grade = main.layers.addSolid([1, 1, 1], "ADJ_Grade", T.width, T.height, 1, T.duration);
    grade.adjustmentLayer = true;
    grade.moveToBeginning();

    // Burned-in PREVIEW notes: temporary / reconstructed parts are labelled on screen.
    // Disable WIP_NOTES (or set timeline.json wip to {}) for the final render.
    if (T.wip && T.wip.global) {
        var notes = addComp("WIP_NOTES", T.duration, binGuides);
        for (var w = 0; w < T.shots.length; w++) {
            var sh = T.shots[w];
            if (!T.wip[sh.id]) continue;
            var nl = text(notes, "WIP_" + sh.id, T.wip.global + "\r" + sh.id + " · " + T.wip[sh.id], T.fonts.jpText, 15, "#FF9F0A", [T.width - 32, 34], true);
            nl.inPoint = sh.start;
            nl.outPoint = sh.end;
        }
        var wn = main.layers.add(notes);
        wn.name = "WIP_NOTES";
        wn.moveToBeginning();
    }

    var guideComp = addComp("GUIDE_Grid12", T.duration, binGuides);
    gridGuide(guideComp);
    var g = main.layers.add(guideComp);
    g.guideLayer = true;
    g.moveToBeginning();

    // README loops: nest MAIN_textless and offset into the loop window.
    for (var k = 0; k < T.loops.length; k++) {
        var lp = T.loops[k];
        var lc = addComp(lp.id, lp.end - lp.start, binOut);
        var nested = lc.layers.add(textless);
        nested.startTime = -lp.start;
        // TODO: replace the last 0.3s with an Esc-dismiss tail so last frame == first frame.
    }

    main.openInViewer();
    app.endUndoGroup();

    if (!$.global.MT_HEADLESS) alert("Mini-Terminal launch film built.\n" + T.shots.length + " shots, " + beat + " beats, " +
          T.loops.length + " loop comps.\nSave into launch-video/ae/project/ (git-ignored).");
})();
