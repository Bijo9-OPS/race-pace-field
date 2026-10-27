# Goal Gap (Garmin data field)

A second data field that goes with Live Pace Calculator. It shows how far
ahead or behind your goal you are, in minutes and seconds:

```
    AHEAD            BEHIND
     1:29             0:45
  Need 4:52/km     Need 4:57/km
```

- Green means ahead of your goal, red means behind.
- "Ahead" and "behind" are measured against running the whole race at an even
  pace for your goal time.
- It updates every 10 seconds, like Live Pace Calculator.
- Before 200 m it shows 0:00 and your goal time. At the finish it shows how
  much faster or slower than your goal you were.

## Settings

Garmin doesn't let two apps share settings, so Goal Gap has its own menu with
the same lines as Live Pace Calculator (race distance, goal time, custom
distance). Set the same race and goal in both.

On the Epix 2: Run > hold MENU > Run Settings > ConnectIQ Fields > Goal Gap.

## Build and install

Same as Live Pace Calculator, but open this **goal-gap** folder in VS Code
(File > Open Folder) before running Monkey C: Build for Device. Copy the new
.prg to GARMIN/APPS on the watch, unplug, and restart the watch.
