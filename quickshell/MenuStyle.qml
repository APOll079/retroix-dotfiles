pragma Singleton
import QtQuick
import Quickshell

// Shared sizes and fonts for every popup menu. Colors always come from Config.colors.
Singleton {
    id: root

    // Fonts (loaded here so menus don't depend on ids declared in shell.qml)
    readonly property string bodyFont: monaco.name
    readonly property string titleFont: charcoal.name
    readonly property string iconFont: icons.name
    readonly property int fontSize: 12
    // Icon glyphs come in two sizes only: 16 in rows, menus and on the bar, 20 on big buttons
    // (the Spotify drawer's 30px buttons). Pictures (cover / app images, tray icons, the 32px
    // placeholder on a cover without art) are not glyphs and have their own sizes.
    readonly property int iconSize: 16
    readonly property int iconSizeLarge: 20

    // The three menu widths
    readonly property int widthSmall: 240
    readonly property int widthMedium: 320
    readonly property int widthLarge: 480

    // Spacing scale: the only paddings and gaps in the shell are these five steps. Every *Pad / *Gap /
    // *Inset / *Spacing below is one of them (scripts/check.py warns about any other). Sizes of things
    // (rows 22, title bar 20, buttons) are not spacing and have their own names.
    readonly property int space2: 2
    readonly property int space4: 4
    readonly property int space6: 6
    readonly property int space8: 8
    readonly property int space12: 12
    readonly property int pad: space6
    readonly property int gap: space4
    readonly property int rowHeight: 22
    readonly property int titleHeight: 20

    readonly property int barHeight: 32
    readonly property int barButtonHeight: 22
    // The tray well (BarWell): one sunken box at the bar's right holding status items, padding inside it
    readonly property int barWellPad: space2
    readonly property int barLabelButtonWidth: 56
    // Etched divider (menus and bar sections) and the bar-section gripper
    readonly property int separatorThickness: 6
    readonly property int gripperWidth: 4
    // Slider knob (raised bevel block, track height)
    readonly property int sliderKnobWidth: 10
    // Slider groove (Win95 trackbar: a thin sunken channel, no fill)
    readonly property int sliderGroove: 4
    // Win95 scrollbar: width of the bar, its arrow buttons and the smallest thumb; arrow auto-repeat (ms)
    readonly property int scrollBarWidth: 16
    readonly property int scrollRepeatDelay: 300
    readonly property int scrollRepeatRate: 50
    // Right-click / dropdown menu: never narrower than this (it grows to its longest label)
    readonly property int contextMenuMinWidth: 140
    // Win95 tabs (TabPage): tab strip height (the selected tab is 1px taller and joins the page), padding inside the page
    readonly property int tabHeight: 28
    readonly property int tabPagePad: space4
    // Status bar at the bottom of a window (StatusBar): one 12px line
    readonly property int statusHeight: 18
    readonly property int barStatusFontSize: 11
    // Lyrics / now-playing line in the bar centre: Monaco 12 like the rest of the bar (B4; it was
    // Liberation Sans 14, the only sans on the bar; Monaco looked wavy at 14, it hints cleanly at 12).
    // Liberation Sans stays bundled in fonts/ (OFL) but nothing uses it now.
    readonly property string barStrongFont: bodyFont
    readonly property int barStrongFontSize: fontSize

    // Component sizes
    // Window sizes: M for every big window (launcher and its tabs, Games, Wallpapers, Services, cheat sheet,
    // Task Manager's default), L for the one that shows a big grid (screenshot History; clamp it to the
    // screen). No S: nothing needs one.
    readonly property int windowWidth: 760
    readonly property int windowHeight: 560
    readonly property int windowLargeWidth: 1120
    readonly property int windowLargeHeight: 760
    // Launcher window: one size for every tab (Apps, Games, Clipboard) and the standalone Games menu
    readonly property int launcherWidth: windowWidth
    readonly property int launcherHeight: windowHeight
    // Clipboard picker: share of the width taken by the preview pane (left of the list)
    readonly property real clipPreviewFraction: 0.45
    // Screenshots: history label column, grid columns and thumbnail decode width, the pause
    // between hiding the overlay chrome and taking the shot (ms), the overlay dim, and the
    // smallest drag that counts as a region (smaller = click, ignored)
    readonly property int shotGridColumns: 4
    readonly property int shotThumbWidth: 320
    // History panel size as a fraction of the screen
    readonly property real shotHistoryWidthFraction: 0.6
    readonly property real shotHistoryHeightFraction: 0.7
    // History quick filter buttons (Today / Week / All)
    readonly property int shotFilterButtonWidth: 56
    // Games grid: columns, title strip under each cover, cover decode width, and the label
    // column of the Add game form
    readonly property int gamesGridColumns: 7
    readonly property int gamesTitleHeight: 32
    readonly property int gamesCoverDecodeWidth: 200
    readonly property int gamesLabelWidth: 72
    // Games filter chips: width, and how many days count as "Recent"
    readonly property int gamesChipWidth: 64
    readonly property int gamesRecentDays: 30
    // Wallpaper browser: grid columns (16:9 thumbnails) and thumbnail decode width
    readonly property int wallGridColumns: 4
    readonly property int wallThumbDecodeWidth: 320
    readonly property int shotSettle: 250
    readonly property real shotDimOpacity: 0.45
    readonly property int shotMinSize: 4
    // Screen-share picker (sharepicker.qml): backdrop dim, grid columns, label strip under each card
    readonly property real shareDimOpacity: 0.35
    readonly property int shareGridColumns: 3
    readonly property int shareLabelHeight: 36
    readonly property int shareIconSize: 32
    // Spotify panel (left edge): width, cover size, recent grid columns, player poll interval
    readonly property int spotifyWidth: 400
    readonly property int spotifyCoverSize: 96
    readonly property int spotifyGridColumns: 4
    readonly property int spotifyGridColumnsLibrary: 3   // library grid tiles per row
    readonly property int spotifyRowHeight: 34      // library / song rows (two lines of 12 px text)
    readonly property int spotifyInset: space2           // padding inside the drawer's sunken fields and tiles
    readonly property int spotifyTileIcon: 32       // placeholder icon on a cover without art
    readonly property int spotifyClickGuard: 350    // ms after opening something during which clicks are ignored
    readonly property int spotifyColumnGap: space4       // between the drawer's rows (the rest of the menus use pad)
    readonly property int spotifyCompactRow: 24     // the drawer's seek / transport / volume / search rows and its icon buttons
    readonly property int spotifyTabHeight: tabHeight
    readonly property int spotifyChipHeight: 20     // chips: smaller than tabs and buttons
    readonly property int spotifyStatusHeight: statusHeight
    readonly property int spotifyPagePad: space4         // inside the tab page's bevel
    readonly property int spotifyRecentCount: 3    // the newest, one row, square tiles of about 120 px (collapsible)
    readonly property int spotifyLyricsCover: 32    // the cover in the compact lyrics header
    readonly property int spotifyNoteMs: 3000       // how long a short message stays on the status bar
    readonly property int spotifyWheelStep: 5       // the mouse wheel on the volume row: percent per notch
    readonly property int spotifySeekStepMs: 5000   // the mouse wheel on the seek bar: ms per notch
    readonly property int spotifyThumb: 28          // the thumbnail in a list row (fills the 34 px row)
    readonly property int spotifyListHeader: 30     // the list header: name, count, Play, Shuffle
    readonly property int spotifyFlickGuard: 150    // ms: a click right after a scroll or flick only stops it
    readonly property int spotifyChipUnderline: 2   // the active chip's accent underline
    readonly property int spotifyButton: 30         // every button in the drawer: square icon buttons are this wide and tall; text buttons and the transport columns this tall
    readonly property int spotifyButtonGlyph: iconSizeLarge    // the icon on those buttons
    readonly property real spotifyIdleOpacity: 0.5  // the volume slider while nothing plays here (it shows the last known level)
    readonly property int spotifyTitleSize: 16      // the now-playing title when it fits on one line (Monaco hints cleanly at 16)
    readonly property int spotifyEmptyBigChars: 28  // empty / error messages up to this long use the 16 px size, longer ones 12
    readonly property int spotifyTipMs: 600        // ms the pointer rests on a control before its tooltip shows (the status bar shows it at once)
    readonly property int spotifyRestoreMs: 1500    // ms the remembered cursor / scroll position is put back while the list settles after opening
    readonly property int spotifyLyricsHold: 3000   // ms the lyrics stay where you scrolled before they follow the song again
    readonly property int spotifyPollMs: 2000
    readonly property int spotifyTickMs: 1000
    readonly property int spotifyVolumeStep: 300    // ms between Spotify volume calls while dragging (another device)
    readonly property int spotifyVolumeHold: 3000   // ms the slider keeps your value before trusting the source again
    readonly property color likedColor: "#1db954"    // liked heart: Spotify green (the one colour not from the palette, on request; bevelLight below is the second, a derived tint)
    readonly property int lyricsFastTick: 100
    readonly property int lyricsFontSize: 16      // Monaco hints cleanly at 12 and 16
    readonly property int lyricsLineGap: space8        // between two lyric lines; a wrapped line keeps its normal spacing, so it reads as one
    readonly property real lyricsAnchor: 0.38     // where the current lyric sits (0 top, 0.5 middle)
    readonly property int cheatKeyWidth: 140     // key chip column in the cheat sheet
    readonly property int searchHeight: 32
    readonly property int searchFontSize: 14
    readonly property int avatarSize: 150
    readonly property int cardWidth: 84
    readonly property int cardHeight: 68
    readonly property int swatchWidth: 10
    readonly property int swatchHeight: 34
    readonly property int calendarCell: 28
    readonly property int notificationIconSize: 32
    readonly property int notificationMargin: 12
    readonly property int barMediaMaxWidth: 420
    // The centre text gets the room left between the bar's sides (never overlaps); below this the
    // sysmon button drops its GPU part to make room
    readonly property int barMediaMinWidth: 200
    // Bar centre keeps the last Spotify track this long after it goes empty (track changes)
    readonly property int barHideDelay: 2000
    // How often the lyric line follows Spotify's position
    readonly property int taskInterval: 2000        // Task Manager refresh (ms)
    readonly property int taskHistory: 60           // samples per Performance graph (2 min at 2 s)
    readonly property int taskColumnWidth: 80       // CPU / Memory / Procs columns
    // Task Manager window (a real window): default size (Hyprland keeps the last one, persistent_size)
    // and the smallest it can be made, where the 2 x 2 Performance graphs and the five action
    // buttons still fit without clipping
    readonly property int taskWindowWidth: windowWidth
    readonly property int taskWindowHeight: windowHeight
    readonly property int taskMinWidth: 600
    readonly property int taskMinHeight: 420
    readonly property int sysMonInterval: 2000      // CPU / RAM / temperature read interval
    readonly property int lyricsTick: 250
    // Motion: two durations and one easing, no bounce. fast = hover highlights and fades, normal =
    // menus opening (fade + slide), the lyrics scroll, a cover crossfade. 0 turns an animation off, and
    // settings.ui.reduceMotion makes every duration 0 (the two slow ones below too).
    readonly property bool reduceMotion: Config.settings.ui.reduceMotion
    readonly property int animFast: reduceMotion ? 0 : 60
    readonly property int animNormal: reduceMotion ? 0 : 120
    readonly property int animEasing: Easing.OutCubic
    readonly property int animSlide: 4          // px a menu slides in from
    // Idle dim layer strength (outline colour over the screen)
    readonly property real idleDimOpacity: 0.5
    // Idle dim fades in over this long (eased, no bounce); 0 = appears at once. It leaves instantly on input.
    readonly property int idleDimFade: reduceMotion ? 0 : 1000
    // Weather refresh (wttr.in), ms
    readonly property int weatherRefresh: 1800000
    readonly property int weatherRetry: 60000           // after a failed fetch
    // Phone tab: device list re-read while it is open, ms
    readonly property int phoneRefresh: 5000
    // Side panel: full height, from the bar down to this far above the screen's bottom edge
    readonly property int sidePanelBottomMargin: 32
    // Notification entries (history and toasts): title size (Monaco hints cleanly at 16), body lines
    // before the rest folds away (history: the chevron unfolds it, up to notificationExpandedLines;
    // toasts show notificationToastBodyLines)
    readonly property int notificationTitleSize: 16
    readonly property int notificationBodyLines: 3
    readonly property int notificationExpandedLines: 40
    readonly property int notificationToastBodyLines: 6
    // History: the well the entries sit in, a shade below the theme's shadow (so the cards and their
    // muted title bars stand up out of it in every theme), and each entry's frame (1px outline + 2px
    // raised bevel)
    readonly property color notificationWell: Qt.darker(Config.colors.shadow, 1.25)
    readonly property int notificationCardInset: space4
    // Home tab: the Applications volume list scrolls after this height (about five apps)
    readonly property int audioAppsMaxHeight: 240
    // Home tab: EQ preset buttons per row before they wrap
    readonly property int eqPresetColumns: 4
    // Bluetooth menu: rows per list before it scrolls, and how long a scan runs (ms)
    readonly property int bluetoothListRows: 5
    readonly property int bluetoothScanTime: 30000
    // Bluetooth pairing prompt: the code to type / compare is Monaco 16 in a sunken box this high
    readonly property int bluetoothCodeSize: 16
    readonly property int bluetoothCodeHeight: 32
    // ... and a device name in the prompt title is cut to this many characters (the longest sentence, "Type this passkey on", still fits)
    readonly property int bluetoothNameChars: 14
    readonly property int notificationTimeout: 10000
    readonly property int notificationFade: reduceMotion ? 0 : 400   // slow on purpose, like the idle dim
    readonly property int osdMargin: 90
    readonly property int notificationMaxVisible: 4
    // Right-aligned value next to a meter ("100%", "MUTE")
    readonly property int valueLabelWidth: 40
    // Title bar: gap around the title, gap between title icon and text
    readonly property int titleSpacing: space8
    readonly property int titleIconGap: space6
    readonly property int traySpacing: space8
    // Unread marker on the bell: size and offset from the button's top-left
    readonly property int unreadDotSize: 6
    readonly property int unreadDotX: 4
    readonly property int unreadDotY: 3

    // Bevel tones. The light edge IS the theme's highlight: theme/apply.py refuses a palette whose
    // highlight is less than 1.35:1 lighter than base, so it always reads as an edge.
    readonly property color bevelLight: Config.colors.highlight
    // The inner light ring of a raised bevel: halfway from the face to the highlight (Win95's #dfdfdf
    // between #c0c0c0 and white), so the two rings read as two steps
    readonly property color bevelInnerLight: Qt.tint(Config.colors.base, Qt.alpha(Config.colors.highlight, 0.5))
    // Glyph of a bar button that is switched on (caffeine): the accent darkened, so it reads on the base face (accent itself is 2-4:1 there)
    readonly property color barOnGlyph: Qt.darker(selectBar, 1.8)
    readonly property color bevelDark: Qt.darker(Config.colors.shadow, 1.7)
    // Hover / selected bar: a hard dark accent, with base-coloured text on top
    // Selection / hover bar, title bars and meter fills. Use the theme's own accent (cherry:
    // the original linux-retroism #c950bb) with whichever palette text colour (base, text or
    // outline) reads best on it. Only if none reaches 4.5:1 is the accent darkened until base
    // text does. selectText is the matching text colour.
    readonly property var selectPair: {
        const acc = Config.colors.accent;
        let best = null, bestC = 0;
        for (const c of [Config.colors.base, Config.colors.text, Config.colors.outline]) {
            const k = root.contrast(c, acc);
            if (k > bestC) { bestC = k; best = c; }
        }
        if (bestC >= 4.5)
            return { bar: acc, text: best };
        let f = 1.0;
        while (f < 2.0 && root.contrast(Config.colors.base, Qt.darker(acc, f)) < 4.5)
            f += 0.05;
        return { bar: Qt.darker(acc, f), text: Config.colors.base };
    }
    readonly property color selectBar: selectPair.bar
    readonly property color selectText: selectPair.text
    function luminance(c) {
        // Config.colors holds strings ("#e3b9d6"); Qt.darker(x, 1) turns either form into a color
        const col = Qt.darker(c, 1.0);
        const ch = v => v <= 0.03928 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4);
        return 0.2126 * ch(col.r) + 0.7152 * ch(col.g) + 0.0722 * ch(col.b);
    }
    function contrast(a, b) {
        const la = luminance(a), lb = luminance(b);
        return (Math.max(la, lb) + 0.05) / (Math.min(la, lb) + 0.05);
    }

    // Frame geometry: 1px outline + 2px bevel + 1px gap, then the title bar, then a 1px outlined
    // content box (the double frame), then padding inside that box.
    readonly property int frameInset: space4
    readonly property int boxGap: space2
    readonly property int boxPadH: space4
    readonly property int boxPadV: space4
    readonly property int chromeTop: frameInset + titleHeight + boxGap + 1 + boxPadV
    readonly property int chromeBottom: frameInset + 1 + boxPadV
    readonly property int chromeHeight: chromeTop + chromeBottom

    FontLoader {
        id: monaco
        source: Qt.resolvedUrl("fonts/Monaco.ttf")
    }
    FontLoader {
        id: charcoal
        source: Qt.resolvedUrl("fonts/Charcoal.ttf")
    }
    FontLoader {
        id: liberationSans
        source: Qt.resolvedUrl("fonts/LiberationSans-Regular.ttf")
    }
    FontLoader {
        id: icons
        source: Qt.resolvedUrl("fonts/MaterialSymbolsSharp_Filled_20pt-Bold.ttf")
    }
}
