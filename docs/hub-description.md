<!-- Text for the AWTRIX Hub listing. Short descriptions by allowed length:
~100 chars: Karaoke for your clock: the lyrics of the song that is playing, in time with the music.
~150 chars: Karaoke for your clock: the lyrics of the song on your speakers light up word by word, in time with the music. Synced lyrics from LRCLIB.
~250 chars: Karaoke for your clock. Canora shows the lyrics of the song that is playing on your speakers, in time with the music: words light up as they are sung, the next words wait below. Home Assistant sends the track via MQTT, lyrics come from LRCLIB.
-->

**Sing along in the kitchen.** Canora (Latin *canorus*, "melodious") turns your clock into a
karaoke display: the lyrics of the song that is playing, in time with the music.

### What you see

- **Top row:** the words being sung right now. They light up from grey to amber as the song goes on.
- **Bottom row:** the next words, so you can read ahead. When the top row is done, everything moves up.
- **Intros and solos:** the song title, and a countdown of three dots before the singing starts again.

Canora **only takes over the display while a song with lyrics is playing**. On pause, stop, or a
song without lyrics, your normal app rotation continues. Press a button to hand the display back
until the next song.

### What you need

- **Home Assistant** with MQTT, and a speaker that reports its playback position (Google Cast
  speakers do, also with Spotify).
- The free **blueprint** that sends the track to the clock. Setup guide, blueprint import button
  and troubleshooting: **https://github.com/exradice/canora**

### Settings

- **MQTT topic:** where the blueprint publishes, `awtrix/data/canora` by default.
- **Offset:** positive values show the lyrics earlier, to make up for speaker delay.
- **Colors** for sung and not yet sung words and for the title.

### Good to know

- Lyrics come live from [LRCLIB](https://lrclib.net), a free community database. Missing a song?
  Add it there. The script sends artist, title and duration to lrclib.net; nothing is stored.
- Words inside a line are timed by an estimate, because LRCLIB has one timestamp per line.
- Made for the 52×16 display (Ulanzi TC002).
