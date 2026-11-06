#!/bin/sh
# Screen recording and replay buffer: a thin wrapper over gpu-screen-recorder (gsr).
#   record.sh start <region|screen|window> <mic 0|1> <dir> <target> [class]
#       region / window: target is a rectangle WxH+X+Y (global pixels). Window mode records the window's
#                        rectangle as a region (a guess: the window may move or be covered while recording).
#       screen:          target is the output name (DP-1). Audio: default_output, plus default_input when mic is 1.
#       Writes <dir>/<name>.mp4 (name from shot-name.sh <class>, class defaults to "recording"; -2, -3 when taken)
#       and prints the path. Refuses when already recording (exit 1). State: $XDG_RUNTIME_DIR/qs-record.json.
#   record.sh stop     SIGINT (gsr finalises the file), waits up to 10 s, prints the file path.
#   record.sh status   prints {"recording":bool,"file":"..","since":epoch}
#   record.sh replay-start <dir> [seconds] [output]   gsr -w <output|screen> -r <seconds, default 30> -c mp4 -o <dir>
#   record.sh replay-save    SIGUSR1 to the replay process. UNVERIFIED until live: gsr documents SIGUSR1 as
#                            "save the replay"; check a real clip appears and has the expected length.
#   record.sh replay-stop    SIGINT
#   record.sh replay-status  prints {"replaying":bool,"dir":"..","since":epoch}
#   record.sh replay-last <dir>   prints the newest *.mp4 file name in <dir> (this one folder only)
# A leading ~ in <dir> is expanded to $HOME. Arguments are never spliced into script text.
# Exit codes: 0 ok, 1 refused or failed, 2 gpu-screen-recorder is not installed.

export LC_ALL=C
here=$(dirname "$0")
rt=${XDG_RUNTIME_DIR:-/tmp}
rec_state=$rt/qs-record.json
rep_state=$rt/qs-replay.json
gsr=gpu-screen-recorder

die() { printf '%s\n' "$1" >&2; exit "${2:-1}"; }
need_gsr() { command -v "$gsr" >/dev/null 2>&1 || die "gpu-screen-recorder is not installed" 2; }

expand_dir() {
    case $1 in
        "~") printf '%s\n' "$HOME" ;;
        "~/"*) printf '%s\n' "$HOME/${1#"~/"}" ;;
        *) printf '%s\n' "$1" ;;
    esac
}

# JSON string body: escape backslash and double quote
jesc() { sed 's/\\/\\\\/g; s/"/\\"/g'; }
junesc() { sed 's/\\"/"/g; s/\\\\/\\/g'; }

# state helpers: $1 = state file. Layout: {"pid":N,"path":"..","since":N}
st_pid() { sed -n 's/^{"pid":\([0-9][0-9]*\),.*/\1/p' "$1" 2>/dev/null | head -n 1; }
st_since() { sed -n 's/.*,"since":\([0-9][0-9]*\)}$/\1/p' "$1" 2>/dev/null | head -n 1; }
st_path_raw() { sed -n 's/^{"pid":[0-9]*,"path":"\(.*\)","since":[0-9]*}$/\1/p' "$1" 2>/dev/null | head -n 1; }
alive() { # pid is a live gpu-screen-recorder (or a wrapper script of that name)
    [ -n "$1" ] && kill -0 "$1" 2>/dev/null && tr '\0' ' ' < "/proc/$1/cmdline" 2>/dev/null | grep -q "$gsr"
}
write_state() { # file pid path since
    p=$(printf %s "$3" | jesc)
    printf '{"pid":%s,"path":"%s","since":%s}\n' "$2" "$p" "$4" > "$1.tmp" && mv "$1.tmp" "$1"
}
wait_gone() { # pid, up to 10 s
    i=0
    while [ $i -lt 50 ] && kill -0 "$1" 2>/dev/null; do sleep 0.2; i=$((i + 1)); done
}

cmd=$1
[ $# -ge 1 ] && shift
case $cmd in
start)
    [ $# -ge 4 ] || die "usage: record.sh start <region|screen|window> <mic 0|1> <dir> <target> [class]"
    mode=$1; mic=$2; dir=$(expand_dir "$3"); target=$4; cls=${5:-recording}
    need_gsr
    pid=$(st_pid "$rec_state")
    if alive "$pid"; then die "already recording"; fi
    case $mic in 0 | 1) ;; *) die "mic must be 0 or 1" ;; esac
    case $mode in
        region | window)
            printf %s "$target" | grep -Eq '^[0-9]+x[0-9]+\+[0-9]+\+[0-9]+$' || die "bad region (want WxH+X+Y)"
            set -- -w region -region "$target" ;;
        screen)
            printf %s "$target" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._:-]*$' || die "bad output name"
            set -- -w "$target" ;;
        *) die "mode must be region, screen or window" ;;
    esac
    mkdir -p -- "$dir" || die "cannot create $dir"
    name=$(sh "$here/shot-name.sh" "$cls" 2>/dev/null)
    [ -n "$name" ] || name=recording_$(date +%Y-%m-%d_%H-%M)
    f=$dir/$name.mp4; n=2
    while [ -e "$f" ]; do f=$dir/$name-$n.mp4; n=$((n + 1)); done
    if [ "$mic" = 1 ]; then set -- "$@" -a default_output -a default_input; else set -- "$@" -a default_output; fi
    nohup "$gsr" "$@" -f 60 -c mp4 -o "$f" >/dev/null 2>&1 </dev/null &
    pid=$!
    sleep 0.3
    kill -0 "$pid" 2>/dev/null || die "gpu-screen-recorder exited right away"
    write_state "$rec_state" "$pid" "$f" "$(date +%s)"
    printf '%s\n' "$f"
    ;;
stop)
    pid=$(st_pid "$rec_state")
    alive "$pid" || { rm -f "$rec_state"; die "not recording"; }
    f=$(st_path_raw "$rec_state" | junesc)
    kill -INT "$pid" 2>/dev/null
    wait_gone "$pid"
    rm -f "$rec_state"
    printf '%s\n' "$f"
    ;;
status)
    pid=$(st_pid "$rec_state")
    if alive "$pid"; then
        printf '{"recording":true,"file":"%s","since":%s}\n' "$(st_path_raw "$rec_state")" "$(st_since "$rec_state")"
    else
        [ -e "$rec_state" ] && rm -f "$rec_state"
        printf '{"recording":false,"file":"","since":0}\n'
    fi
    ;;
replay-start)
    [ $# -ge 1 ] || die "usage: record.sh replay-start <dir> [seconds] [output]"
    dir=$(expand_dir "$1"); secs=${2:-30}; out=${3:-screen}
    need_gsr
    pid=$(st_pid "$rep_state")
    if alive "$pid"; then die "replay already running"; fi
    printf %s "$secs" | grep -Eq '^[0-9]+$' && [ "$secs" -ge 5 ] || die "seconds must be a number, 5 or more"
    printf %s "$out" | grep -Eq '^[A-Za-z0-9][A-Za-z0-9._:-]*$' || die "bad output name"
    mkdir -p -- "$dir" || die "cannot create $dir"
    nohup "$gsr" -w "$out" -r "$secs" -c mp4 -f 60 -a default_output -o "$dir" >/dev/null 2>&1 </dev/null &
    pid=$!
    sleep 0.3
    kill -0 "$pid" 2>/dev/null || die "gpu-screen-recorder exited right away"
    write_state "$rep_state" "$pid" "$dir" "$(date +%s)"
    printf '%s\n' "$dir"
    ;;
replay-save)
    pid=$(st_pid "$rep_state")
    alive "$pid" || { rm -f "$rep_state"; die "replay is not running"; }
    kill -USR1 "$pid" || die "could not signal gpu-screen-recorder"
    ;;
replay-stop)
    pid=$(st_pid "$rep_state")
    alive "$pid" || { rm -f "$rep_state"; die "replay is not running"; }
    kill -INT "$pid" 2>/dev/null
    wait_gone "$pid"
    rm -f "$rep_state"
    ;;
replay-status)
    pid=$(st_pid "$rep_state")
    if alive "$pid"; then
        printf '{"replaying":true,"dir":"%s","since":%s}\n' "$(st_path_raw "$rep_state")" "$(st_since "$rep_state")"
    else
        [ -e "$rep_state" ] && rm -f "$rep_state"
        printf '{"replaying":false,"dir":"","since":0}\n'
    fi
    ;;
replay-last)
    [ $# -ge 1 ] || die "usage: record.sh replay-last <dir>"
    dir=$(expand_dir "$1")
    [ -d "$dir" ] || exit 0
    # newest *.mp4 by mtime; this folder only
    best=
    for f in "$dir"/*.mp4; do
        [ -f "$f" ] || continue
        if [ -z "$best" ] || [ "$f" -nt "$best" ]; then best=$f; fi
    done
    [ -n "$best" ] && basename -- "$best"
    exit 0
    ;;
*)
    die "usage: record.sh start|stop|status|replay-start|replay-save|replay-stop|replay-status|replay-last"
    ;;
esac
