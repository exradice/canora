# Canora

**Karaoke for your AWTRIX clock.** Canora shows the lyrics of the song that is playing, in time
with the music: the words light up as they are sung, and the next words are always visible below.

*Canora* comes from the Latin *canorus*, "melodious, singing".

<!-- Demo: docs/canora.gif - recorded with a public-domain song, see "Legal" below -->

[![Import blueprint](https://my.home-assistant.io/badges/blueprint_import.svg)](https://my.home-assistant.io/redirect/blueprint_import/?blueprint_url=https%3A%2F%2Fgithub.com%2Fexradice%2Fcanora%2Fblob%2Fmain%2Fblueprints%2Fautomation%2Fcanora.yaml)
[![Buy me a coffee](https://img.shields.io/badge/Buy%20me%20a%20coffee-support-FFDD00?logo=buymeacoffee&logoColor=black)](https://buymeacoffee.com/exradice)

## How it works

```
Speaker (e.g. Google Cast)  ──>  Home Assistant  ──MQTT──>  AWTRIX clock  ──HTTPS──>  lrclib.net
                                 track, position            Canora script  <── synced lyrics
```

- **Home Assistant** only sends what is playing and where in the song you are, through a
  blueprint, to an MQTT topic.
- **The clock** does everything else: it fetches the synced lyrics from
  [LRCLIB](https://lrclib.net), counts the position forward between updates, wraps the lines,
  highlights the words and holds the display while a song with lyrics is playing.
- When the music stops, is paused, or a song has no lyrics, the clock goes back to its normal app
  rotation. Press a button to move on, and the clock leaves Canora alone until the next song.

## Requirements

- **An AWTRIX NG clock with a 52×16 display** (Ulanzi TC002), connected to your MQTT broker.
- **Home Assistant** with the **MQTT integration**, using the same broker as the clock.
- **A media player that reports the playback position** (`media_position` and
  `media_position_updated_at`). Google Cast speakers do this, including when Spotify plays on
  them. Check yours under *Developer tools → States* while music is playing.
- **Internet access** for the clock, to reach lrclib.net.

## Setup

1. **Install the script.** Get *Canora* from the AWTRIX Hub, or create a script named `Canora` in
   the clock's web interface (*Scripts* tab) and paste [`canora.be`](canora.be).
2. **Optional: create an on/off switch.** In Home Assistant: *Settings → Devices & services →
   Helpers → Create helper → Toggle*, for example named `Karaoke`. Expose it to your voice
   assistant to say "turn on karaoke".
3. **Import the blueprint** with the button above, then *Create automation*: pick your speakers,
   the switch (if you made one), and keep the MQTT topic unless you changed it in step 4.
4. **Check the topic.** The script listens on `awtrix/data/canora` by default (*Apps* tab → gear
   icon of Canora). If you change it, use the same topic in the blueprint.
5. **Only if you use a fixed app order:** add `Canora` to it (for example in your
   `<prefix>/cmd/apps/order` message). A script that is not in the rotation cannot take over the
   display, and Canora then never shows up.

Play a song. A second or two after it starts, the clock switches to the lyrics.

## Settings

In the clock's web interface, *Apps* tab, gear icon of Canora:

| Setting | Default | What it does |
|---|---|---|
| MQTT topic | `awtrix/data/canora` | Where the blueprint publishes |
| Offset | 0 ms | Positive values show the lyrics earlier, to make up for speaker delay |
| Not yet sung / Sung | grey / amber | Colors of the words before and after they are sung |
| Title during intros and solos | dark grey | Color of the song title in instrumental parts |

## Troubleshooting

- **Nothing happens.** Look at the clock's log (web interface). Every lyrics lookup writes a line
  such as `Canora: Song title step 1/2: ok, 42 lines`.
  - `status 404` or `no synced lyrics` on every step: LRCLIB has no synced lyrics for this song.
    You can add them yourself at [lrclib.net](https://lrclib.net) and help everyone.
  - `status 503`: LRCLIB often answers the first request for a song this way. Canora tries again
    after 2 and 4 seconds.
- **No log line at all:** the clock receives no data. Check that the blueprint automation runs
  (its traces) and that blueprint and script use the same topic. Is the switch on?
- **Lyrics run ahead or behind:** adjust the *Offset*. Words inside a line are timed by an
  estimate, because LRCLIB only has a timestamp per line.
- **The clock shows Canora briefly but then moves on:** Canora is missing from your fixed app
  order (setup step 5).

## MQTT interface

You do not need Home Assistant: anything that publishes this JSON (retained) to the topic works,
for example Node-RED.

```json
{
  "enabled": true,
  "state": "playing",
  "id": "spotify:track:6tNQ70jh4OwmPGpYy6R2o9",
  "artist": "Artist",
  "title": "Song title",
  "album": "Album",
  "duration": 180000,
  "position": 4598,
  "position_ts": 1793087239732
}
```

| Field | Meaning |
|---|---|
| `enabled` | Canora on or off |
| `state` | Player state; Canora only runs while it is `playing` |
| `id` | Any id that changes with the song; empty means artist + title |
| `artist`, `title`, `album` | Used to look up the lyrics (`album` is currently not sent to LRCLIB) |
| `duration` | Song length in ms |
| `position` | Playback position in ms at the moment `position_ts` |
| `position_ts` | When `position` was measured, ms since 1970 (UTC). Publish again on pause, seek and track change |

The clock and the publisher need correct time (NTP); the clock counts forward from `position_ts`.

## Privacy

The script sends the **artist, title and duration** of every song you play to lrclib.net to look
up the lyrics. Nothing else leaves your network, and nothing is stored on the clock.

## Legal

- Canora contains **no lyrics**. They are fetched live from [LRCLIB](https://lrclib.net), a free
  community database, and only shown on your clock. Lyrics are protected by copyright; use Canora
  for private enjoyment.
- If you share photos or videos of Canora, prefer songs in the public domain.
- Spotify, Google Cast, AWTRIX and Home Assistant are names of their respective owners. Canora is
  an independent project and not affiliated with any of them.

## Support

Canora is free and stays free. If it brings karaoke to your kitchen and you want to say thanks,
you can [buy me a coffee](https://buymeacoffee.com/exradice). Bug reports and ideas are
welcome as GitHub issues.

## License

[MIT](LICENSE) © 2026 exradice
