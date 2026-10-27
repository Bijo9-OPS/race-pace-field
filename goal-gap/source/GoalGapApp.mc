import Toybox.Application;
import Toybox.WatchUi;

class GoalGapApp extends Application.AppBase {

    hidden var mView = null;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        mView = new GoalGapView();
        return [ mView ];
    }

    // The menu shown when you open this field's settings on the watch.
    function getSettingsView() {
        var menu = $.buildSettingsMenu();
        return [ menu, new SettingsMenuDelegate(menu) ];
    }

    // Called when the settings are changed from the phone or Garmin Express.
    function onSettingsChanged() {
        if (mView != null) {
            mView.refresh();
        }
        WatchUi.requestUpdate();
    }
}
