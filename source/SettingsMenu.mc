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
            var view = new WheelView("Goal time",
                [(seconds / 3600) % 10, (seconds % 3600) / 60, seconds % 60],
                [9, 59, 59], ["%d", "%02d", "%02d"], ":");
            WatchUi.pushView(view, new WheelDelegate(view, :goal, item, mMenu), WatchUi.SLIDE_LEFT);
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
            var view = new WheelView("Distance km", [whole, hundredths], [99, 99], ["%d", "%02d"], ".");
            WatchUi.pushView(view, new WheelDelegate(view, :custom, item, mMenu), WatchUi.SLIDE_LEFT);
        }
    }
}

// Garmin's own Picker crashes inside a data field's settings on the Epix 2,
// so this is a small hand-made set of wheels driven by the watch buttons:
// UP and DOWN turn the highlighted wheel, START moves to the next wheel and
// saves after the last one, BACK goes to the previous wheel or leaves.
class WheelView extends WatchUi.View {

    var values;
    var index = 0;
    hidden var mTitle;
    hidden var mMax;
    hidden var mFormats;
    hidden var mSeparator;

    function initialize(title, startValues, max, formats, separator) {
        View.initialize();
        mTitle = title;
        values = startValues;
        mMax = max;
        mFormats = formats;
        mSeparator = separator;
    }

    function turn(step) {
        var v = values[index] + step;
        if (v > mMax[index]) {
            v = 0;
        } else if (v < 0) {
            v = mMax[index];
        }
        values[index] = v;
        WatchUi.requestUpdate();
    }

    function onUpdate(dc) {
        dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_BLACK);
        dc.clear();
        var w = dc.getWidth();
        var h = dc.getHeight();

        dc.drawText(w / 2, h * 0.2, Graphics.FONT_SMALL, mTitle, Graphics.TEXT_JUSTIFY_CENTER);

        var font = Graphics.FONT_LARGE;
        var texts = [];
        var total = 0;
        var sepWidth = dc.getTextWidthInPixels(mSeparator, font);
        for (var i = 0; i < values.size(); i++) {
            texts.add(values[i].format(mFormats[i]));
            total += dc.getTextWidthInPixels(texts[i], font);
        }
        total += sepWidth * (values.size() - 1);

        var x = (w - total) / 2;
        var y = h / 2;
        var fontH = dc.getFontHeight(font);
        for (var i = 0; i < texts.size(); i++) {
            var tw = dc.getTextWidthInPixels(texts[i], font);
            var cx = x + tw / 2;
            if (i == index) {
                dc.setColor(Graphics.COLOR_ORANGE, Graphics.COLOR_TRANSPARENT);
                // Arrows show which wheel UP and DOWN will turn.
                dc.fillPolygon([[cx - 8, y - fontH / 2 - 4], [cx + 8, y - fontH / 2 - 4], [cx, y - fontH / 2 - 14]]);
                dc.fillPolygon([[cx - 8, y + fontH / 2 + 4], [cx + 8, y + fontH / 2 + 4], [cx, y + fontH / 2 + 14]]);
            } else {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            }
            dc.drawText(cx, y, font, texts[i], Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
            x += tw;
            if (i < texts.size() - 1) {
                dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
                dc.drawText(x + sepWidth / 2, y, font, mSeparator, Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
                x += sepWidth;
            }
        }

        dc.setColor(Graphics.COLOR_LT_GRAY, Graphics.COLOR_TRANSPARENT);
        var hint = (index == values.size() - 1) ? "START to save" : "START for next";
        dc.drawText(w / 2, h * 0.72, Graphics.FONT_XTINY, hint, Graphics.TEXT_JUSTIFY_CENTER);
    }
}

class WheelDelegate extends WatchUi.BehaviorDelegate {

    hidden var mView;
    hidden var mKind;
    hidden var mItem;
    hidden var mMenu;

    function initialize(view, kind, item, menu) {
        BehaviorDelegate.initialize();
        mView = view;
        mKind = kind;
        mItem = item;
        mMenu = menu;
    }

    // UP button
    function onPreviousPage() {
        mView.turn(1);
        return true;
    }

    // DOWN button
    function onNextPage() {
        mView.turn(-1);
        return true;
    }

    // START button
    function onSelect() {
        if (mView.index < mView.values.size() - 1) {
            mView.index += 1;
            WatchUi.requestUpdate();
            return true;
        }
        save();
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    function onBack() {
        if (mView.index > 0) {
            mView.index -= 1;
            WatchUi.requestUpdate();
            return true;
        }
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }

    hidden function save() {
        var v = mView.values;
        if (mKind == :goal) {
            var text = v[0].format("%d") + ":" + v[1].format("%02d") + ":" + v[2].format("%02d");
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
            var index = mMenu.findItemById(:distance);
            if (index >= 0) {
                mMenu.getItem(index).setSubLabel($.distanceName(4));
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
