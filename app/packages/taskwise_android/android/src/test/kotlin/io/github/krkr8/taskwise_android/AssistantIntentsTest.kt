package io.github.krkr8.taskwise_android

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class AssistantIntentsTest {
  private fun share(text: String?, subject: String? = null, type: String = "text/plain") =
    AssistantIntents.action(AssistantIntents.ACTION_SEND, type, text, subject)

  @Test
  fun newTaskShortcut() {
    assertEquals(
      mapOf("type" to "newTask"),
      AssistantIntents.action(AssistantIntents.NEW_TASK, null, null, null),
    )
  }

  @Test
  fun sharedTextBecomesATask() {
    assertEquals(mapOf("type" to "share", "text" to "Buy milk"), share("  Buy milk \n"))
  }

  @Test
  fun aSubjectBecomesTheTitleLine() {
    assertEquals(
      mapOf("type" to "share", "text" to "A good article\nhttps://example.com/a"),
      share("https://example.com/a", subject = "A good article"),
    )
    // Apps that repeat the subject in the text don't get it twice.
    assertEquals(
      mapOf("type" to "share", "text" to "A good article https://example.com/a"),
      share("A good article https://example.com/a", subject = "A good article"),
    )
    assertEquals(
      mapOf("type" to "share", "text" to "Only a subject"),
      share(null, subject = "Only a subject"),
    )
  }

  @Test
  fun nothingToAdd() {
    assertNull(share("   "))
    assertNull(share(null))
    assertNull(share("photo", type = "image/png"))
    assertNull(AssistantIntents.action("android.intent.action.MAIN", null, null, null))
    assertNull(AssistantIntents.action(null, null, null, null))
  }
}
