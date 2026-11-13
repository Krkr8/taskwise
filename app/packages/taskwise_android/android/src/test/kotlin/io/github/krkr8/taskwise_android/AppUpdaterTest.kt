package io.github.krkr8.taskwise_android

import android.content.pm.PackageInstaller
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AppUpdaterTest {
  @Test
  fun statusNamesForDart() {
    assertNull(AppUpdater.statusName(PackageInstaller.STATUS_PENDING_USER_ACTION))
    assertEquals("success", AppUpdater.statusName(PackageInstaller.STATUS_SUCCESS))
    assertEquals("cancelled", AppUpdater.statusName(PackageInstaller.STATUS_FAILURE_ABORTED))
    assertEquals(
      "failed:${PackageInstaller.STATUS_FAILURE_INCOMPATIBLE}",
      AppUpdater.statusName(PackageInstaller.STATUS_FAILURE_INCOMPATIBLE),
    )
  }
}
