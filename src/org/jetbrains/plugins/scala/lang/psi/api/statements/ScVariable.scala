package org.jetbrains.plugins.scala
package lang
package psi
package api
package statements

import javax.swing.Icon

import com.intellij.psi.tree.IElementType
import org.jetbrains.plugins.scala.icons.Icons
import org.jetbrains.plugins.scala.lang.lexer.ScalaTokenTypes.kVAR
import org.jetbrains.plugins.scala.lang.psi.api.expr.ScBlock
import org.jetbrains.plugins.scala.lang.psi.api.toplevel.templates.ScExtendsBlock
import org.jetbrains.plugins.scala.lang.psi.api.toplevel.typedef._

/**
 * @author Alexander Podkhalyuzin
 */
trait ScVariable extends ScValueOrVariable {
  override protected def keywordElementType: IElementType = kVAR

  override protected def isSimilarMemberForNavigation(member: ScMember, isStrict: Boolean): Boolean = member match {
    case other: ScVariable => super.isSimilarMemberForNavigation(other, isStrict)
    case _ => false
  }
  override def getIcon(flags: Int): Icon = {
    var parent = getParent
    while (parent != null) {
      parent match {
        case _: ScExtendsBlock => return Icons.FIELD_VAR
        case _: ScBlock => return Icons.VAR
        case _ => parent = parent.getParent
      }
    }
    null
  }
}