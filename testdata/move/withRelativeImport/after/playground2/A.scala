package playground2

object A {
  import playground.B.C
  import C.someLocal

  def method(): Unit = println(someLocal)
}
