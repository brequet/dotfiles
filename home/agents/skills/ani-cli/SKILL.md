---
name: ani-cli
description: Download anime with ani-cli from the cloned upstream repo. Use when the user asks to download anime episodes or seasons (for example "S2E7" or "to the end"), mentions ani-cli, or wants episodes saved under ~/Downloads/ani-cli.
---

# ani-cli downloads

`ani-cli` scrapes hianime.at. The nixpkgs package is stale (5.0 still points at
the dead anidb.app provider), so never run `nixpkgs#ani-cli`. Run the clone at
`~/Projects/ani-cli` instead.

## Pull first

Update the clone before every session:

```sh
git -C ~/Projects/ani-cli pull --ff-only
~/Projects/ani-cli/ani-cli -V   # expect 5.1.x or newer
```

If the clone is missing:

```sh
git clone https://github.com/pystardust/ani-cli.git ~/Projects/ani-cli
```

Do not update with `ani-cli -U`; the git clone is the source of truth.

## Dependencies

`yt-dlp` and `ffmpeg` are not installed globally. Run ani-cli through a nix
shell so both are on PATH (`yt-dlp` handles most HLS streams, `ffmpeg` is needed
when an episode carries a separate audio track):

```sh
nix shell nixpkgs#yt-dlp nixpkgs#ffmpeg -c ~/Projects/ani-cli/ani-cli ...
```

## Find the series and season

Hianime lists each season as its own search result, so the series and the season
are selected together with `-S <n>`. Compute the numbered list first; the numbers
match the `-S` index:

```sh
UA="Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36"
curl -sL -A "$UA" "https://hianime.at/search?keyword=clevatess" |
  sed '/id="main-sidebar"/,$d' | tr '\n' ' ' |
  sed 's|<div class="film-detail">|\n<div class="film-detail">|g' |
  sed -nE 's|.*<h3 class="film-name">[[:space:]]*<a href="[^"]*/([^"/]*)"[[:space:]]*title="([^"]*)".*|\1\t\2|p' |
  nl -w2 -s'. '
```

The indices shift as the site changes, so recompute them for every download.

For an ongoing show the episode list can include unreleased episodes. Check the
last one before using "to the end":

```sh
ANI_CLI_PLAYER=debug nix shell nixpkgs#yt-dlp nixpkgs#ffmpeg -c \
  ~/Projects/ani-cli/ani-cli -S 2 -e 13 "clevatess"
```

`debug` prints the links without playing. `No sources found` means it is not out
yet; use the previous episode.

## Download into a dedicated folder

One folder per series, and per season, under `~/Downloads/ani-cli`. Never
download into the Downloads root:

```sh
series="Clevatess Season 2"
dir="$HOME/Downloads/ani-cli/$series"
mkdir -p "$dir"

ANI_CLI_DOWNLOAD_DIR="$dir" \
  nix shell nixpkgs#yt-dlp nixpkgs#ffmpeg -c ~/Projects/ani-cli/ani-cli \
  -S 2 -e 11-13 -d "clevatess"
```

- Use the title as shown on the site, including `Season N`, so seasons do not
  mix in one folder.
- `-e START-END` is an inclusive range; `-e START--1` runs to the last listed
  episode.
- Files are `<series> Episode N.mp4` with an English `.vtt` beside them.
- Check what already exists and start after it instead of re-downloading.

## Progress and hangs

ani-cli calls `yt-dlp` with `--fragment-retries infinite`. A dead source can
retry 403s forever without making progress. Always log and cap the run:

```sh
timeout 900 nix shell nixpkgs#yt-dlp nixpkgs#ffmpeg -c \
  ~/Projects/ani-cli/ani-cli -S 2 -e 11-13 -d "clevatess" \
  >/tmp/ani-cli-clevatess.log 2>&1
echo "exit=$?"
grep -ac "403 Forbidden" /tmp/ani-cli-clevatess.log
```

If the log shows repeated 403s, stop and retry at a lower quality (`-q 720`)
rather than waiting. A silent command is not progress: check the file size and
the last log line.

## Parallel runs

Different series can run at the same time. Give each its own download folder and
history dir so they do not race on `~/.local/state/ani-cli/ani-hsts`:

```sh
ANI_CLI_DOWNLOAD_DIR="$dir" \
ANI_CLI_HIST_DIR="/tmp/ani-cli-hist-$series" ...
```

Start each in the background, `wait`, then report the per-series exit code and
elapsed time.

## Verify

```sh
ffprobe -v error -show_entries format=duration:stream=codec_type,width,height -of json "$file"
grep -c -- '-->' "$file.vtt"
ffmpeg -v error -i "$file" -t 15 -f null -
```

Expect roughly 23-24 minutes per TV episode, 1920x1080, AAC audio, a non-empty
`.vtt`, and no decode errors.

## Cleanup

After a failed or interrupted download, remove its partials before retrying:

```sh
rm -f "$dir"/*.part* "$dir"/*.ytdl
```
