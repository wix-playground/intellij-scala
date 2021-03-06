package org.jetbrains.plugins.scala.copy

import com.intellij.codeInsight.CodeInsightSettings
import org.jetbrains.plugins.scala.settings.{ScalaApplicationSettings, ScalaProjectSettings}

/**
  * [[CopyJavaToScala]] check imports addition to converted code, when they were not copied
  *
  * Conversion functionaluty from java to scala
  * tested with [[org.jetbrains.plugins.scala.conversion.JavaToScalaConversionTestBase]]
  *
  * Created by Kate Ustuyzhanina on 12/28/16.
  */
class CopyJavaToScala extends CopyTestBase(Java(), Scala()) {

  override def setUp(): Unit = {
    super.setUp()
    ScalaProjectSettings.getInstance(getProject).setDontShowConversionDialog(true)
    ScalaApplicationSettings.getInstance().ADD_IMPORTS_ON_PASTE = CodeInsightSettings.YES
  }

  def testAddSimpleImport() = {
    val fromText =
      """
        |import java.io.File;
        |
        |<selection>public class AnonymousClass {
        |   File file = new File("super");
        |}</selection>
      """.stripMargin

    val expected =
      """import java.io.File
        |
        |class AnonymousClass {
        |  val file: File = new File("super")
        |}""".stripMargin

    doTestEmptyToFile(fromText, expected)
  }

  def testRefAsArray(): Unit ={
    val fromText =
      """
        |import java.io.File;
        |
        |<selection>public class Test {
        |   File[] array = new File[23];
        |}</selection>
      """.stripMargin

    val expected =
      """import java.io.File
        |
        |class Test {
        |  val array: Array[File] = new Array[File](23)
        |}""".stripMargin

    doTestEmptyToFile(fromText, expected)
  }

  def testParametrizedType(): Unit ={
    val fromText =
      """
        |import java.util.ArrayList;
        |import java.util.List;
        |
        |<selection>public class Test {
        |    List<Integer> list = new ArrayList<Integer>();
        |}</selection>
      """.stripMargin

    val expected =
      """import java.util
        |import java.util.{ArrayList, List}
        |
        |class Test {
        |  val list: util.List[Integer] = new util.ArrayList[Integer]
        |}""".stripMargin

    doTestEmptyToFile(fromText, expected)
  }
}
