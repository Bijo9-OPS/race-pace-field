import Toybox.Activity;
import Toybox.Application;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.WatchUi;

const METERS_PER_KM = 1000.0;
const METERS_PER_MILE = 1609.344;
const UPDATE_SECONDS = 10.0;

// Values returned by DataField.getObscurityFlags().
const EDGE_LEFT = 1;
const EDGE_TOP = 2;
const EDGE_RIGHT = 4;
const EDGE_BOTTOM = 8;

// Shows the average pace needed over the rest of the race to finish on goal.
class RacePaceView extends WatchUi.DataField {

    hidden var mRaceMeters = 42195.0;   // race distance, including any GPS allowance
    hidden var mGoalSeconds = 0.0;      // goal finish time
    hidden var mPerMile = false;        // show pace per mile instead of per km
    hidden var mLastCalc = -1000.0;     // timer time of the last recalculation

    hidden var mValue = "--:--";
    hidden var mValueIsNumber = true;
    hidden var mStatus = "";
    hidden var mStatusState = 0;        // 0 neutral, 1 ahead, -1 behind

    function initialize() {
        DataField.initialize();
        loadSettings();
    }

    function loadSettings() {
        var distance = readNumber("raceDistance", 3);
        var meters = 42195.0;
        if (distance == 0) {
            meters = 5000.0;
        } else if (distance == 1) {
            meters = 10000.0;
        } else if (distance == 2) {
            meters = 21097.5;
        } else if (distance == 4) {
            var custom = readFloat("customDistance", 42.195);
            var unit = readNumber("customUnit", 0) == 1 ? METERS_PER_MILE : METERS_PER_KM;
            meters = custom * unit;
        }
        if (meters < 100.0) {
            meters = 100.0;
        }
        mPerMile = readNumber("displayUnit", 0) == 1;

        // Extra metres plan for the watch measuring the race long, and act as a buffer.
        var adjust = readFloat("distanceAdjust", 0.0);
        mRaceMeters = meters * (1.0 + adjust / 100.0) + readNumber("extraMeters", 0);

        if (readNumber("targetMode", 0) == 1) {
            // Goal pace: the finish time is that pace held over the official distance.
            var pace = $.parseClock(readString("targetPace", "5:00"), false);
            var paceUnit = readNumber("targetPaceUnit", 0) == 1 ? METERS_PER_MILE : METERS_PER_KM;
            mGoalSeconds = pace * meters / paceUnit;
        } else {
            mGoalSeconds = $.parseClock(readString("targetTime", "3:30:00"), meters >= 3000.0).toFloat();
        }
    }

    // Forces a fresh calculation on the next update, e.g. after settings change.
    function refresh() {
        loadSettings();
        mLastCalc = -1000.0;
    }

    function compute(info) {
        var doneMeters = 0.0;
        var elapsed = 0.0;
        if (info has :elapsedDistance && info.elapsedDistance != null) {
            doneMeters = info.elapsedDistance.toFloat();
        }
        if (info has :timerTime && info.timerTime != null) {
            elapsed = info.timerTime / 1000.0;
        }

        // Recalculate every 10 seconds of activity time so the number stays steady.
        // Before the start it updates every second, so a new goal shows at once.
        // A smaller timer means a new activity has started.
        if (elapsed > 0 && elapsed >= mLastCalc && elapsed - mLastCalc < UPDATE_SECONDS) {
            return;
        }
        mLastCalc = elapsed;

        // Settings changed in the watch menu are saved, but the running field is
        // not told about them, so read them again on every recalculation.
        loadSettings();
        var unitMeters = mPerMile ? METERS_PER_MILE : METERS_PER_KM;

        if (mGoalSeconds <= 0) {
            setText("Set goal", false, "Check settings", 0);
            return;
        }

        var leftMeters = mRaceMeters - doneMeters;
        var leftSeconds = mGoalSeconds - elapsed;

        if (leftMeters <= 0) {
            setText("Done", false, formatClock(elapsed), 0);
            return;
        }
        if (leftSeconds <= 0) {
            setText("--:--", true, "Past goal", -1);
            return;
        }

        var needed = leftSeconds / leftMeters * unitMeters;
        var value = formatPace(needed);

        // How far ahead or behind the goal you are, against an even-pace plan.
        if (doneMeters < 200.0) {
            setText(value, true, "Goal " + formatClock(mGoalSeconds), 0);
        } else {
            var planned = mGoalSeconds * doneMeters / mRaceMeters;
            var diff = (planned - elapsed).toNumber();
            if (diff >= 0) {
                setText(value, true, formatClock(diff) + " ahead", 1);
            } else {
                setText(value, true, formatClock(-diff) + " behind", -1);
            }
        }
    }

    function onUpdate(dc) {
        var bg = getBackgroundColor();
        var dark = bg == Graphics.COLOR_BLACK;
        var fg = dark ? Graphics.COLOR_WHITE : Graphics.COLOR_BLACK;
        dc.setColor(fg, bg);
        dc.clear();

        var w = dc.getWidth();
        var h = dc.getHeight();
        var cx = w / 2;

        // On round screens the edges of a field can be cut off; keep text inside.
        var flags = getObscurityFlags();
        var top = (flags & EDGE_TOP) != 0 ? h * 0.12 : h * 0.03;
        var bottom = (flags & EDGE_BOTTOM) != 0 ? h * 0.88 : h * 0.97;
        var maxWidth = (flags & (EDGE_LEFT | EDGE_RIGHT)) != 0 ? w * 0.78 : w * 0.94;

        var smallFont = Graphics.FONT_XTINY;
        var smallH = dc.getFontHeight(smallFont);
        var roomy = (bottom - top) > smallH * 3.2;

        var label = mPerMile ? "PACE NEEDED /MI" : "PACE NEEDED /KM";
        if (dc.getTextWidthInPixels(label, smallFont) > maxWidth) {
            label = mPerMile ? "NEED /MI" : "NEED /KM";
        }

        var valueTop = top;
        var valueBottom = bottom;
        if (roomy) {
            dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
            dc.drawText(cx, top, smallFont, label, Graphics.TEXT_JUSTIFY_CENTER);
            valueTop = top + smallH;
            if (mStatus.length() > 0) {
                valueBottom = bottom - smallH;
                dc.setColor(statusColor(dark, fg), Graphics.COLOR_TRANSPARENT);
                dc.drawText(cx, valueBottom, smallFont, fitStatus(dc, smallFont, maxWidth), Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        var font = pickFont(dc, mValue, maxWidth, valueBottom - valueTop);
        dc.setColor(fg, Graphics.COLOR_TRANSPARENT);
        dc.drawText(cx, (valueTop + valueBottom) / 2, font, mValue,
            Graphics.TEXT_JUSTIFY_CENTER | Graphics.TEXT_JUSTIFY_VCENTER);
    }

    // Biggest font that fits the space. Number fonts only have digits and ':'.
    hidden function pickFont(dc, text, maxWidth, maxHeight) {
        var fonts = mValueIsNumber
            ? [Graphics.FONT_NUMBER_THAI_HOT, Graphics.FONT_NUMBER_HOT, Graphics.FONT_NUMBER_MEDIUM,
               Graphics.FONT_NUMBER_MILD, Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL]
            : [Graphics.FONT_LARGE, Graphics.FONT_MEDIUM, Graphics.FONT_SMALL];
        for (var i = 0; i < fonts.size(); i++) {
            // Number fonts carry a lot of empty space above and below the digits.
            var height = dc.getFontHeight(fonts[i]) * (i < 4 && mValueIsNumber ? 0.75 : 1.0);
            if (dc.getTextWidthInPixels(text, fonts[i]) <= maxWidth && height <= maxHeight) {
                return fonts[i];
            }
        }
        return Graphics.FONT_TINY;
    }

    hidden function fitStatus(dc, font, maxWidth) {
        if (dc.getTextWidthInPixels(mStatus, font) <= maxWidth) {
            return mStatus;
        }
        // Short form for narrow fields: "+1:23" or "-0:45".
        var space = mStatus.find(" ");
        if (mStatusState != 0 && space != null) {
            return (mStatusState > 0 ? "+" : "-") + mStatus.substring(0, space);
        }
        return "";
    }

    hidden function statusColor(dark, fg) {
        if (mStatusState > 0) {
            return dark ? Graphics.COLOR_GREEN : Graphics.COLOR_DK_GREEN;
        } else if (mStatusState < 0) {
            return dark ? Graphics.COLOR_RED : Graphics.COLOR_DK_RED;
        }
        return fg;
    }

    hidden function setText(value, isNumber, status, state) {
        mValue = value;
        mValueIsNumber = isNumber;
        mStatus = status;
        mStatusState = state;
    }

    // Pace is rounded down so the watch never shows a pace slower than needed.
    hidden function formatPace(secondsPerUnit) {
        var s = secondsPerUnit.toNumber();
        if (s >= 6000) {
            return "--:--";
        }
        return (s / 60).format("%d") + ":" + (s % 60).format("%02d");
    }

    hidden function formatClock(seconds) {
        var s = seconds.toNumber();
        var hours = s / 3600;
        var mins = (s % 3600) / 60;
        var secs = s % 60;
        if (hours > 0) {
            return hours.format("%d") + ":" + mins.format("%02d") + ":" + secs.format("%02d");
        }
        return mins.format("%d") + ":" + secs.format("%02d");
    }

    hidden function readNumber(key, fallback) {
        var v = Application.Properties.getValue(key);
        return (v instanceof Number || v instanceof Float) ? v.toNumber() : fallback;
    }

    hidden function readFloat(key, fallback) {
        var v = Application.Properties.getValue(key);
        return (v instanceof Number || v instanceof Float) ? v.toFloat() : fallback;
    }

    hidden function readString(key, fallback) {
        var v = Application.Properties.getValue(key);
        return v instanceof String ? v : fallback;
    }
}
