package id.flutter.flutter_background_service;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertNotNull;
import static org.junit.Assert.assertTrue;
import static org.junit.Assert.fail;
import static org.robolectric.Shadows.shadowOf;

import android.content.ComponentName;
import android.content.Context;
import android.content.ContextWrapper;
import android.content.Intent;
import android.os.PowerManager;

import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.Robolectric;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;

@RunWith(RobolectricTestRunner.class)
public class BootReceiverWakeLockTest {
    @Test
    public void bootStartupStartsServiceAndReleasesWakeLockWhenServiceStarts() {
        Context context = RuntimeEnvironment.getApplication();
        new Config(context).setAutoStartOnBoot(true);
        BackgroundService.lockStatic = null;

        new BootReceiver().onReceive(context, new Intent(Intent.ACTION_BOOT_COMPLETED));

        Intent startedService = shadowOf(context).getNextStartedService();
        assertNotNull("boot should start the background service", startedService);
        PowerManager.WakeLock bootWakeLock = BackgroundService.getLock(context);
        assertTrue("receiver should hold the wake lock until service startup", bootWakeLock.isHeld());

        try {
            Robolectric.buildService(TestBackgroundService.class).create();

            assertFalse("service startup should release the boot wake lock", bootWakeLock.isHeld());
        } finally {
            if (BackgroundService.lockStatic != null && BackgroundService.lockStatic.isHeld()) {
                BackgroundService.lockStatic.release();
            }
            BackgroundService.lockStatic = null;
        }
    }

    @Test
    public void bootStartFailureReleasesWakeLockAndPropagatesFailure() {
        Context context = RuntimeEnvironment.getApplication();
        new Config(context).setAutoStartOnBoot(true);
        BackgroundService.lockStatic = null;
        PowerManager.WakeLock[] acquiredWakeLock = new PowerManager.WakeLock[1];
        Context failingContext = new ContextWrapper(context) {
            @Override
            public ComponentName startService(Intent service) {
                acquiredWakeLock[0] = BackgroundService.lockStatic;
                throw new IllegalStateException("service start failed");
            }
        };

        try {
            new BootReceiver().onReceive(failingContext, new Intent(Intent.ACTION_BOOT_COMPLETED));
            fail("boot should propagate a failed service start");
        } catch (IllegalStateException exception) {
            assertEquals("service start failed", exception.getMessage());
        } finally {
            BackgroundService.lockStatic = null;
        }

        assertNotNull("receiver should acquire a wake lock before startup", acquiredWakeLock[0]);
        assertFalse("a failed service start should release the wake lock", acquiredWakeLock[0].isHeld());
    }

    @Test
    public void bootStartThatIsNotQueuedReleasesWakeLock() {
        Context context = RuntimeEnvironment.getApplication();
        new Config(context).setAutoStartOnBoot(true);
        BackgroundService.lockStatic = null;
        PowerManager.WakeLock[] acquiredWakeLock = new PowerManager.WakeLock[1];
        Context unavailableContext = new ContextWrapper(context) {
            @Override
            public ComponentName startService(Intent service) {
                acquiredWakeLock[0] = BackgroundService.lockStatic;
                return null;
            }
        };

        new BootReceiver().onReceive(unavailableContext, new Intent(Intent.ACTION_BOOT_COMPLETED));

        assertNotNull("receiver should acquire a wake lock before startup", acquiredWakeLock[0]);
        assertFalse("an unqueued service start should release the wake lock", acquiredWakeLock[0].isHeld());
        BackgroundService.lockStatic = null;
    }

    @Test
    public void failedSecondBootStartDoesNotReleaseFirstBroadcastWakeLock() {
        Context context = RuntimeEnvironment.getApplication();
        new Config(context).setAutoStartOnBoot(true);
        BackgroundService.lockStatic = null;
        int[] startCalls = new int[1];
        Context firstStartQueuedThenUnavailable = new ContextWrapper(context) {
            @Override
            public ComponentName startService(Intent service) {
                startCalls[0]++;
                if (startCalls[0] == 1) {
                    return new ComponentName(context, BackgroundService.class);
                }
                if (startCalls[0] == 2) {
                    throw new IllegalStateException("second service start failed");
                }
                return null;
            }
        };

        try {
            new BootReceiver().onReceive(firstStartQueuedThenUnavailable, new Intent(Intent.ACTION_BOOT_COMPLETED));
            PowerManager.WakeLock firstWakeLock = BackgroundService.lockStatic;
            assertNotNull("first boot should acquire a wake lock", firstWakeLock);
            assertTrue("first boot should keep its wake lock while startup is pending", firstWakeLock.isHeld());

            try {
                new BootReceiver().onReceive(firstStartQueuedThenUnavailable, new Intent(Intent.ACTION_BOOT_COMPLETED));
                fail("boot should propagate a failed second service start");
            } catch (IllegalStateException exception) {
                assertEquals("second service start failed", exception.getMessage());
            }

            assertTrue("a failed second start must not release the first boot lock", firstWakeLock.isHeld());
            new BootReceiver().onReceive(firstStartQueuedThenUnavailable, new Intent(Intent.ACTION_BOOT_COMPLETED));
            assertTrue("a second unqueued start must not release the first boot lock", firstWakeLock.isHeld());
            Robolectric.buildService(TestBackgroundService.class).create();
            assertFalse("service startup should release the first boot lock", firstWakeLock.isHeld());
        } finally {
            if (BackgroundService.lockStatic != null && BackgroundService.lockStatic.isHeld()) {
                BackgroundService.lockStatic.release();
            }
            BackgroundService.lockStatic = null;
        }
    }

    private static final class TestBackgroundService extends BackgroundService {
        @Override
        protected void runService() {
            // Keep this lifecycle test focused on service startup and wake-lock ownership.
        }
    }
}
