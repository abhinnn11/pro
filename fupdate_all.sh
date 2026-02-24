fupdate_all() {

    list="update.txt"
    dst="$HOME/.bashrc"

    [ ! -f "$list" ] && { echo "update.txt not found"; return 1; }

    ########################################
    # ONE GLOBAL BACKUP
    ########################################
    ts="$(date +%Y%m%d_%H%M%S)"
    epoch="$(date +%s)"
    tarfile="$HOME/.bashrc.tar.$epoch"

    tmpcopy="/tmp/.bashrc.$ts"
    cp "$dst" "$tmpcopy"
    tar -cf "$tarfile" -C /tmp "$(basename "$tmpcopy")"
    rm -f "$tmpcopy"

    echo "Global backup created: $tarfile"
    echo

    ########################################
    # BATCH UPDATE MODE
    ########################################
    export FUPDATE_BATCH=1

    while IFS= read -r file || [ -n "$file" ]; do

        file="$(echo "$file" | xargs)"
        [[ -z "$file" || "$file" == \#* ]] && continue

        if [ ! -f "$file" ]; then
            echo "Skipping $file (not found)"
            continue
        fi

        fn=$(basename "$file" .sh)
        echo "Updating $fn from $file"
        fupdate "$fn" "$file"
        echo

    done < "$list"

    unset FUPDATE_BATCH

    echo "All listed functions updated."
    echo "Reload shell: source ~/.bashrc"
}


