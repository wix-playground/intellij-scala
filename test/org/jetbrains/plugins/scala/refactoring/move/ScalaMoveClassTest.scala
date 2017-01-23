package org.jetbrains.plugins.scala
package refactoring.move

import java.io.File
import java.util

import com.intellij.openapi.vfs.impl.VirtualFilePointerManagerImpl
import com.intellij.openapi.vfs.pointers.VirtualFilePointerManager
import com.intellij.openapi.vfs.{LocalFileSystem, VfsUtil, VirtualFile, VirtualFileFilter}
import com.intellij.psi._
import com.intellij.psi.impl.source.PostprocessReformattingAspect
import com.intellij.psi.search.GlobalSearchScope
import com.intellij.refactoring.PackageWrapper
import com.intellij.refactoring.move.moveClassesOrPackages.{MoveClassesOrPackagesProcessor, SingleSourceRootMoveDestination}
import com.intellij.testFramework.{PlatformTestUtil, PsiTestUtil}
import org.jetbrains.plugins.scala.base.ScalaLightPlatformCodeInsightTestCaseAdapter
import org.jetbrains.plugins.scala.lang.psi.api.toplevel.typedef.{ScClass, ScObject}
import org.jetbrains.plugins.scala.lang.psi.impl.{ScalaFileImpl, ScalaPsiManager}
import org.jetbrains.plugins.scala.settings.ScalaApplicationSettings
import org.jetbrains.plugins.scala.util.TestUtils

import scala.collection.mutable.ArrayBuffer

/**
 * @author Alefas
 * @since 30.10.12
 */
class ScalaMoveClassTest extends ScalaLightPlatformCodeInsightTestCaseAdapter {
  def testPackageObject() {
    doTest("packageObject", Array("com.`package`"), "org")
  }

  def testPackageObject2() {
    doTest("packageObject2", Array("com"), "org")
  }

  def testSimple() {
    doTest("simple", Array("com.A"), "org")
  }

  def testSCL2625() {
    doTest("scl2625", Array("somepackage.Dummy", "somepackage.MoreBusiness", "somepackage.Business", "somepackage.AnotherEnum"), "dest")
  }

  def testSCL4623() {
    doTest("scl4623", Array("moveRefactoring.foo.B"), "moveRefactoring.bar")
  }

  def testSCL4613() {
    doTest("scl4613", Array("moveRefactoring.foo.B"), "moveRefactoring.bar")
  }

  def testSCL4621() {
    doTest("scl4621", Array("moveRefactoring.foo.O"), "moveRefactoring.bar")
  }

  def testSCL4619() {
    doTest("scl4619", Array("foo.B"), "bar")
  }

  def testSCL4875() {
    doTest("scl4875", Array("com.A"), "org")
  }

  def testSCL4878() {
    doTest("scl4878", Array("org.B"), "com")
  }

  def testSCL4894() {
    doTest("scl4894", Array("moveRefactoring.foo.B", "moveRefactoring.foo.BB"), "moveRefactoring.bar")
  }

  def testSCL4972() {
    doTest("scl4972", Array("moveRefactoring.foo.B"), "moveRefactoring.bar")
  }

  def testSCL5456 () {
    doTest("scl5456", Array("com.A"), "org", Kinds.onlyClasses)
  }

  def testWithCompanion() {
    doTest("withCompanion", Array("source.A"), "target", Kinds.onlyClasses)
  }


  def testBothJavaAndScala() {
    doTest("bothJavaAndScala", Array("org.A", "org.J"), "com")
  }

  def testWithRelativeImport_SCL11280() {
    doTest("withRelativeImport", Array("playground.A"), "playground2")
  }

//  wait for fix SCL-6316
//  def testWithoutCompanion() {
//    doTest("withoutCompanion", Array("source.A"), "target", Kinds.onlyObjects, moveCompanion = false)
//  }


  // TODO add docs. Interim notes:
  // 1. The target package name is expected to exist in the testdata (otherwise you get NPE)
  // 2. This test seems to mix too many implementation details. Perhaps refactor into separate driver?
  // 3. As a result, it's hard to trust that this is representative of what IDEA actually DOES "in production"
  def doTest(testName: String, classNames: Array[String], newPackageName: String, mode: Kinds.Value = Kinds.all, moveCompanion: Boolean = true) {
    def findAndRefreshVFile(path: String) = {
      val vFile = LocalFileSystem.getInstance.findFileByPath(path.replace(File.separatorChar, '/'))
      VfsUtil.markDirtyAndRefresh(/*async = */false, /*recursive =*/ true, /*reloadChildren =*/true, vFile)
      vFile
    }

    val root: String = TestUtils.getTestDataPath + "/move/" + testName
    val rootBefore: String = root + "/before"
    findAndRefreshVFile(rootBefore)

    val rootDir: VirtualFile = PsiTestUtil.createTestProjectStructure(getProjectAdapter, getModuleAdapter, rootBefore, new util.HashSet[File]())
    VirtualFilePointerManager.getInstance.asInstanceOf[VirtualFilePointerManagerImpl].storePointers()
    val settings = ScalaApplicationSettings.getInstance()
    val moveCompanionOld = settings.MOVE_COMPANION
    settings.MOVE_COMPANION = moveCompanion
    try {
      performAction(classNames, newPackageName, mode)
    } finally {
      PsiTestUtil.removeSourceRoot(getModuleAdapter, rootDir)
    }
    settings.MOVE_COMPANION = moveCompanionOld
    val rootAfter: String = root + "/after"
    val rootDir2: VirtualFile = findAndRefreshVFile(rootAfter)
    VirtualFilePointerManager.getInstance.asInstanceOf[VirtualFilePointerManagerImpl].storePointers()
    getProjectAdapter.getComponent(classOf[PostprocessReformattingAspect]).doPostponedFormatting()
    PlatformTestUtil.assertDirectoriesEqual(rootDir2, rootDir, Ignores)
  }

  private def performAction(classNames: Array[String], newPackageName: String, mode: Kinds.Value) {
    val classes = new ArrayBuffer[PsiClass]()
    for (name <- classNames) {
      classes ++= ScalaPsiManager.instance(getProjectAdapter).getCachedClasses(GlobalSearchScope.allScope(getProjectAdapter), name).filter {
        case o: ScObject if o.isSyntheticObject => false
        case c: ScClass if mode == Kinds.onlyObjects => false
        case o: ScObject if mode == Kinds.onlyClasses => false
        case _ => true
      }
    }
    val aPackage: PsiPackage = JavaPsiFacade.getInstance(getProjectAdapter).findPackage(newPackageName)
    assert(aPackage != null, s"A directory must pre-exist for target package $newPackageName")
    val dirs: Array[PsiDirectory] = aPackage.getDirectories(GlobalSearchScope.moduleScope(getModuleAdapter))
    assert(dirs.length == 1)
    ScalaFileImpl.performMoveRefactoring {
      new MoveClassesOrPackagesProcessor(getProjectAdapter, classes.toArray,
        new SingleSourceRootMoveDestination(PackageWrapper.create(JavaDirectoryService.getInstance.getPackage(dirs(0))), dirs(0)), true, true, null).run()
    }
    PsiDocumentManager.getInstance(getProjectAdapter).commitAllDocuments()
  }

  object Kinds extends Enumeration {
    type Kinds = Value
    val onlyObjects, onlyClasses, all = Value
  }

  object Ignores extends VirtualFileFilter {
    override def accept(virtualFile: VirtualFile): Boolean =
      virtualFile.getName != ".gitignore"
  }
}
