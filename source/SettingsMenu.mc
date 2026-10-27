import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// On-watch settings: race distance, goal finish time and custom distance.

function distanceName(index) {
    if (index == 0) {
        return "5K";
    } else if (index == 1) {
        return "10K";
    } else if (index == 2) {
        return "Half marathon";
    } else if (index == 3) {
        return "Marathon";
    }
    return "Custom " + $.customKmText();
}

// The custom distance in km, e.g. "15.00 km".
function customKm() {
    var v = Application.Properties.getValue("customDistance");
    var km = (v instanceof Number || v instanceof Float) ? v.toFloat() : 42.195;
    if ($.settingNumber("customUnit", 0) == 1) {
        km = km * METERS_PER_MILE / METERS_PER_KM;
    }
    return km;
}

function customKmText() {
    return $.customKm().format("%.2f") + " km";
}

function settingNumber(key, fallback) {
    var v = Application.Properties.getValue(key);
    return (v instanceof Number || v instanceof Float) ? v.toNumber() : fallback;
}

function settingString(key, fallback) {
    var v = Application.Properties.getValue(key);
    return v instanceof String ? v : fallback;
}

// Tells the running data field to pick up the new values.
function settingsChanged() {
    Application.getApp().onSettingsChanged();
}

function buildSettingsMenu() {
    var menu = new WatchUi.Menu2({:title => "Live Pace"});
    menu.addItem(new WatchUi.MenuItem("Race distance",
        $.distanceName($.settingNumber("raceDistance", 2)), :distance, {}));
    menu.addItem(new WatchUi.MenuItem("Goal time",
        $.settingString("targetTime", "1:43:30"), :goal, {}));
    menu.addItem(new WatchUi.MenuItem("Custom distance",
        $.customKmText(), :custom, {}));
    return menu;
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    hidden var mMenu;

    function initialize(menu) {
        Menu2InputDelegate.initialize();
        mMenu = menu;
    }

    function onSelect(item) {
        var id = item.getId();
        if (id == :distance) {
            // Each press moves to the next distance: 5K, 10K, half, marathon, custom.
            var current = $.settingNumber("raceDistance", 2);
            var next = (current >= 4) ? 0 : current + 1;
            Application.Properties.setValue("raceDistance", next);
            item.setSubLabel($.distanceName(next));
            $.settingsChanged();
            WatchUi.requestUpdate();
        } else if (id == :goal) {
            var goalMenu = $.buildStepMenu("Goal time", $.goalText(),
                [-60, 60, -10, 10, -1, 1],
                ["Faster 1 min", "Slower 1 min", "Faster 10 sec", "Slower 10 sec", "Faster 1 sec", "Slower 1 sec"]);
            WatchUi.pushView(goalMenu, new StepMenuDelegate(:goal, item, mMenu, goalMenu), WatchUi.SLIDE_LEFT);
        } else if (id == :custom) {
            var distanceMenu = $.buildStepMenu("Custom distance", $.customKmText(),
                [1000, -1000, 100, -100, 10, -10],
                ["+1 km", "-1 km", "+0.1 km", "-0.1 km", "+0.01 km", "-0.01 km"]);
            WatchUi.pushView(distanceMenu, new StepMenuDelegate(:custom, item, mMenu, distanceMenu), WatchUi.SLIDE_LEFT);
        }
    }
}

// Picker wheels crash inside a data field's settings on the watch, so values
// are changed with plain menu lines that add or take away a fixed step.
function buildStepMenu(title, current, steps, labels) {
    var menu = new WatchUi.Menu2({:title => title});
    menu.addItem(new WatchUi.MenuItem("Now", current, :current, {}));
    for (var i = 0; i < steps.size(); i++) {
        menu.addItem(new WatchUi.MenuItem(labels[i], null, steps[i], {}));
    }
    return menu;
}

function goalText() {
    return $.clockText($.parseClock($.settingString("targetTime", "1:43:30"), true));
}

function clockText(seconds) {
    return (seconds / 3600).format("%d") + ":" + ((seconds % 3600) / 60).format("%02d") + ":" + (seconds % 60).format("%02d");
}

// Applies one step to the goal time (seconds) or custom distance (metres).
class StepMenuDelegate extends WatchUi.Menu2InputDelegate {

    hidden var mKind;
    hidden var mParentItem;
    hidden var mParentMenu;
    hidden var mMenu;

    function initialize(kind, parentItem, parentMenu, menu) {
        Menu2InputDelegate.initialize();
        mKind = kind;
        mParentItem = parentItem;
        mParentMenu = parentMenu;
        mMenu = menu;
    }

    function onSelect(item) {
        var step = item.getId();
        if (step == :current) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return;
        }

        var text;
        if (mKind == :goal) {
            var seconds = $.parseClock($.settingString("targetTime", "1:43:30"), true) + step;
            if (seconds < 60) {
                seconds = 60;
            } else if (seconds > 35999) {
                seconds = 35999;
            }
            text = $.clockText(seconds);
            Application.Properties.setValue("targetTime", text);
            Application.Properties.setValue("targetMode", 0);
        } else {
            var meters = ($.customKm() * 1000 + 0.5).toNumber() + step;
            if (meters < 100) {
                meters = 100;
            } else if (meters > 999990) {
                meters = 999990;
            }
            Application.Properties.setValue("customDistance", meters / 1000.0);
            Application.Properties.setValue("customUnit", 0);
            Application.Properties.setValue("raceDistance", 4);
            text = $.customKmText();
            var index = mParentMenu.findItemById(:distance);
            if (index >= 0) {
                mParentMenu.getItem(index).setSubLabel($.distanceName(4));
            }
        }

        mParentItem.setSubLabel(text);
        // The "Now" line is the first one in this menu.
        mMenu.getItem(0).setSubLabel(text);
        $.settingsChanged();
        WatchUi.requestUpdate();
    }
}

// Reads "3:30:00", "45:00" or "4:58" as a number of seconds.
// With two parts like "3:30", hoursFirst decides between h:mm and m:ss:
// a first part under 10 is read as hours for a finish time.
function parseClock(text, hoursFirst) {
    if (text == null) {
        return 0;
    }
    var parts = [] as Array<Number>;
    var current = 0;
    var chars = text.toString().toCharArray() as Array<Char>;
    for (var i = 0; i < chars.size(); i++) {
        var code = chars[i].toNumber();
        if (code >= 48 && code <= 57) {
            current = current * 10 + (code - 48);
        } else if (chars[i] == ':' || chars[i] == '.') {
            parts.add(current);
            current = 0;
        }
    }
    parts.add(current);

    if (parts.size() == 2 && hoursFirst && parts[0] < 10) {
        return parts[0] * 3600 + parts[1] * 60;
    }
    var total = 0;
    for (var i = 0; i < parts.size() && i < 3; i++) {
        total = total * 60 + parts[i];
    }
    return total;
}
