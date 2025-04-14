module set;

import std.algorithm;
import std.array;
import std.conv;
import std.sumtype;

const class Set {
  private struct Empty { };

  private struct Finite {
    private Set[] arr; /+ Non-unique +/

    invariant { assert(arr.length > 0); }

    this(Set[] xs) pure nothrow @safe { arr = xs; }

    string toString() pure nothrow @safe const {
      string[] strings = arr.map!(x => x.toString).array;
      string str = "{ " ~ strings[0];
      foreach (s; strings[1..$]) {
        str ~= ", " ~ s;
      }
      return str ~ " }";
    }

    bool containsMember(Set o) pure nothrow @safe const {
      foreach (x; arr) {
        if (o.equals(x)) return true;
      }
      return false;
    }

    bool subset(Set o) pure nothrow @safe const {
      foreach (x; arr) {
        if (!x.member(o)) return false;
      }
      return true;
    }

    Set setUnion() pure nothrow @safe const {
      Set[] newArr = [];

      foreach (elem; arr) {
        elem.val.match!(
          (Empty _) {},
          (Finite fin) {
            newArr ~= fin.arr;
          }
        );
      }

      if (newArr.length > 0)
        return new Set(newArr);

      return new Set;
    }
  }

  private alias Type = const SumType!(Empty, Finite);
  private Type val;

  this() pure nothrow @safe const { val = Empty(); }
  this(Set s1) pure nothrow @safe const {
    val = Finite([s1]);
  }
  this(Set s1, Set s2) pure nothrow @safe const {
    val = Finite([s1, s2]);
  }
  this(Set[] ss) pure nothrow @safe const { val = Finite(ss); }

  override string toString() pure nothrow @safe const {
    return val.match!(
      (Empty _) => "0",
      (Finite fin) => fin.toString
    );
  }

  bool isEmpty() pure nothrow @safe const {
    return val.has!(const Empty);
  }

  bool member(Set o) pure nothrow @safe const {
    return o.val.match!(
      (Empty _) => false,
      (Finite oFin) => oFin.containsMember(this)
    );
  }

  bool subset(Set o) pure nothrow @safe const {
    return o.val.match!(
      (Empty _) => isEmpty,
      (Finite _) {
        return val.match!(
          (Empty _) => true,
          (Finite fin) => fin.subset(o)
        );
      }
    );
  }

  bool equals(Set o) pure nothrow @safe const {
    return subset(o) && o.subset(this);
  }

  Set setUnion() pure nothrow @safe const {
    return val.match!(
      (Empty _) => new Set,
      (Finite fin) => fin.setUnion
    );
  }
}

