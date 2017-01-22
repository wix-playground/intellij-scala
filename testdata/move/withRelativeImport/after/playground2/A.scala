package playground2

import playground.B

object A {
  import B.C
  import C.someLocal

  def method(): Unit = println(someLocal)
}