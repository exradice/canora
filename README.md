# Canora

**Karaoke for your AWTRIX clock.** Canora shows the lyrics of the song that is playing, in time
with the music: the words light up as they are sung, and the next words are always visible below.

*Canora* comes from the Latin *canorus*, "melodious, singing".

<!-- Demo: docs/canora.gif - recorded with a public-domain song, see "Legal" below -->

[![Import blueprint](https://my.home-assistant.io/badges/blueprint_import.svg)](https://my.home-assistant.io/redirect/blueprint_import/?blueprint_url=https%3A%2F%2Fgithub.com%2Fexradice%2Fcanora%2Fblob%2Fmain%2Fblueprints%2Fautomation%2Fcanora.yaml)
[![Support on Ko-fi](https://img.shields.io/badge/Ko--fi-support-FF5E5B?logo=kofi&logoColor=white)](https://ko-fi.com/exradice)

## How it works

```
Any media player  ──>  Home Assistant  ──MQTT──>  AWTRIX clock  ──HTTPS──>  lrclib.net
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

- **An AWTRIX NG clock with a 52×16 display** (Ulanzi TC002), connected to your MQTT broker,
  with *Home Assistant discovery* switched on in its MQTT settings.
- **Home Assistant** with the **MQTT integration**, using the same broker as the clock.
- **A media player in Home Assistant** that shows artist, title and duration while music plays.
  See [Which players work](#which-players-work).
- **Internet access** for the clock, to reach lrclib.net.

## Which players work

Canora does not depend on a music service or a speaker brand. It reads the standard attributes
every Home Assistant media player has. How well it works depends on what your player reports.
Check under *Developer tools → States* while music is playing:

| Your player shows | Result |
|---|---|
| `media_artist`, `media_title`, `media_duration` **and** `media_position` with `media_position_updated_at` | **Exact timing**, including pause, seek and skip |
| artist, title and duration, but no `media_position` | **Approximate mode:** Canora counts from the moment the song starts. Fine if you listen through; after a pause or a seek the lyrics are off until the next song |
| no duration (live radio, most web streams) | No lyrics: without a duration there is no reliable match |

Home Assistant asks integrations to report the position whenever it jumps (new song, pause,
seek), and Canora counts forward in between, exactly like the media card in your dashboard.

Good to know:

- **Tested** with Google Cast speakers playing Spotify. Other integrations that report the
  position should work the same way, for example Sonos or Music Assistant. Tell us in an issue
  what works for you.
- **Music Assistant** is a good way to make many services and speakers look the same to Home
  Assistant: Spotify, Tidal, Qobuz, Deezer, YouTube Music, local files, on Cast, Sonos, AirPlay,
  Squeezebox and DLNA speakers. Pick its player entities in the blueprint.
- **The Spotify integration** follows your account rather than a speaker. It helps when your
  speakers are not in Home Assistant, but it polls Spotify only every 30 seconds or so, so a
  seek can take a moment to show up.
- **Speaker groups:** add the group and its members; the first one that is playing is used.
- **Music only** (blueprint option, on by default) ignores videos, TV shows and podcasts.

## Setup

### How Home Assistant and the clock find each other

Every AWTRIX clock has an **MQTT prefix**: the first part of all its topics, set in the clock's
MQTT settings (for example `awtrix` or `kitchen`). Canora uses the topic

```
<prefix>/data/canora        for example  kitchen/data/canora
```

Both sides build this topic from the same prefix, so you never type a topic yourself:

- **On the clock** you enter the prefix once in Canora's settings. A script cannot read the
  clock's own prefix, which is why this one field is needed.
- **In Home Assistant** you pick the clock's **MQTT prefix** sensor in the blueprint, and the
  blueprint reads the prefix from it. AWTRIX creates this sensor when *Home Assistant discovery*
  is on in the clock's MQTT settings; it is called something like
  `sensor.<clock name>_mqtt_prefix` and shows the prefix as its state.

The topic sits under the clock's own prefix on purpose: if your broker only lets the clock read
its own topics (an ACL such as `topic read kitchen/#`), Canora still works without changes.

### Steps

1. **Install the script.** Get *Canora* from the AWTRIX Hub, or create a script named `Canora` in
   the clock's web interface (*Scripts* tab) and paste [`canora.be`](canora.be).
2. **Enter the prefix.** *Apps* tab → gear icon of Canora → **MQTT prefix of this clock**: the
   same value as in the clock's MQTT settings. Not sure? In Home Assistant, the clock's *MQTT
   prefix* sensor shows it. The clock's log then says `Canora: listening on <prefix>/data/canora`.
3. **Optional: create an on/off switch.** In Home Assistant: *Settings → Devices & services →
   Helpers → Create helper → Toggle*, for example named `Karaoke`. Expose it to your voice
   assistant to say "turn on karaoke".
4. **Import the blueprint** with the button above (or *Settings → Automations & scenes →
   Blueprints → Import blueprint* and paste
   `https://github.com/exradice/canora/blob/main/blueprints/automation/canora.yaml`). Then
   *Create automation* and pick:
   - **Clocks:** the *MQTT prefix* sensor of each clock running Canora
   - **Speakers:** the media players to follow
   - **On/off switch:** the toggle from step 3, if you made one
5. **Check the app order** (only if you set a fixed one). AWTRIX shows only the apps listed in
   `order`, and a script that is not in the rotation cannot take over the display. Add `Canora`
   to your list, keeping all your other apps, for example over MQTT:

   ```
   topic:   <prefix>/cmd/apps/order
   payload: {"order":["Time","Canora","Date"],"disabled":["Battery"]}
   ```

   `disabled` is required and lists the apps that are switched off. If you publish your order as
   a retained message (for example from an automation), add Canora there, otherwise the old list
   comes back on the next reconnect. Without a fixed order, new scripts join the rotation by
   themselves and you can skip this step.

Play a song. A second or two after it starts, the clock switches to the lyrics.

## Settings

In the clock's web interface, *Apps* tab, gear icon of Canora:

| Setting | Default | What it does |
|---|---|---|
| MQTT prefix of this clock | *(empty, required)* | The clock's MQTT prefix; Canora listens on `<prefix>/data/canora` |
| Custom topic | *(empty)* | Only if you publish somewhere else, for example without Home Assistant |
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
- **`Canora: set the MQTT prefix of this clock`** in the log: setup step 2 is missing.
- **No lookup line at all:** the clock receives no data.
  - Does the log say `listening on kitchen/data/canora` with *your* prefix?
  - Does the blueprint automation run, and does its trace show a publish to the same topic?
  - Is the on/off switch on?
  - If you use a custom topic: can the clock's MQTT user read it?
- **`no duration, skipped (live stream?)`:** the player reports no song length, see
  [Which players work](#which-players-work).
- **Lyrics run ahead or behind:** adjust the *Offset*. Words inside a line are timed by an
  estimate, because LRCLIB only has a timestamp per line.
- **The lyrics load (log says `ok`) but the clock never switches to them:** Canora is missing
  from your fixed app order (setup step 5).

## MQTT interface

You do not need Home Assistant: anything that publishes this JSON (retained) to
`<prefix>/data/canora` (or your custom topic) works, for example Node-RED.

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
| `position_ts` | When `position` was measured, ms since 1970 (UTC). Publish again on pause, seek and track change. `0` or missing: Canora counts from when the song arrives (approximate mode) |

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
you can [buy me a coffee on Ko-fi](https://ko-fi.com/exradice). Bug reports and ideas are
welcome as GitHub issues.

## License

[MIT](LICENSE) © 2026 exradice

---

<p align="center">Made with ❤️ in the EU 🇪🇺</p>
