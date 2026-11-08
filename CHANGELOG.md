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
- Home Assistant blueprint for any media player integration, any number of speakers and clocks,
  and an optional on/off switch. It finds each clock's topic `<prefix>/data/canora` from the
  clock's MQTT prefix sensor, so no topic is typed by hand. It only publishes when something Canora uses changes, and can ignore
  videos, TV shows and podcasts ("Music only").
- Approximate mode for players without a playback position; songs without a duration (live
  streams) are skipped instead of matched wrongly.
