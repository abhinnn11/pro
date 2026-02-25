pb1_worker() {

    URL="$1"
    referer="$2"
    origin="$3"
    tmpfile="$4"
    output_file="$5"
    cookiejar="$6"

    ####################################################
    # Activate CDN session
    ####################################################
    curl -s -L \
        -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" \
        -c "$cookiejar" \
        -b "$cookiejar" \
        -e "$referer" \
        "$referer" >/dev/null 2>&1

    sleep 2

    ####################################################
    # Resolve master playlist
    ####################################################
    if [[ "$URL" == *master.m3u8* ]]; then
        variant=$(curl -s \
            -H "Referer: $referer" \
            -H "Origin: $origin" \
            -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" \
            "$URL" | grep -Eo 'https://[^"]+index[^"]+\.m3u8[^"]*' | head -1)

        [[ -n "$variant" ]] && URL="$variant"
    fi

    ####################################################
    # Record stream
    ####################################################
    /opt/ffmpeg8/bin/ffmpeg \
        -nostdin \
        -loglevel warning \
        -user_agent "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" \
        -headers "Referer: $referer\r\nOrigin: $origin\r\n" \
        -rw_timeout 20000000 \
        -timeout 20000000 \
        -reconnect 1 \
        -reconnect_streamed 1 \
        -reconnect_at_eof 1 \
        -reconnect_on_network_error 1 \
        -reconnect_delay_max 5 \
        -protocol_whitelist "file,http,https,tcp,tls,crypto" \
        -allowed_extensions ALL \
        -fflags +genpts+igndts+discardcorrupt \
        -use_wallclock_as_timestamps 1 \
        -i "$URL" \
        -map 0:v -map 0:a? \
        -c copy \
        "$tmpfile"

    [[ ! -s "$tmpfile" ]] && exit

    ####################################################
    # Repair timestamps (critical for MP4)
    ####################################################
    fixed="${tmpfile%.ts}_fixed.ts"

    /opt/ffmpeg8/bin/ffmpeg \
        -fflags +genpts+igndts+discardcorrupt \
        -err_detect ignore_err \
        -i "$tmpfile" \
        -c copy \
        -avoid_negative_ts make_zero \
        "$fixed"

    ####################################################
    # Final MP4
    ####################################################
    /opt/ffmpeg8/bin/ffmpeg \
        -loglevel warning \
        -i "$fixed" \
        -c copy \
        -movflags +faststart \
        "$output_file"

    rm -f "$tmpfile" "$fixed"
}
