# Live Pace Calculator (Garmin data field)

A Connect IQ data field for your run screens. During a race it shows the
average pace you need to hold **for the rest of the race** to finish on your
goal. Under it, in green or red, it shows how far ahead or behind an even-pace
plan you are.

```
  PACE NEEDED /KM
       4:57
    0:42 ahead
```

- It recalculates every 10 seconds from the activity time and the distance
  covered so far, so the number stays steady instead of flickering.
- Before you start it shows your goal finish time.
- If you have already passed your goal time it shows `--:--` and "Past goal".
- When you reach the race distance it shows "Done" and your time.
- Pace is shown per km (you can switch it to per mile with `displayUnit`).
- The pace is rounded down (the faster way), so holding it keeps you on goal.

It works on the Fenix 6, 7 and 8, Epix 2, Enduro, and Forerunner 245, 255,
265, 745, 945, 955 and 965 families.

---

## 1. Set your race and goal

**On the watch:** the field has its own settings menu with three lines.
"Race distance" moves to the next distance each time you press it (5K, 10K,
half marathon, marathon, custom). "Goal time" opens a list
with the current goal at the top and lines to make it faster or slower by
1 minute, 10 seconds or 1 second. "Custom distance" works the same way in
steps of 1 km, 0.1 km and 0.01 km, and switches the race to that distance. Garmin shows this menu in the data field's options when you set
up your run screens.

**Before building:** the starting values come from one text file. The Garmin
Connect phone app can't change settings for an app you copied over yourself.

Open `resources/settings/properties.xml` in any text editor and change only the
value between `>` and `<` on these lines:

| Line | What to put |
|---|---|
| `raceDistance` | `0` = 5K, `1` = 10K, `2` = half marathon, `3` = marathon, `4` = custom |
| `customDistance` | Only for custom: the distance, e.g. `15` |
| `customUnit` | Only for custom: `0` = km, `1` = miles |
| `targetMode` | `0` = use a finish time, `1` = use an average pace |
| `targetTime` | Your goal time as h:mm:ss, e.g. `3:30:00` or `0:45:00` |
| `targetPace` | Your goal pace as m:ss, e.g. `4:58` |
| `targetPaceUnit` | `0` = that pace is per km, `1` = per mile |
| `displayUnit` | Show the needed pace per `0` = km, `1` = mile |
| `distanceAdjust` | Watches usually measure races a bit long. `1.0` plans for 1% extra. Leave `0.0` if unsure. |

Example, a 1:45:00 half marathon:

```xml
<property id="raceDistance" type="number">2</property>
<property id="targetMode" type="number">0</property>
<property id="targetTime" type="string">1:45:00</property>
```

Save the file, then build (step 3). Rebuild and copy again whenever you change
a goal.

## 2. One-time setup on your computer (about 20 minutes)

1. Install **Visual Studio Code** from https://code.visualstudio.com.
2. Install the **Connect IQ SDK Manager** from
   https://developer.garmin.com/connect-iq/sdk/. Open it, sign in with your
   Garmin account, download the latest SDK and click "Use this SDK".
3. In the SDK Manager open the **Devices** tab and download **fēnix® 6 Pro**
   (or whichever watch you have).
4. In VS Code open Extensions (the four squares icon on the left), search for
   **Monkey C** by Garmin and install it.
5. In VS Code press `Ctrl+Shift+P` (`Cmd+Shift+P` on a Mac), type
   **Monkey C: Verify Installation** and press Enter. If it asks to make a
   developer key, say yes and save it somewhere safe. Every build is signed
   with this key.

## 3. Build it for your watch

1. In VS Code choose **File > Open Folder** and open this `RacePace` folder.
2. Press `Ctrl+Shift+P` / `Cmd+Shift+P`, type **Monkey C: Build for Device**
   and press Enter.
3. Pick your watch (e.g. `fenix6pro`) and pick a folder to save into.
4. You get a file called `RacePace.prg`.

Optional: to try it on screen first, press `F5` (Run). The simulator opens;
in it choose **Simulation > Activity Data** to fake a run and watch the
numbers change.

## 4. Put it on the watch

1. Plug the watch into the computer with its USB cable.
   - Windows: it shows up like a USB drive.
   - Mac: install the free **OpenMTP** app (https://openmtp.ganeshrvel.com)
     and open it to see the watch's files.
2. Copy `RacePace.prg` into the watch folder `GARMIN/APPS`.
3. Unplug the watch. It may take a minute to settle.

## 5. Add it to your run screen

On the Fenix 6:

1. From the watch face press **Start**, pick **Run**, then hold **Up (Menu)**.
2. Go to **Run Settings > Data Screens**, pick a screen, then **Layout** if you
   want fewer, larger fields.
3. Pick the field to replace, go to **Connect IQ**, and choose
   **Live Pace Calculator**.

It reads best on a 1, 2 or 3-field screen. On a 4-field screen it still shows
the pace, just smaller.

---

## Notes

- Time is the activity timer, so pauses don't count against you. Turn
  **Auto Pause off** for races, so the clock matches the official one.
- Distance is the watch's GPS distance. If the watch beeps each km before the
  course markers, raise `distanceAdjust` (1.0 is a common choice for road
  races).
- To support another watch, open `manifest.xml` in VS Code, use
  **Monkey C: Edit Products** and tick it.
