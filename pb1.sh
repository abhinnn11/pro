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

    # sanitize filename
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
        tmpfile="$ttt32_dest/${title_prefix}${under}${ts}.ts"
        output_file="$ttt32_dest/${title_prefix}${under}${ts}.mp4"

        echo "Processing: $URL" | tee -a "$log_file"

        ####################################################
        # STEP 1 — Activate session (important for CDN edge)
        ####################################################
        echo "[*] Activating session..."

        curl -s -L \
            -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" \
            -c "$cookiejar" \
            -b "$cookiejar" \
            -e "$referer" \
            "$referer" >/dev/null 2>&1

        sleep 2

        ####################################################
        # STEP 2 — Resolve MASTER playlist
        ####################################################
        if [[ "$URL" == *master.m3u8* ]]; then
            echo "[*] Resolving master playlist..."

            variant=$(curl -s \
                -H "Referer: $referer" \
                -H "Origin: $origin" \
                -A "Mozilla/5.0 (Windows NT 10.0; Win64; x64)" \
                "$URL" | grep -Eo 'https://[^"]+index[^"]+\.m3u8[^"]*' | head -1)

            if [[ -z "$variant" ]]; then
                echo "Could not find variant playlist"
                continue
            fi

            URL="$variant"
            echo "[*] Using variant:"
            echo "$URL"
        fi

        ####################################################
        # STEP 3 — Record stream
        ####################################################
        echo "[*] Recording..."

        if ! /opt/ffmpeg8/bin/ffmpeg \
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
            -fflags +genpts \
            -i "$URL" \
            -map 0:v -map 0:a? \
            -c copy \
            "$tmpfile"
        then
            echo "Recording failed (stream likely expired)"
            rm -f "$tmpfile"
            continue
        fi

        ####################################################
        # STEP 4 — Validate recording
        ####################################################
        if [[ ! -s "$tmpfile" ]]; then
            echo "Recording produced empty file"
            rm -f "$tmpfile"
            continue
        fi

        ####################################################
        # STEP 5 — Remux to MP4
        ####################################################
        echo "[*] Finalizing MP4..."

        /opt/ffmpeg8/bin/ffmpeg \
            -loglevel warning \
            -i "$tmpfile" \
            -c copy \
            -movflags +faststart \
            "$output_file"

        rm -f "$tmpfile"

        echo "Saved: $output_file" | tee -a "$log_file"
        echo "----------------------------------------" | tee -a "$log_file"

    done
}
