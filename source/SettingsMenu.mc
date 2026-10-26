import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.WatchUi;

// On-watch settings: race distance and goal finish time.

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
    return "Custom";
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
    return menu;
}

class SettingsMenuDelegate extends WatchUi.Menu2InputDelegate {

    function initialize() {
        Menu2InputDelegate.initialize();
    }

    function onSelect(item) {
        var id = item.getId();
        if (id == :distance) {
            // Each press moves to the next distance: 5K, 10K, half, marathon.
            var current = $.settingNumber("raceDistance", 2);
            var next = (current >= 3) ? 0 : current + 1;
            Application.Properties.setValue("raceDistance", next);
            item.setSubLabel($.distanceName(next));
            $.settingsChanged();
            WatchUi.requestUpdate();
        } else if (id == :goal) {
            var seconds = $.parseClock($.settingString("targetTime", "1:43:30"), true);
            var picker = new WatchUi.Picker({
                :title => new WatchUi.Text({
                    :text => "Goal h:mm:ss",
                    :color => Graphics.COLOR_WHITE,
                    :font => Graphics.FONT_SMALL,
                    :locX => WatchUi.LAYOUT_HALIGN_CENTER,
                    :locY => WatchUi.LAYOUT_VALIGN_BOTTOM
                }),
                :pattern => [new NumberFactory(9, "%d"), new NumberFactory(59, "%02d"), new NumberFactory(59, "%02d")],
                :defaults => [(seconds / 3600) % 10, (seconds % 3600) / 60, seconds % 60]
            });
            WatchUi.pushView(picker, new GoalPickerDelegate(item), WatchUi.SLIDE_LEFT);
        }
    }
}

// One wheel of the goal time picker: 0 up to max.
class NumberFactory extends WatchUi.PickerFactory {

    hidden var mMax;
    hidden var mFormat;

    function initialize(max, format) {
        PickerFactory.initialize();
        mMax = max;
        mFormat = format;
    }

    function getSize() {
        return mMax + 1;
    }

    function getValue(index) {
        return index;
    }

    function getDrawable(index, selected) {
        return new WatchUi.Text({
            :text => index.format(mFormat),
            :color => Graphics.COLOR_WHITE,
            :font => Graphics.FONT_NUMBER_MILD,
            :locX => WatchUi.LAYOUT_HALIGN_CENTER,
            :locY => WatchUi.LAYOUT_VALIGN_CENTER
        });
    }
}

class GoalPickerDelegate extends WatchUi.PickerDelegate {

    hidden var mItem;

    function initialize(item) {
        PickerDelegate.initialize();
        mItem = item;
    }

    function onAccept(values) {
        var text = values[0].format("%d") + ":" + values[1].format("%02d") + ":" + values[2].format("%02d");
        Application.Properties.setValue("targetTime", text);
        Application.Properties.setValue("targetMode", 0);
        mItem.setSubLabel(text);
        $.settingsChanged();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onCancel() {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
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
