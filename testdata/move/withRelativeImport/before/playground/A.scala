package playground

object A {
  import B.C
  import C.someLocal

  def method(): Unit = println(someLocal)
}

object B {
  object C {
    val someLocal = 15
  }
}