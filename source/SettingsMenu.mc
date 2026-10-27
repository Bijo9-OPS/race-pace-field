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
            var seconds = $.parseClock($.settingString("targetTime", "1:43:30"), true);
            $.openNumberList(:goal, [(seconds / 3600) % 10, (seconds % 3600) / 60, seconds % 60], 0, item, mMenu);
        } else if (id == :custom) {
            var km = $.customKm();
            var whole = km.toNumber();
            var hundredths = ((km - whole) * 100 + 0.5).toNumber();
            if (whole > 99) {
                whole = 99;
            }
            if (hundredths > 99) {
                hundredths = 99;
            }
            $.openNumberList(:custom, [whole, hundredths], 0, item, mMenu);
        }
    }
}

// Garmin's own Picker crashes inside a data field's settings on the Epix 2,
// and screens we draw ourselves redraw very slowly there, so each "wheel" is
// a normal scrolling list of numbers: UP and DOWN scroll, START picks the
// number and moves on to the next wheel, and the last one saves.
function wheelTitles(kind) {
    return kind == :goal ? ["Hours", "Minutes", "Seconds"] : ["Kilometres", "Hundredths"];
}

function wheelText(kind, values) {
    if (kind == :goal) {
        return values[0].format("%d") + ":" + values[1].format("%02d") + ":" + values[2].format("%02d");
    }
    return values[0].format("%d") + "." + values[1].format("%02d") + " km";
}

function openNumberList(kind, values, stage, item, mainMenu) {
    var max = (kind == :goal && stage == 0) ? 9 : (kind == :goal ? 59 : 99);
    var format = (stage == 0) ? "%d" : "%02d";
    var menu = new WatchUi.Menu2({:title => $.wheelTitles(kind)[stage] + " " + $.wheelText(kind, values)});
    for (var i = 0; i <= max; i++) {
        menu.addItem(new WatchUi.MenuItem(i.format(format), null, i, {}));
    }
    menu.setFocus(values[stage]);
    var delegate = new NumberListDelegate(kind, values, stage, item, mainMenu);
    if (stage == 0) {
        WatchUi.pushView(menu, delegate, WatchUi.SLIDE_LEFT);
    } else {
        WatchUi.switchToView(menu, delegate, WatchUi.SLIDE_LEFT);
    }
}

class NumberListDelegate extends WatchUi.Menu2InputDelegate {

    hidden var mKind;
    hidden var mValues;
    hidden var mStage;
    hidden var mItem;
    hidden var mMainMenu;

    function initialize(kind, values, stage, item, mainMenu) {
        Menu2InputDelegate.initialize();
        mKind = kind;
        mValues = values;
        mStage = stage;
        mItem = item;
        mMainMenu = mainMenu;
    }

    function onSelect(item) {
        mValues[mStage] = item.getId();
        if (mStage < $.wheelTitles(mKind).size() - 1) {
            $.openNumberList(mKind, mValues, mStage + 1, mItem, mMainMenu);
            return;
        }
        save();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
    }

    hidden function save() {
        var v = mValues;
        if (mKind == :goal) {
            var text = $.wheelText(:goal, v);
            Application.Properties.setValue("targetTime", text);
            Application.Properties.setValue("targetMode", 0);
            mItem.setSubLabel(text);
        } else {
            var km = v[0] + v[1] / 100.0;
            if (km < 0.1) {
                km = 0.1;
            }
            Application.Properties.setValue("customDistance", km.toFloat());
            Application.Properties.setValue("customUnit", 0);
            Application.Properties.setValue("raceDistance", 4);
            mItem.setSubLabel($.customKmText());
            var index = mMainMenu.findItemById(:distance);
            if (index >= 0) {
                mMainMenu.getItem(index).setSubLabel($.distanceName(4));
            }
        }
        $.settingsChanged();
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
