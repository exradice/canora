# Changelog

## 1.0.0 - 2026-11-01

First public release.

- Synced lyrics from LRCLIB in three steps: exact title, title without additions such as
  " - Remastered", then a search for the closest duration.
- Retries when LRCLIB answers 503 (common for the first request of a song) or the network fails.
- Lines are wrapped at word boundaries; the row being sung is on top, the next words below, and
  everything moves up when a row is done.
- Words light up at about eight glyphs per second, never past the start of the next line.
- Instrumental parts show the song title, the last three seconds a countdown of dots.
- Holds the app rotation while a song with lyrics plays; a button press hands the display back
  until the next song.
- Home Assistant blueprint for any number of speakers and an optional on/off switch.
