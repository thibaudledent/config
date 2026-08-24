#!/usr/bin/env bash
#
# repo-dump.sh - Dump a repository as plain text.
#
# Listing strategy:
#   - inside a Git work tree -> `git ls-files` (honours .gitignore for free)
#   - otherwise              -> `find` with pruning of the heavy directories
#   In both cases a second application-level filter is applied, because
#   .gitignore does not cover everything: committed .idea/, committed jars,
#   committed keystores, generated sources that are tracked on purpose...
#
# Safe with spaces, newlines and special characters in file names (NUL-delimited).
#

set -uo pipefail
shopt -s nocasematch   # so that .PNG / .JPG match the .png / .jpg patterns

# ---------------------------------------------------------------- defaults ---
MAX_LINES=200          # lines kept when truncation is enabled
MAX_SIZE_KB=512        # above this, the file is skipped (unless -t is used)
TRUNCATE=false
LIST_ONLY=false
NO_FILTER=false
VERBOSE=false
FORCE_FIND=false
OUTPUT=""
EXTRA_EXCLUDES=()

# ------------------------------------------------------------------- usage ---
show_usage() {
    cat <<'EOF'
Usage: repo-dump.sh [options] <path>

Options:
  -t            Truncate files longer than MAX_LINES (keeps head + tail)
  -l <n>        Maximum number of lines (default: 200)
  -s <kb>       Maximum file size in KB (default: 512)
  -o <file>     Write the dump to a file instead of stdout
  -x <glob>     Extra exclusion pattern (repeatable), e.g. -x '*/legacy/*'
  -n            Dry run: only list the files that would be included
  -a            Disable the exclusion rules (binaries are still skipped)
  -G            Force `find` even inside a Git repository
  -v            Print skipped files and the reason on stderr
  -h            Show this help

Examples:
  ./repo-dump.sh -t -l 300 -o dump.txt ~/projects/my-spring-app
  ./repo-dump.sh -n .                     # preview what would be included
EOF
    exit "${1:-1}"
}

log() { [ "$VERBOSE" = true ] && printf '%s\n' "$*" >&2; return 0; }

# ----------------------------------------------------------------- options ---
while getopts "tl:s:o:x:naGvh" opt; do
    case "$opt" in
        t) TRUNCATE=true ;;
        l) MAX_LINES=$OPTARG ;;
        s) MAX_SIZE_KB=$OPTARG ;;
        o) OUTPUT=$OPTARG ;;
        x) EXTRA_EXCLUDES+=("$OPTARG") ;;
        n) LIST_ONLY=true ;;
        a) NO_FILTER=true ;;
        G) FORCE_FIND=true ;;
        v) VERBOSE=true ;;
        h) show_usage 0 ;;
        *) show_usage ;;
    esac
done
shift $((OPTIND - 1))

[ $# -eq 1 ] || show_usage
case "$MAX_LINES$MAX_SIZE_KB" in *[!0-9]*) echo "Error: -l and -s expect an integer" >&2; exit 1 ;; esac

ROOT="${1%/}"; [ -n "$ROOT" ] && : || ROOT="/"
if [ ! -d "$ROOT" ]; then
    echo "Error: Path '$1' doesn't exist or is not a directory" >&2
    exit 1
fi

# ============================================================== filtering ====
# Returns 0 -> skip the file, 1 -> keep it
is_excluded() {
    local rel="$1" base p
    base="${rel##*/}"
    p="/$rel"

    # --- 1. Always kept (takes precedence over the generic rules below) ------
    case "$base" in
        readme|readme.*|license|licen[cs]e.*|notice|changelog.*|contributing.*|\
        pom.xml|build.gradle|build.gradle.kts|settings.gradle|settings.gradle.kts|\
        gradle.properties|libs.versions.toml|maven.config|jvm.config|\
        package.json|angular.json|nx.json|project.json|workspace.json|\
        tsconfig*.json|jsconfig*.json|karma.conf.js|jest.config.*|proxy.conf*.json|\
        .gitignore|.gitattributes|.editorconfig|.nvmrc|.dockerignore|.gitmodules|\
        dockerfile|dockerfile.*|*.dockerfile|docker-compose*.y*ml|compose*.y*ml|\
        jenkinsfile|jenkinsfile.*|*.jenkinsfile|makefile|taskfile.y*ml|\
        application*.yml|application*.yaml|application*.properties|\
        bootstrap*.yml|bootstrap*.yaml|messages*.properties|\
        logback*.xml|log4j2*.xml|persistence.xml|web.xml|\
        .env.example|.env.sample|.env.template|*.env.example)
            return 1 ;;
    esac
    # CI/CD pipelines, Helm/K8s values, DB migration scripts
    case "$p" in
        */.github/workflows/*|*/.github/*.md|*/.circleci/*|*/.gitlab-ci.yml|\
        */.travis.yml|*/azure-pipelines*.yml|*/helm/*/values*.y*ml|*/k8s/*.y*ml|\
        */src/main/resources/db/*|*/src/*/resources/*.sql)
            return 1 ;;
    esac

    [ "$NO_FILTER" = true ] && return 1

    # --- 2. Extra patterns supplied with -x ---------------------------------
    local pat
    for pat in ${EXTRA_EXCLUDES[@]+"${EXTRA_EXCLUDES[@]}"}; do
        # shellcheck disable=SC2254  # unquoted on purpose: $pat is a glob
        case "$rel" in $pat) return 0 ;; esac
    done

    # --- 3. Build output, tooling caches and IDE directories ----------------
    case "$p" in
        */.git/*|*/.svn/*|*/.hg/*|\
        */node_modules/*|*/bower_components/*|*/.pnpm-store/*|*/.yarn/*|*/jspm_packages/*|\
        */target/*|*/.target/*|*/build/*|*/out/*|*/bin/*|*/obj/*|\
        */.gradle/*|*/gradle/wrapper/*|*/.mvn/wrapper/*|\
        */dist/*|*/.angular/*|*/.nx/*|*/.next/*|*/.nuxt/*|*/.svelte-kit/*|*/.astro/*|\
        */coverage/*|*/.nyc_output/*|*/test-results/*|*/allure-results/*|\
        */playwright-report/*|*/cypress/videos/*|*/cypress/screenshots/*|*/reports/*|\
        */.idea/*|*/.vscode/*|*/.fleet/*|*/.settings/*|*/.metadata/*|*/.apt_generated/*|\
        */.cache/*|*/.parcel-cache/*|*/.turbo/*|*/.vite/*|*/.eslintcache/*|\
        */tmp/*|*/temp/*|*/logs/*|*/log/*|\
        */.scannerwork/*|*/.sonar/*|*/.terraform/*|*/__pycache__/*|*/.venv/*|*/venv/*|\
        */generated/*|*/generated-sources/*|*/generated-test-sources/*|*/.flattened*/*)
            return 0 ;;
    esac

    # --- 4. Binaries, archives, media and office documents ------------------
    case "$base" in
        *.class|*.jar|*.war|*.ear|*.so|*.dll|*.dylib|*.exe|*.o|*.a|*.obj|*.pyc|*.pyo|*.node|\
        *.zip|*.tar|*.tgz|*.gz|*.bz2|*.xz|*.7z|*.rar|*.jmod|\
        *.png|*.jpg|*.jpeg|*.gif|*.bmp|*.ico|*.icns|*.webp|*.tiff|*.psd|*.ai|*.svg|\
        *.mp3|*.mp4|*.wav|*.avi|*.mov|*.mkv|*.webm|\
        *.woff|*.woff2|*.ttf|*.otf|*.eot|\
        *.pdf|*.doc|*.docx|*.xls|*.xlsx|*.ppt|*.pptx|\
        *.db|*.sqlite|*.sqlite3|*.mdb|*.iso|*.dmg|*.bin|*.dat)
            return 0 ;;
    esac

    # --- 5. Secrets, keys and credentials -----------------------------------
    case "$base" in
        *.jks|*.keystore|*.truststore|*.p12|*.pfx|*.pem|*.key|*.crt|*.cer|*.der|*.csr|\
        *.asc|*.gpg|*.kdbx|*.ppk|\
        .env|.env.*|*.env|id_rsa*|id_dsa*|id_ecdsa*|id_ed25519*|\
        .netrc|.npmrc|.yarnrc|.pypirc|.htpasswd|credentials|\
        secrets.y*ml|*secret*.y*ml|*credentials*.json|service-account*.json)
            return 0 ;;
    esac

    # --- 6. Logs, temp files, IDE artifacts, wrappers, minified bundles -----
    case "$base" in
        *.log|*.log.*|nohup.out|hs_err_pid*|replay_pid*|*.hprof|*.dump|\
        *.iml|*.ipr|*.iws|.classpath|.project|.factorypath|*.launch|\
        .ds_store|thumbs.db|desktop.ini|\
        *.swp|*.swo|*'~'|*.orig|*.rej|*.bak|*.tmp|*.pid|\
        mvnw|mvnw.cmd|gradlew|gradlew.bat|maven-wrapper.properties|gradle-wrapper.properties|\
        *.min.js|*.min.css|*.map|*.bundle.js|*.chunk.js|*.tsbuildinfo|\
        .flattened-pom.xml|dependency-reduced-pom.xml|*.lst|*.factorypath)
            return 0 ;;
    esac

    return 1
}

# Lock files: worth listing (which package manager is used) but not worth reading
is_stub() {
    case "${1##*/}" in
        package-lock.json|npm-shrinkwrap.json|yarn.lock|pnpm-lock.yaml|\
        composer.lock|Gemfile.lock|poetry.lock|Cargo.lock) return 0 ;;
    esac
    return 1
}

# ================================================================ listing ====
if [ "$FORCE_FIND" = false ] && command -v git >/dev/null 2>&1 &&
   git -C "$ROOT" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    USE_GIT=true
    SOURCE="git ls-files --cached --others --exclude-standard (honours .gitignore)"
else
    USE_GIT=false
    SOURCE="find + pruning (not a Git work tree)"
fi

list_candidates() {
    if [ "$USE_GIT" = true ]; then
        git -C "$ROOT" ls-files -z --cached --others --exclude-standard
    else
        # Prune the heavy directories up front so find never descends into them
        find "$ROOT" \
            \( -type d \( -name .git -o -name node_modules -o -name target \
               -o -name build -o -name dist -o -name out -o -name .angular \
               -o -name .gradle -o -name .idea -o -name .vscode -o -name .mvn \
               -o -name coverage -o -name .cache -o -name .venv \) -prune \) -o \
            -type f -print0 |
        while IFS= read -r -d '' f; do
            printf '%s\0' "${f#"$ROOT"/}"   # emit paths relative to ROOT, like git does
        done
    fi
}

# ============================================================== selection ====
KEPT=$(mktemp) || exit 1
trap 'rm -f "$KEPT"' EXIT

n_total=0; n_kept=0; n_rule=0; n_binary=0; n_size=0; n_secret=0

# Process substitution (not a pipe) keeps the loop in the current shell,
# so the counters below survive the loop.
while IFS= read -r -d '' rel; do
    [ -n "$rel" ] || continue
    n_total=$((n_total + 1))
    abs="$ROOT/$rel"

    [ -f "$abs" ] || continue                       # ls-files also reports deleted files
    [ -n "$OUTPUT" ] && [ "$abs" -ef "$OUTPUT" ] 2>/dev/null && continue   # never dump ourselves
    if [ ! -r "$abs" ]; then
        echo "Cannot read file: $rel" >&2
        continue
    fi

    if is_excluded "$rel"; then
        n_rule=$((n_rule + 1)); log "SKIP  [rule]    $rel"; continue
    fi

    # Binary safety net (grep -I); an empty file counts as text
    if [ -s "$abs" ] && ! LC_ALL=C grep -Iq . "$abs" 2>/dev/null; then
        n_binary=$((n_binary + 1)); log "SKIP  [binary]  $rel"; continue
    fi

    # Plaintext private key -> never dump the content, whatever the extension
    if LC_ALL=C grep -qE -- '-----BEGIN [A-Z ]*PRIVATE KEY-----' "$abs" 2>/dev/null; then
        n_secret=$((n_secret + 1)); log "SKIP  [secret]  $rel"; continue
    fi

    size_kb=$(( ($(wc -c < "$abs") + 1023) / 1024 ))
    if [ "$size_kb" -gt "$MAX_SIZE_KB" ] && [ "$TRUNCATE" = false ]; then
        n_size=$((n_size + 1)); log "SKIP  [size]    $rel (${size_kb}KB)"; continue
    fi

    n_kept=$((n_kept + 1))
    printf '%s\0' "$rel" >> "$KEPT"
done < <(list_candidates)

# ================================================================= output ====
if [ -n "$OUTPUT" ]; then
    exec > "$OUTPUT" || { echo "Error: cannot write to '$OUTPUT'" >&2; exit 1; }
fi

branch=$(git -C "$ROOT" rev-parse --abbrev-ref HEAD 2>/dev/null) || branch="n/a"
commit=$(git -C "$ROOT" rev-parse --short HEAD 2>/dev/null)     || commit="n/a"

cat <<EOF
##### REPOSITORY DUMP #####
root      : $ROOT
generated : $(date '+%Y-%m-%d %H:%M:%S')
git       : branch=$branch commit=$commit
listing   : $SOURCE
files     : $n_kept included / $n_total scanned
excluded  : rules=$n_rule binary=$n_binary size=$n_size secret=$n_secret
truncate  : $TRUNCATE (max ${MAX_LINES} lines, max ${MAX_SIZE_KB} KB)

##### FILE INDEX #####
EOF
tr '\0' '\n' < "$KEPT"

[ "$LIST_ONLY" = true ] && exit 0

display_file() {
    local rel="$1" abs="$ROOT/$1" lines half
    lines=$(awk 'END{print NR+0}' "$abs")   # counts an unterminated last line too

    if is_stub "$rel"; then
        printf '\n===== FILE: %s (lock file, %s lines — content omitted) =====\n' "$rel" "$lines"
        printf '===== END: %s =====\n' "$rel"
        return
    fi

    if [ "$TRUNCATE" = true ] && [ "$lines" -gt "$MAX_LINES" ]; then
        half=$((MAX_LINES / 2))
        printf '\n===== FILE: %s (truncated, %s lines total) =====\n' "$rel" "$lines"
        head -n "$half" "$abs"
        printf '\n[... %s lines omitted ...]\n\n' "$((lines - 2 * half))"
        tail -n "$half" "$abs"
    else
        printf '\n===== FILE: %s (%s lines) =====\n' "$rel" "$lines"
        cat "$abs"
    fi
    printf '\n===== END: %s =====\n' "$rel"
}

printf '\n##### FILE CONTENTS #####\n'
while IFS= read -r -d '' rel; do
    display_file "$rel"
done < "$KEPT"