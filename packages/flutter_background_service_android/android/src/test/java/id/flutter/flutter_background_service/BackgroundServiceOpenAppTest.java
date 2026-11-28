package id.flutter.flutter_background_service;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertTrue;

import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.Robolectric;
import org.robolectric.RobolectricTestRunner;

@RunWith(RobolectricTestRunner.class)
public class BackgroundServiceOpenAppTest {
    @Test
    public void returnsFalseWhenNoLaunchIntentExists() {
        BackgroundService service = Robolectric.buildService(TestBackgroundService.class)
                .create()
                .get();
        RecordingResult result = new RecordingResult();

        service.onMethodCall(new MethodCall("openApp", null), result);

        assertTrue("openApp must complete its method result", result.completed);
        assertEquals(Boolean.FALSE, result.value);
    }

    private static final class TestBackgroundService extends BackgroundService {
        @Override
        public void onCreate() {
            // Avoid starting the Flutter engine; the test only needs an attached service context.
        }
    }

    private static final class RecordingResult implements MethodChannel.Result {
        private boolean completed;
        private Object value;

        @Override
        public void success(Object value) {
            this.completed = true;
            this.value = value;
        }

        @Override
        public void error(String errorCode, String errorMessage, Object errorDetails) {
            this.completed = true;
        }

        @Override
        public void notImplemented() {
            this.completed = true;
        }
    }
}
