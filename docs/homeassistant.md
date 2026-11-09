# Home Assistant review, automations, and dashboards

This document describes the Home Assistant changes added to this repo and the
reasoning behind them. The live HA instance is expected at
`/mnt/drive/HomeAssistant/config` (inside the container: `/config`).

## Current setup at a glance

- Home Assistant 2026.11.0, host networking, privileged container.
- SONOFF Zigbee via a ZBBridge-P: 13 TRVZB radiator valves and 5 SNZB-02D
  temperature/humidity sensors.
- 2 SONOFF S60ZBTPF energy-monitoring plugs (living room and upstairs).
- Xiaomi Robot Vacuum X20+ via Xiaomi Home.
- Tapo C520WS camera via Tapo: Cameras Control.
- Met.no weather, sun, backup, and the standard default integrations.
- No lights, no motion sensors, no door/window contacts, and no presence
  trackers yet.
- Before this change: `automations.yaml` was `[]`, scripts/scenes were empty,
  and there was no custom dashboard or Energy configuration.

## What was wrong / what to fix

### 1. The Overview was the auto-generated dashboard

There was no `lovelace` dashboard configuration and no `ui-lovelace.yaml`, so
Home Assistant showed the auto-generated **Overview**. That page lists every
enabled entity, including dozens of diagnostic/config entities per TRV
(battery, RSSI, connection, target temperatures, valve opening, work state,
temperature correction, etc.). That is why it felt cluttered.

Two dashboards are now provided:

- **Home** — day-to-day overview: house mode, indoor average, heating,
  main-room thermostats, camera, vacuum, backup status.
- **Energy** — the two plugs with live power, today/month/year totals, cost,
  daily/monthly charts, and per-plug details.

### 2. No automations

The heating was entirely manual. The TRVs were set to individual targets
(including 24 °C in the bathroom and 26 °C in the left bedroom), with no
schedule, no away mode, and no low-battery/offline alerts.

### 3. No presence or window/door sensors

`person.potterhome` has no device trackers, so HA cannot tell whether anyone is
home. There are also no window/door contacts, so heating cannot be paused when
a window is open. The TRVs do have an internal "window detection" switch; a
script is included to enable it, but real contact sensors are more reliable.

### 4. Cloud-dependent SONOFF integration

The SONOFF integration is configured with an eWeLink account rather than local
mode. This means heating control depends on the vendor cloud and internet. The
startup log also shows repeated `sonoff: Not adding entity ... 'NoneType'
object is not iterable` errors. Consider migrating the integration to local
mode and/or updating it. The Sonoff cloud credentials are stored in
`.storage`, which is correctly excluded from git.

### 5. No backups configured

`backup_last_successful_automatic_backup` is `unknown`. The repo snapshot is
useful for config disaster recovery, but it is not a full backup. Set up
automatic backups in **Settings -> System -> Backups** (ideally to a NAS or
another disk).

### 6. Housekeeping

- Many devices have no area assigned. Assign every TRV, plug, sensor, vacuum,
  and camera to an area/floor. This improves voice control, area cards, and
  the auto-generated pages.
- Some entities are stale/unavailable:
  - `sensor.livingroom_farside_temperature_sensor_*` is unavailable.
  - `sensor.miaomiaoc_de_blt_4_1c9juknnkgg00_t2_*` is unknown.
  - `sensor.livingroom_plug_repeater_sonoff_a480158071_power` flaps between
    `0.0` and `unavailable`; check Zigbee routing/placement.
- The vacuum reported fault code `68`; check the Xiaomi app.
- The Tapo log shows repeated "Already downloading a recording" errors; check
  the background recording download / SD sync.
- Rename the plugs to what they actually power. "Livingroom Plug Repeater" is
  not meaningful on a dashboard.
- Watchtower auto-updates Home Assistant along with the other containers.
  Consider excluding HA from Watchtower so custom integrations are not broken
  by surprise updates.

## Automations added

| Automation | What it does | Why |
|---|---|---|
| Heating: apply house mode | Calls the matching heating script when `input_select.house_mode` changes | One source of truth for Home/Away/Sleep/Vacation |
| Heating: morning comfort | Sleep -> Home at 06:30 (if schedule enabled) | Warm house before waking up |
| Heating: night mode | Home -> Sleep at 22:30 (if schedule enabled) | Lower setpoints overnight |
| Battery: low battery alert | Persistent notification when any TRV/sensor/vacuum battery < 20% for 10 min | Avoid dead valves in winter |
| System: device offline alert | Notification when a TRV, plug, or camera is unavailable for 30 min | Catch Zigbee/Wi-Fi failures |
| Climate: high humidity alert | Notification when a room stays > 75% for 15 min | Damp/mould prevention |
| Energy: high plug load | Notification when a plug draws > 2500 W for 10 min | Catch a runaway heater/appliance |
| Energy: weekly summary | Sunday 19:00 notification with today/month/year kWh and cost | Makes energy use visible |
| Vacuum: finished cleaning | Notification when the vacuum docks | Know when cleaning is done |
| Vacuum: fault reported | Notification on a non-zero fault code | Maintenance |
| System: weekly backup health check | Monday 10:00 warning if no successful backup in 7 days | Avoid silent backup failure |

Heating profiles:

- **Home**: living room/bathrooms 22 °C, bedrooms 21 °C, halls/laundry/toilet/
  spare room 20 °C.
- **Sleep**: bathrooms 20 °C, bedrooms 19 °C, living/halls/laundry/toilet/spare
  18 °C.
- **Away**: all rooms 16 °C (frost protection).
- **Vacation**: all rooms 14 °C.

Adjust the temperatures in `scripts.yaml` to taste. The current manual targets
were higher (bathroom 24 °C, left bedroom 26 °C); the new values are a more
efficient starting point, not a requirement.

Safety: the heating schedule is **off by default**. The mode buttons on the
dashboard apply a profile only when you tap them, and no profile is re-applied
on Home Assistant restart. This means a restart will not silently change your
TRV setpoints. Enable `input_boolean.heating_schedule` when you are happy with
the temperatures.

## Camera

The Tapo C520WS is included in the **Camera** view:

- Live stream
- Arm/disarm scripts (privacy mode, motion detection, notifications, person
  alarm, auto-track, SD recording)
- Privacy, floodlight, motion/person detection, auto-track
- Siren with confirmation
- Camera health (Wi-Fi RSSI, network, SD sync, firmware)

The camera is also included in the offline-device alert. If you want the
camera to arm automatically when the house is Away, add a condition/action to
the "Heating: apply house mode" automation or create a separate automation
that calls `script.camera_arm` / `script.camera_disarm`.

The C520WS integration currently exposes the detection *configuration*
(motion/person/vehicle selectors) but no motion/person `binary_sensor`
entities, so HA cannot trigger on a "person detected" event yet. Enable motion
detection in the Tapo app and reload the integration; if binary sensors appear,
add a notification automation. Otherwise use the Tapo app's own push
notifications.

## Files added

```
data/HomeAssistant/config/
├── configuration.yaml       # helpers, includes, YAML dashboards
├── automations.yaml         # 11 starter automations
├── scripts.yaml             # heating profiles + camera/vacuum helpers
├── templates.yaml           # derived sensors (averages, totals, cost, battery)
├── utility_meters.yaml      # year-to-date plug counters
└── dashboards/
    ├── home.yaml            # Overview, Climate, Camera, Vacuum views
    └── energy.yaml          # plug power + accumulated energy
```

`scripts/sync_manifest.txt` now includes the new files so
`scripts/sync.sh --config` keeps the disaster-recovery snapshot complete.

> **Important:** `data/` is normally a pull-only snapshot generated from the
> live instance by `scripts/sync.sh --config`. These files are proposed config.
> Deploy them first (or commit them before running the sync); otherwise
> `sync.sh --config` will overwrite them with the current live files.

## How to apply to the live instance

The live config is root-owned, but the Docker socket is available. From the
repo root:

```bash
scripts/deploy_homeassistant.sh
```

The script backs up the current YAML to `/tmp/ha-backup-<timestamp>/`, copies
the new files, runs `hass --script check_config`, and only restarts the
container after a successful validation. Use `--no-restart` to copy and
validate without applying, or `--yes` to skip the restart prompt.

If you prefer to do it manually, the equivalent steps are:

```bash
# 1. Back up the current files
mkdir -p /tmp/ha-backup
cp /mnt/drive/HomeAssistant/config/{configuration.yaml,automations.yaml,scripts.yaml} /tmp/ha-backup/

# 2. Copy the new files into the container (writes through the bind mount)
docker cp data/HomeAssistant/config/configuration.yaml   homeassistant:/config/configuration.yaml
docker cp data/HomeAssistant/config/automations.yaml     homeassistant:/config/automations.yaml
docker cp data/HomeAssistant/config/scripts.yaml         homeassistant:/config/scripts.yaml
docker cp data/HomeAssistant/config/templates.yaml        homeassistant:/config/templates.yaml
docker cp data/HomeAssistant/config/utility_meters.yaml   homeassistant:/config/utility_meters.yaml
docker exec homeassistant mkdir -p /config/dashboards
docker cp data/HomeAssistant/config/dashboards/home.yaml   homeassistant:/config/dashboards/home.yaml
docker cp data/HomeAssistant/config/dashboards/energy.yaml homeassistant:/config/dashboards/energy.yaml

# 3. Validate
docker exec homeassistant hass --script check_config -c /config

# 4. Apply
docker restart homeassistant
```

Then:

1. Open **Profile -> Dashboard** and select **Home** as the default dashboard.
2. Open **Settings -> Dashboards -> Energy** and add the two plug energy
   sensors under **Individual devices**.
3. Check `input_number.electricity_price` (default 36 Ft/kWh) and adjust it.
4. Review the comfort temperatures in `scripts.yaml`.
5. Rename the plugs to what they actually power.

If you only want to try the dashboards without the automations, copy
`configuration.yaml`, `templates.yaml`, `utility_meters.yaml`, and the
`dashboards/` files, and leave `automations.yaml` / `scripts.yaml` untouched.

## Recommended next hardware

In priority order:

1. **Door/window contacts** for the main heated rooms (living room, bedrooms,
   bathroom). Use them to pause the TRV when a window is open.
2. **Presence detection** — the HA Companion app on phones is the cheapest
   option; it also gives actionable notifications. Add the phones as device
   trackers to `person.potterhome`, then add "everyone left -> Away" and
   "someone arrived -> Home" automations.
3. **A few smart lights/plugs** if you want lighting automations; there are
   currently no light entities at all.
4. **A central boiler relay/thermostat** if the boiler supports it. TRVs alone
   cannot stop the boiler from firing; a relay can save more energy than
   per-room valves.
5. **A second Zigbee router** near the upstairs plug if the flapping persists.
   The two plugs are already acting as repeaters, but the ZBBridge-P is the
   only coordinator.

## What a good HA overview usually looks like

Most experienced HA users do **not** use the auto-generated Overview. A typical
dashboard is built around tasks, not around the entity registry:

- **Top row**: house mode / presence, outside weather, one or two key alerts.
- **Rooms**: one section per room with a thermostat, temperature/humidity, and
  lights. Area cards or `tile` cards, 2-3 columns on mobile.
- **Energy**: current load, today/month totals, one chart. The built-in Energy
  dashboard handles long-term totals.
- **Camera/security**: one live card plus arm/disarm controls; not a wall of
  80 camera configuration entities.
- **System**: backups, updates, low batteries, offline devices — usually on a
  separate "System" view, not the main page.
- **Hide the noise**: diagnostic/config entities (RSSI, connection state,
  temperature correction, work mode) belong in the device page, not the
  dashboard.
- **Use areas and labels**: assign devices to areas/floors and label them
  (`Climate`, `Energy`, `Battery`, `Security`). This makes area cards, voice
  control, and future dashboards much easier.
- **Mobile first**: 2 columns, large tap targets, no more than ~6 cards per
  screen. Use the Sections view (used here) rather than a long masonry page.
- **Optional HACS cards**: Mushroom cards, Mini Graph Card, ApexCharts, and
  card-mod are popular for polish. The dashboards here use only built-in
  cards, so they work without HACS.
