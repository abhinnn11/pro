pb1() {

    mkdir -p "$ttt32_dest" || return 1

    local log_file="$ttt32_dest/toptv.log"
    local cookiejar="$HOME/topvid.cookies"
    local under="__"

    local title_prefix="$1"
    local referer="$2"
    local origin="$3"

    [[ -z "$referer" ]] && referer="$ttt42_last_referer"
    [[ -z "$origin"  ]] && origin="$ttt42_last_origin"

    ttt42_last_referer="$referer"
    ttt42_last_origin="$origin"

    title_prefix=$(echo "$title_prefix" | tr -cd '[:alnum:] _-')
    [[ -z "$title_prefix" ]] && title_prefix="pb"

    echo "Using Referer: ${referer:-<none>}" | tee -a "$log_file"
    echo "Using Origin : ${origin:-<none>}" | tee -a "$log_file"

    while true; do
        printf "Enter M3U8 URL (q to quit): "
        IFS= read -r URL || break
        [[ "$URL" == "q" ]] && break
        [[ -z "$URL" ]] && continue

        ts=$(date '+%d%m-%H%M%S')

        jobname="${title_prefix}${under}${ts}"
        tmpfile="$ttt32_dest/${jobname}.ts"
        output_file="$ttt32_dest/${jobname}.mp4"
        joblog="$ttt32_dest/${jobname}.log"
        pidfile="$ttt32_dest/${jobname}.pid"

        echo "Starting detached recording: $jobname"

        ####################################################
        # DETACHED PROCESS LAUNCH (the real fix)
        ####################################################
        nohup setsid bash -c "
            $(declare -f pb1_worker)
            pb1_worker \"$URL\" \"$referer\" \"$origin\" \"$tmpfile\" \"$output_file\" \"$cookiejar\"
        " >> \"$joblog\" 2>&1 < /dev/null &

        echo $! > "$pidfile"

        echo "PID $(cat "$pidfile") running (log: $joblog)"
        echo "----------------------------------------" | tee -a "$log_file"

    done
}
