# Consume Mode for Lyrion Music Server

MPD-style consume for LMS 8.x / 9.x. A track leaves the play queue once it has
finished playing or has been skipped with Next. Jumping straight to another
entry in the queue leaves the track you jumped away from alone.

Enabled per player, in the web UI.

## Install (Docker / TrueNAS SCALE)

The `cache/InstalledPlugins` directory is managed by LMS itself and is rebuilt
from the repository metadata, so anything dropped there by hand disappears on
restart. Put the plugin in the server's own `Plugins` directory instead, and
bind-mount it from the host so it survives container recreation.

1. On the TrueNAS host, create a dataset or directory, e.g.
   `/mnt/tank/apps/lms-plugins/ConsumeMode`, and copy the contents of this
   folder into it (`Plugin.pm`, `install.xml`, `strings.txt`, `Settings.pm`,
   `PlayerSettings.pm`, `HTML/`).

2. Fix ownership so the container can read it:

       chown -R 568:568 /mnt/tank/apps/lms-plugins
       chmod -R u=rwX,go=rX /mnt/tank/apps/lms-plugins

3. Confirm the server root inside the container:

       docker ps --format '{{.Names}}' | grep -i lyrion
       docker exec <container> ls -d /lms/Plugins

4. Apps -> lyrion-music-server -> Edit -> Storage -> Add additional storage:
   - Type: Host Path
   - Host Path: `/mnt/tank/apps/lms-plugins/ConsumeMode`
   - Mount Path: `/lms/Plugins/ConsumeMode`
   - Read only: no

   Mount the single plugin sub-directory, never `/lms/Plugins` itself, or you
   will hide the plugins bundled in the image.

5. Save. The app redeploys. Then in LMS: Settings -> Plugins, confirm
   "Consume Mode" is listed and enabled, and restart the server if prompted.

## Use

Settings -> Player -> pick the player -> Consume Mode -> tick the box.

Two global options live under Settings -> Advanced -> Consume Mode:
consume on Previous (off by default) and consume the final track of the
queue (on by default).

CLI / JSON-RPC:

    <playerid> consumemode 1
    <playerid> consumemode 0
    <playerid> consumemode ?     -> _consumemode:0|1

Omitting the value toggles.

## Troubleshooting

Settings -> Advanced -> Logging, set `plugin.consumemode` to INFO, then watch
`config/logs/server.log`. Every removal is logged with the queue index and the
reason for the transition.

## Known limits

- Consume plus Repeat is contradictory. Repeat-one is detected and never
  consumes; repeat-all will empty the queue one track per lap.
- If the same file appears twice in the queue and positions have shifted, the
  first matching entry is removed.
- Synced groups are handled at the master player; set the preference on the
  master.
