// Theme editor: theme/themecolors.js against values computed once by apply.py's own functions (the fixture below was made by
// running apply.py's contrast / darker / lift_highlight / darken_to / derive rules on every themes.json palette, a few broken
// ones and 60 random colour pairs), and popups/ThemeEditor.qml with real clicks and keys: the eight roles with swatch / hex /
// Pick, live contrast lines, Save writes custom-theme.json, Apply sets the theme to "custom" and is off while apply.py would
// refuse the palette. ThemeEditor is a layer-shell PanelWindow and can't be created offscreen: like updatespanel.qml this loads
// a scratch copy (in the runner's scratch tree) with PanelWindow turned into FloatingWindow. Pick runs a harmless printf in
// place of scripts/colorpick.sh (that script is tested with a fake hyprpicker in tests/media-scripts-test.py).
import QtQuick
import QtTest
import Quickshell
import Quickshell.Io
import "theme/themecolors.js" as TC

ShellRoot {
    id: shell
    property var warm: Config.settingsLoaded
    property int failures: 0
    property int closed: 0
    readonly property var fix: JSON.parse('{"palettes":{"default":{"roles":{"base":"#d8d8d8","shadow":"#9b9b9b","highlight":"#fdfdfd","urgent":"#be552e","accent":"#207874","text":"#000000","outline":"#000000","outlineGradientFade":"#161616"},"textBase":14.733706248706273,"textHighlight":20.645011006662344,"textShadow":7.5555619611308416,"edge":1.4012096249356896,"urgent":3.2537083865767262,"select":["#1c6865","#d8d8d8"],"selectRatio":4.579356961009021,"lift":"#fdfdfd","darkenUrgent":"#be552e"},"yorha":{"roles":{"base":"#d9caba","shadow":"#baafa1","highlight":"#f4efea","urgent":"#a65631","accent":"#626335","text":"#3e3d38","outline":"#3d3d39","outlineGradientFade":"#5b5b45"},"textBase":6.793507508684138,"textHighlight":9.526821176201075,"textShadow":5.045250465169655,"edge":1.4023420396640385,"urgent":3.279468436711314,"select":["#55562e","#d9caba"],"selectRatio":4.754594606179186,"lift":"#f4efea","darkenUrgent":"#a65631"},"cherry":{"roles":{"base":"#f4c9ef","shadow":"#c7a4cc","highlight":"#fefafd","urgent":"#a86147","accent":"#c950bb","text":"#321d32","outline":"#20091d","outlineGradientFade":"#3e233e"},"textBase":10.643437544366092,"textHighlight":14.95977146316754,"textShadow":7.079969823835893,"edge":1.4055394604242517,"urgent":3.235160093584882,"select":["#c950bb","#20091d"],"selectRatio":4.783030825715033,"lift":"#fefafd","darkenUrgent":"#a86147"},"dusty":{"roles":{"base":"#e3b9d6","shadow":"#a47aa0","highlight":"#fbe3f6","urgent":"#985740","accent":"#d4609a","text":"#2a1228","outline":"#20091d","outlineGradientFade":"#3e233e"},"textBase":10.016997728859634,"textHighlight":14.330444507128279,"textShadow":4.8287896029566335,"edge":1.4306127339772994,"urgent":3.2278655591926166,"select":["#d4609a","#20091d"],"selectRatio":5.311221833382185,"lift":"#fbe3f6","darkenUrgent":"#985740"},"indigo":{"roles":{"base":"#bac4e6","shadow":"#7e8bad","highlight":"#e3e7f5","urgent":"#c12f2f","accent":"#3e7c99","text":"#0d0d19","outline":"#1a2135","outlineGradientFade":"#223143"},"textBase":11.138240318685131,"textHighlight":15.62849707840629,"textShadow":5.679694548941251,"edge":1.4031387931348958,"urgent":3.2640522693430603,"select":["#2b566a","#bac4e6"],"selectRatio":4.589943881686532,"lift":"#e3e7f5","darkenUrgent":"#c12f2f"},"gleep":{"roles":{"base":"#bae6c5","shadow":"#93c48c","highlight":"#ffffff","urgent":"#be5742","accent":"#3e9949","text":"#0d1913","outline":"#21351a","outlineGradientFade":"#284223"},"textBase":13.051815802540581,"textHighlight":18.016953720530392,"textShadow":9.021577621962324,"edge":1.3804174065208097,"urgent":3.2847225535027373,"select":["#3e9949","#0d1913"],"selectRatio":5.025466813287627,"lift":"#ffffff","darkenUrgent":"#be5742"},"win95":{"roles":{"base":"#c0c0c0","shadow":"#808080","highlight":"#ffffff","urgent":"#b00000","accent":"#000080","text":"#000000","outline":"#000000","outlineGradientFade":"#404040"},"textBase":11.542302514116262,"textHighlight":21.0,"textShadow":5.317210002277984,"edge":1.8193943517176883,"urgent":4.05559251163138,"select":["#000080","#c0c0c0"],"selectRatio":8.79948156468494,"lift":"#ffffff","darkenUrgent":"#b00000"},"platinum":{"roles":{"base":"#dddddd","shadow":"#999999","highlight":"#ffffff","urgent":"#b83030","accent":"#5c5ca8","text":"#000000","outline":"#000000","outlineGradientFade":"#333333"},"textBase":15.461102578439387,"textHighlight":21.0,"textShadow":7.3709355625018365,"edge":1.3582472461753565,"urgent":4.4130064833548195,"select":["#5858a0","#dddddd"],"selectRatio":4.659142388357358,"lift":"#ffffff","darkenUrgent":"#b83030"},"lowedge":{"roles":{"base":"#f4c9ef","shadow":"#c7a4cc","highlight":"#f5cbf0","urgent":"#a86147","accent":"#c950bb","text":"#321d32","outline":"#20091d","outlineGradientFade":"#3e233e"},"textBase":10.643437544366092,"textHighlight":10.816889353315954,"textShadow":7.079969823835893,"edge":1.0162965966800523,"urgent":3.235160093584882,"select":["#c950bb","#20091d"],"selectRatio":4.783030825715033,"lift":"#fefafd","darkenUrgent":"#a86147"},"lowurgent":{"roles":{"base":"#f4c9ef","shadow":"#c7a4cc","highlight":"#fefafd","urgent":"#f0a0d0","accent":"#c950bb","text":"#321d32","outline":"#20091d","outlineGradientFade":"#3e233e"},"textBase":10.643437544366092,"textHighlight":14.95977146316754,"textShadow":7.079969823835893,"edge":1.4055394604242517,"urgent":1.3573299537975345,"select":["#c950bb","#20091d"],"selectRatio":4.783030825715033,"lift":"#fefafd","darkenUrgent":"#966482"},"weakselect":{"roles":{"base":"#909090","shadow":"#c7a4cc","highlight":"#fefafd","urgent":"#a86147","accent":"#808080","text":"#989898","outline":"#a0a0a0","outlineGradientFade":"#3e233e"},"textBase":1.1067043539401278,"textHighlight":2.789479180296133,"textShadow":1.3201691262022406,"edge":3.0871287540590693,"urgent":1.4729366782466118,"select":["#404040","#909090"],"selectRatio":3.2477142542031254,"lift":"#fefafd","darkenUrgent":"#5e3628"},"midgrey":{"roles":{"base":"#777777","shadow":"#555555","highlight":"#999999","urgent":"#ff0000","accent":"#7f7f7f","text":"#ffffff","outline":"#000000","outlineGradientFade":"#111111"},"textBase":4.478089453577214,"textHighlight":2.849027755287037,"textShadow":7.455177810447525,"edge":1.5717956574017475,"urgent":1.1199488481041677,"select":["#7f7f7f","#000000"],"selectRatio":5.244615148281104,"lift":"#999999","darkenUrgent":"#5d0000"}},"pairs":[["#a5cd68","#4d3c1a",5.833770804327394],["#18b8ff","#25165e",6.891985451017234],["#3031d0","#bb3b93",1.6801995885702514],["#1db208","#6deceb",2.000032598357531],["#2c0146","#de06ce",4.186447118052551],["#23c417","#7b382e",3.6692544269648364],["#d95a94","#1e43bb",2.267568021681434],["#3f62f8","#724c60",1.4782883938661795],["#1fac61","#cb19b4",1.6442718828656235],["#7131a3","#17d9af",4.336758628379725],["#442f7d","#9447ab",1.9237748768937315],["#49dbcd","#3c4f43",5.141992435524724],["#9df154","#5c882b",3.0217351776798957],["#6030a1","#beaae4",4.131625403799516],["#2025e0","#1e840b",1.8150728120154649],["#69736b","#fe2a0a",1.30115038614562],["#daed60","#a0d7e5",1.2185879535486723],["#e807c8","#b92152",1.5564979727505592],["#7f31c4","#5c0a63",1.8698574259187108],["#29e8e6","#99ba40",1.4578375684108589],["#fd7fe4","#afdc0b",1.3999263538237883],["#936c94","#257a95",1.120284020490751],["#d61431","#5475e9",1.2733704343800252],["#4dd0ea","#fa595f",1.7308932007982258],["#1412f9","#27bddf",3.796366208791646],["#a0a383","#ae2484",2.3812944466992034],["#fe4c28","#e993be",1.4942473848463191],["#2febd0","#8a357b",4.838476436444243],["#2147ad","#1f1010",2.254126321840759],["#e42b06","#91b681",1.9823908059183775],["#b1aaac","#0b8d5e",1.8482499607274478],["#b5ff64","#560a6f",10.459262415909683],["#3bf3fa","#fcc554",1.160938407533428],["#6fb8ed","#932a47",3.663456457332786],["#7ec75f","#cbb93e",1.0319621420303045],["#fe3620","#2941f3",1.832558111774018],["#e5fbe4","#cda450",2.133793572569025],["#8e40ee","#461b2e",2.8271339668020437],["#8e8d34","#d4a1be",1.6042245610345314],["#c2c933","#76250f",5.728340077251482],["#2a7cf8","#5a3935",2.5765153169200476],["#76c30c","#7777d3",1.7863744541892885],["#f84d08","#5d5c0b",2.018028200271149],["#905939","#02188e",2.4109531455583624],["#d68027","#bd0ecd",1.6981416131401752],["#a32111","#40406c",1.2837056007700114],["#1ba4f4","#e9cd34",1.7286494820101759],["#c8e5e3","#cbcfc8",1.1860628751571456],["#c9ca19","#3502d0",5.768460204340042],["#cd06d1","#1fdef2",2.815353697156136],["#227b62","#6ae302",3.090406908759421],["#531967","#384885",1.4293638699500344],["#1aeb30","#346b19",3.9746934648197096],["#4d7298","#33f323",3.3490578778792486],["#0d0e73","#240067",1.0445531001940334],["#c0a122","#4c0ecf",3.68204334364529],["#b1dd0a","#ba73a1",2.1828106483331404],["#3ee52d","#3b0f9d",7.150680116947535],["#ee962b","#f5f658",2.015500865689082],["#9fab1b","#2bf913",1.763329409780229]],"darker":[["#a5cd68",2.0,"#526634"],["#18b8ff",3.3,"#07384d"],["#3031d0",3.3,"#0f0f3f"],["#1db208",1.0,"#1db208"],["#2c0146",2.0,"#160023"],["#23c417",1.0,"#23c417"],["#d95a94",3.3,"#421b2d"],["#3f62f8",3.3,"#131e4b"],["#1fac61",1.0,"#1fac61"],["#7131a3",3.3,"#220f31"],["#442f7d",2.0,"#22173e"],["#49dbcd",3.3,"#16423e"],["#9df154",1.0,"#9df154"],["#6030a1",1.0,"#6030a1"],["#2025e0",3.3,"#0a0b44"],["#69736b",3.3,"#202320"],["#daed60",2.0,"#6d7630"],["#e807c8",1.1,"#d306b6"],["#7f31c4",1.7,"#4b1d73"],["#29e8e6",3.3,"#0c4646"],["#fd7fe4",2.0,"#7e4072"],["#936c94",1.0,"#936c94"],["#d61431",1.1,"#c3122d"],["#4dd0ea",2.0,"#266875"],["#1412f9",3.3,"#06054b"],["#a0a383",1.1,"#919477"],["#fe4c28",1.0,"#fe4c28"],["#2febd0",2.0,"#187668"],["#2147ad",1.1,"#1e419d"],["#e42b06",2.0,"#721603"],["#b1aaac",2.0,"#585556"],["#b5ff64",3.3,"#374d1e"],["#3bf3fa",1.0,"#3bf3fa"],["#6fb8ed",1.7,"#416c8b"],["#7ec75f",2.0,"#3f642f"],["#fe3620",1.7,"#952013"],["#e5fbe4",3.3,"#454c45"],["#8e40ee",2.0,"#472077"],["#8e8d34",1.1,"#81802f"],["#c2c933",1.7,"#72761e"],["#2a7cf8",1.7,"#194992"],["#76c30c",1.0,"#76c30c"],["#f84d08",1.1,"#e14607"],["#905939",1.7,"#553422"],["#d68027",3.3,"#41270c"],["#a32111",3.3,"#310a05"],["#1ba4f4",3.3,"#08324a"],["#c8e5e3",2.0,"#647272"],["#c9ca19",2.0,"#65650c"],["#cd06d1",1.7,"#79047b"],["#227b62",2.0,"#113e31"],["#531967",1.1,"#4b175e"],["#1aeb30",1.0,"#1aeb30"],["#4d7298",1.1,"#46688a"],["#0d0e73",1.7,"#080844"],["#c0a122",1.1,"#af921f"],["#b1dd0a",2.0,"#596e05"],["#3ee52d",2.0,"#1f7216"],["#ee962b",2.0,"#774b16"],["#9fab1b",1.7,"#5e6510"]],"lift":[["#a5cd68","#4d3c1a","#4d3c1a"],["#18b8ff","#25165e","#25165e"],["#3031d0","#bb3b93","#bb3b93"],["#1db208","#6deceb","#6deceb"],["#2c0146","#de06ce","#de06ce"],["#23c417","#7b382e","#7b382e"],["#d95a94","#1e43bb","#1e43bb"],["#3f62f8","#724c60","#724c60"],["#1fac61","#cb19b4","#cb19b4"],["#7131a3","#17d9af","#17d9af"],["#442f7d","#9447ab","#9447ab"],["#49dbcd","#3c4f43","#3c4f43"],["#9df154","#5c882b","#5c882b"],["#6030a1","#beaae4","#beaae4"],["#2025e0","#1e840b","#1e840b"],["#69736b","#fe2a0a","#828b84"],["#daed60","#a0d7e5","#ffffff"],["#e807c8","#b92152","#b92152"],["#7f31c4","#5c0a63","#5c0a63"],["#29e8e6","#99ba40","#99ba40"],["#fd7fe4","#afdc0b","#afdc0b"],["#936c94","#257a95","#a888a8"],["#d61431","#5475e9","#e15369"],["#4dd0ea","#fa595f","#fa595f"],["#1412f9","#27bddf","#27bddf"],["#a0a383","#ae2484","#ae2484"],["#fe4c28","#e993be","#e993be"],["#2febd0","#8a357b","#8a357b"],["#2147ad","#1f1010","#1f1010"],["#e42b06","#91b681","#91b681"],["#b1aaac","#0b8d5e","#0b8d5e"],["#b5ff64","#560a6f","#560a6f"],["#3bf3fa","#fcc554","#ffffff"],["#6fb8ed","#932a47","#932a47"],["#7ec75f","#cbb93e","#b9e1a9"],["#fe3620","#2941f3","#2941f3"],["#e5fbe4","#cda450","#cda450"],["#8e40ee","#461b2e","#461b2e"],["#8e8d34","#d4a1be","#d4a1be"],["#c2c933","#76250f","#76250f"],["#2a7cf8","#5a3935","#5a3935"],["#76c30c","#7777d3","#7777d3"],["#f84d08","#5d5c0b","#5d5c0b"],["#905939","#02188e","#02188e"],["#d68027","#bd0ecd","#bd0ecd"],["#a32111","#40406c","#b4493c"],["#1ba4f4","#e9cd34","#e9cd34"],["#c8e5e3","#cbcfc8","#ffffff"],["#c9ca19","#3502d0","#3502d0"],["#cd06d1","#1fdef2","#1fdef2"],["#227b62","#6ae302","#6ae302"],["#531967","#384885","#384885"],["#1aeb30","#346b19","#346b19"],["#4d7298","#33f323","#33f323"],["#0d0e73","#240067","#2f3087"],["#c0a122","#4c0ecf","#4c0ecf"],["#b1dd0a","#ba73a1","#ba73a1"],["#3ee52d","#3b0f9d","#3b0f9d"],["#ee962b","#f5f658","#f5f658"],["#9fab1b","#2bf913","#2bf913"]],"darken":[["#a5cd68","#4d3c1a","#a5cd68"],["#18b8ff","#25165e","#18b8ff"],["#3031d0","#bb3b93","#15155b"],["#1db208","#6deceb","#168906"],["#2c0146","#de06ce","#2c0146"],["#23c417","#7b382e","#23c417"],["#d95a94","#1e43bb","#361625"],["#3f62f8","#724c60","#10183e"],["#1fac61","#cb19b4","#082b18"],["#7131a3","#17d9af","#7131a3"],["#442f7d","#9447ab","#19122f"],["#49dbcd","#3c4f43","#49dbcd"],["#9df154","#5c882b","#273c15"],["#6030a1","#beaae4","#6030a1"],["#2025e0","#1e840b","#101372"],["#69736b","#fe2a0a","#323733"],["#daed60","#a0d7e5","#6b742f"],["#e807c8","#b92152","#3a0232"],["#7f31c4","#5c0a63","#200c31"],["#29e8e6","#99ba40","#116261"],["#fd7fe4","#afdc0b","#a05090"],["#936c94","#257a95","#2b1f2b"],["#d61431","#5475e9","#630917"],["#4dd0ea","#fa595f","#1a4750"],["#1412f9","#27bddf","#1412f9"],["#a0a383","#ae2484","#282921"],["#fe4c28","#e993be","#9f2f19"],["#2febd0","#8a357b","#2febd0"],["#2147ad","#1f1010","#08122b"],["#e42b06","#91b681","#a82004"],["#b1aaac","#0b8d5e","#302e2f"],["#b5ff64","#560a6f","#b5ff64"],["#3bf3fa","#fcc554","#1d797d"],["#6fb8ed","#932a47","#6fb8ed"],["#7ec75f","#cbb93e","#426831"],["#fe3620","#2941f3","#3f0d08"],["#e5fbe4","#cda450","#50574f"],["#8e40ee","#461b2e","#23103b"],["#8e8d34","#d4a1be","#5c5c22"],["#c2c933","#76250f","#c2c933"],["#2a7cf8","#5a3935","#0a1f3e"],["#76c30c","#7777d3","#233904"],["#f84d08","#5d5c0b","#3e1302"],["#905939","#02188e","#24160e"],["#d68027","#bd0ecd","#35200a"],["#a32111","#40406c","#290804"],["#1ba4f4","#e9cd34","#1373ac"],["#c8e5e3","#cbcfc8","#637170"],["#c9ca19","#3502d0","#c9ca19"],["#cd06d1","#1fdef2","#be06c2"],["#227b62","#6ae302","#21765e"],["#531967","#384885","#15061a"],["#1aeb30","#346b19","#1aeb30"],["#4d7298","#33f323","#4d7298"],["#0d0e73","#240067","#03031d"],["#c0a122","#4c0ecf","#c0a122"],["#b1dd0a","#ba73a1","#334003"],["#3ee52d","#3b0f9d","#3ee52d"],["#ee962b","#f5f658","#ba7522"],["#9fab1b","#2bf913","#727a13"]]}')
    function check(name, cond) {
        console.log("TEST " + (cond ? "pass " : "FAIL ") + name);
        if (!cond)
            failures++;
    }
    function asVar(o: var): var {
        return o;
    }
    function near(a, b) {
        return Math.abs(a - b) < 1e-9;
    }
    function find(item, pred, out) {
        for (const c of item.children) {
            if (pred(c))
                out.push(c);
            shell.find(c, pred, out);
        }
        return out;
    }
    function named(win, name) {
        return shell.find(win.contentItem, c => c.objectName === name, []);
    }

    FileView {
        id: src
        path: Quickshell.shellPath("popups/ThemeEditor.qml")
        blockLoading: true
    }
    FileView {
        id: dst
        path: Quickshell.shellPath("popups/ThemeEditorTest.qml")
        blockWrites: true
    }
    FileView {
        id: saved
        path: Quickshell.statePath("custom-theme.json")
        blockLoading: true
        printErrors: false
    }

    Component.onCompleted: {
        let t = src.text();
        t = t.replace("PanelWindow {", "FloatingWindow {");
        t = t.replace(/\n    anchors \{[\s\S]*?\n    \}/, "");
        t = t.split("\n").filter(l => l.indexOf("exclusionMode") < 0 && l.indexOf("WlrLayershell") < 0).join("\n");
        t = t.replace("property int screenHeight: 0", "property int screenHeight: " + MenuStyle.windowHeight + "\n    implicitWidth: " + MenuStyle.windowWidth + "\n    implicitHeight: " + (MenuStyle.windowHeight + 2 * MenuStyle.windowWidth / 5));
        dst.setText(t);
        loader.setSource("popups/ThemeEditorTest.qml", { bar: null });
    }
    Loader {
        id: loader
    }

    TestCase { id: tc; name: "sim"; when: false }

    function typeInto(box, str) {
        box.input.forceActiveFocus();
        box.input.selectAll();
        tc.keyClick(Qt.Key_Delete);
        for (const ch of str)
            tc.keyClick(ch);
    }

    function fixtures() {
        const f = shell.fix;
        shell.check("fixture: 60 random contrast pairs match apply.py", f.pairs.every(p => shell.near(TC.contrast(p[0], p[1]), p[2])));
        shell.check("fixture: darker (HSV value / factor) matches Qt.darker as apply.py has it", f.darker.every(p => TC.darker(p[0], p[1]) === p[2]));
        shell.check("fixture: lift_highlight matches", f.lift.every(p => TC.liftHighlight(p[0], p[1]) === p[2]));
        shell.check("fixture: darken_to matches", f.darken.every(p => TC.darkenTo(p[0], p[1], 3.2) === p[2]));
        let allRows = true, allSel = true, allBlock = true, allSug = true;
        for (const name of Object.keys(f.palettes)) {
            const p = f.palettes[name];
            const rows = TC.checkRows(p.roles);
            const by = {};
            for (const r of rows)
                by[r.key] = r;
            allRows = allRows && shell.near(by["text-base"].value, p.textBase) && shell.near(by["text-highlight"].value, p.textHighlight)
                && shell.near(by["text-shadow"].value, p.textShadow) && shell.near(by["edge"].value, p.edge) && shell.near(by["urgent"].value, p.urgent);
            const sp = TC.selectPair(p.roles);
            allSel = allSel && sp.bar === p.select[0] && sp.text === p.select[1] && shell.near(sp.ratio, p.selectRatio);
            // apply.py refuses when the edge, the urgent or any text line is short of its minimum
            const refused = p.edge < 1.35 || p.urgent < 3.0 || p.textBase < 4.5 || p.textHighlight < 4.5 || p.textShadow < 4.5;
            allBlock = allBlock && (TC.blockers(p.roles).length > 0) === refused;
            allSug = allSug && TC.liftHighlight(p.roles.base, p.roles.highlight) === p.lift && TC.darkenTo(p.roles.urgent, p.roles.base, 3.2) === p.darkenUrgent;
        }
        shell.check("fixture: every palette's text / edge / urgent contrast lines match apply.py", allRows);
        shell.check("fixture: the selected-row pair (bar, text, ratio) matches apply.py's derive", allSel);
        shell.check("fixture: blockers() is non-empty exactly when apply.py would refuse", allBlock);
        shell.check("fixture: the suggestions (lift_highlight, darken_to) match", allSug);
        const names = Object.keys(f.palettes);
        shell.check("fixture: the broken palettes are refused and the shipped ones pass", ["lowedge", "lowurgent"].every(n => TC.blockers(f.palettes[n].roles).length > 0)
            && names.filter(n => ["lowedge", "lowurgent", "weakselect", "midgrey"].indexOf(n) < 0).every(n => TC.blockers(f.palettes[n].roles).length === 0));
        shell.check("fixture: a palette whose accent no text reads on is advisory only (select line fails, not blocking)", (() => {
            const r = TC.checkRows(f.palettes.weakselect.roles).find(x => x.key === "select");
            return r && !r.ok && !r.blocking;
        })());
        shell.check("pyRound: halves go to even like Python's round()", TC.pyRound(0.5) === 0 && TC.pyRound(1.5) === 2 && TC.pyRound(2.5) === 2 && TC.pyRound(2.4) === 2 && TC.pyRound(2.6) === 3);
        shell.check("normalise: accepts #RRGGBB and rrggbb, rejects the rest", TC.normalise(" #ABCDEF ") === "#abcdef" && TC.normalise("123456") === "#123456"
            && ["", "#12345", "#1234567", "#ggg000", "red", null, "#12 456"].every(s => TC.normalise(s) === ""));
        shell.check("toFile: all eight roles, normalised, plus defaultWallpaperPath", (() => {
            const o = TC.toFile(Object.assign({}, f.palettes.cherry.roles, { base: "#F4C9EF" }));
            return TC.ROLES.every(k => /^#[0-9a-f]{6}$/.test(o[k])) && o.base === "#f4c9ef" && o.defaultWallpaperPath === "";
        })());
        shell.check("startingPalette: a theme without urgent borrows the accent", TC.startingPalette({ base: "#ffffff", accent: "#123456", outline: "#000000" }).urgent === "#123456");
    }

    Timer {
        interval: 1200; running: true
        onTriggered: {
            shell.fixtures();
            const panel = shell.asVar(loader.item);
            shell.check("the scratch copy loaded", panel !== null);
            panel.closeCallback = function () { shell.closed++; };
            shell.check("no custom-theme.json exists before the first Save", saved.text() === "");
            Config.settings.currentTheme = "cherry";
            panel.openMenu();
            tc.wait(200);
            const rowOf = role => shell.named(panel, "role-" + role)[0];
            const hexOf = role => shell.find(rowOf(role), c => c.objectName === "hex", [])[0];
            const swatchOf = role => shell.find(rowOf(role), c => c.objectName === "swatch", [])[0];
            const pickOf = role => shell.find(rowOf(role), c => c.objectName === "pick", [])[0];
            const btn = name => shell.named(panel, name)[0];
            const status = () => shell.named(panel, "status")[0];
            const cherry = Config.themes.cherry;

            shell.check("eight role rows, each with a swatch, a hex field and a Pick button", TC.ROLES.every(r => rowOf(r) && swatchOf(r) && hexOf(r) && pickOf(r)));
            shell.check("the fields start with the current theme's colours", TC.ROLES.every(r => hexOf(r).text === cherry[r]));
            shell.check("the swatch shows the colour", String(swatchOf("accent").color) === String(Qt.color(cherry.accent)));
            shell.check("a passing palette: every contrast line passes, Apply and Save on", panel.rows.length === 6 && panel.rows.every(r => r.ok) && btn("apply").enabled && btn("save").enabled);
            shell.check("the contrast lines are the apply.py rules", panel.rows.map(r => r.key).join() === "edge,text-base,text-highlight,text-shadow,urgent,select");

            // a bad hex turns Save and Apply off
            shell.typeInto(hexOf("base"), "#12zz56");
            tc.wait(100);
            shell.check("a bad hex: Save and Apply are off and the status says which role", !btn("save").enabled && !btn("apply").enabled && status().text.indexOf("base is not a #rrggbb colour") >= 0);
            shell.check("a bad hex: the swatch is cleared", swatchOf("base").color.a === 0);

            // low contrast: Save stays on, Apply is off with the reason
            shell.typeInto(hexOf("base"), cherry.base);
            shell.typeInto(hexOf("text"), "#c0b0c0");
            tc.wait(100);
            shell.check("low text contrast: the line fails, Apply off with the reason, Save on", !panel.rows.find(r => r.key === "text-base").ok && !btn("apply").enabled && btn("save").enabled
                && status().text.indexOf("Apply is off: text on base is") === 0);
            tc.mouseClick(btn("apply"));
            tc.wait(100);
            shell.check("a click on the disabled Apply changes nothing", Config.settings.currentTheme === "cherry");

            // Pick fills the field
            panel.pickCommand = ["sh", "-c", "printf '#A1B2C3\\n'"];
            tc.mouseClick(pickOf("text"));
            tc.wait(600);
            shell.check("Pick: the field gets the picked colour, lower-case", hexOf("text").text === "#a1b2c3" && String(swatchOf("text").color) === String(Qt.color("#a1b2c3")));
            panel.pickCommand = ["sh", "-c", "printf 'nonsense\\n'"];
            tc.mouseClick(pickOf("accent"));
            tc.wait(600);
            shell.check("Pick: a cancelled / bad pick leaves the field alone", hexOf("accent").text === cherry.accent);

            // Save writes the state file
            shell.typeInto(hexOf("text"), "#321D32");
            tc.wait(100);
            shell.check("a good palette again: Apply on", btn("apply").enabled);
            tc.mouseClick(btn("save"));
            tc.wait(300);
            saved.reload();
            tc.wait(100);
            let p = null;
            try { p = JSON.parse(saved.text()); } catch (e) { p = null; }
            shell.check("Save: custom-theme.json has the eight roles (lower-case) and defaultWallpaperPath", p !== null && TC.ROLES.every(r => p[r] === TC.normalise(hexOf(r).text)) && p.text === "#321d32" && p.defaultWallpaperPath === "");
            shell.check("Save alone does not change the current theme", Config.settings.currentTheme === "cherry");

            // Apply
            shell.typeInto(hexOf("accent"), "#2a6f97");
            tc.wait(100);
            tc.mouseClick(btn("apply"));
            tc.wait(300);
            saved.reload();
            tc.wait(100);
            let q = null;
            try { q = JSON.parse(saved.text()); } catch (e) { q = null; }
            shell.check("Apply: saves the file and sets the current theme to custom", Config.settings.currentTheme === "custom" && q !== null && q.accent === "#2a6f97");
            shell.check("Apply: the shipped palettes are untouched", Config.themes.cherry.accent === cherry.accent);

            // Reset and closing
            Config.settings.currentTheme = "cherry";
            tc.wait(100);
            tc.mouseClick(btn("reset"));
            tc.wait(100);
            shell.check("Reset: back to the current theme's colours", TC.ROLES.every(r => hexOf(r).text === cherry[r]));
            tc.mouseClick(btn("close"));
            tc.wait(100);
            shell.check("Close closes", shell.closed === 1);
            hexOf("base").input.forceActiveFocus();
            tc.keyClick(Qt.Key_Escape);
            tc.wait(100);
            shell.check("Esc in a field closes", shell.closed === 2);

            console.log("TEST done failures=" + shell.failures);
            quitTimer.start();
        }
    }
    Timer { id: quitTimer; interval: 50; onTriggered: Qt.quit() }
}
