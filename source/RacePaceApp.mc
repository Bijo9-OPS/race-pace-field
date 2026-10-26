import Toybox.Application;
import Toybox.WatchUi;

class RacePaceApp extends Application.AppBase {

    hidden var mView = null;

    function initialize() {
        AppBase.initialize();
    }

    function getInitialView() {
        mView = new RacePaceView();
        return [ mView ];
    }

    // Called when the settings are changed from the phone or Garmin Express.
    function onSettingsChanged() {
        if (mView != null) {
            mView.loadSettings();
        }
        WatchUi.requestUpdate();
    }
}
