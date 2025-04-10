module set;

import std.algorithm;
import std.array;
import std.conv;
import std.sumtype;

const class Set {
  private struct Empty { };
  private struct Finite {
    Set[] arr;
    invariant { assert(arr.length > 0); }
    this(Set[] xs) pure nothrow @safe { arr = xs; }
  };

  private alias Type = const SumType!(Empty, Finite);
  private Type val;

  this() pure nothrow @safe const { val = Empty(); }
  this(Set s1) pure nothrow @safe const {
    val = Finite([s1]);
  }
  this(Set s1, Set s2) pure nothrow @safe const {
    val = Finite([s1, s2]);
  }

  override string toString() pure nothrow @safe const {
    return val.match!(
      (Empty _) => "0",
      (Finite fin) {
        string[] strings = fin.arr.map!(x => x.toString).array;
        string finString = "{ " ~ strings[0];
        foreach (s; strings[1..$]) {
          finString ~= ", " ~ s;
        }
        return finString ~ " }";
      }
    );
  }

  bool isEmpty() pure nothrow @safe const {
    return val.has!(const Empty);
  }

  bool member(Set o) pure nothrow @safe const {
    return o.val.match!(
      (Empty _) => false,
      (Finite oFin) {
        foreach (x; oFin.arr) {
          if (equals(x)) return true;
        }
        return false;
      }
    );
  }

  bool subset(Set o) pure nothrow @safe const {
    return o.val.match!(
      (Empty _) => isEmpty,
      (Finite _) {
        return val.match!(
          (Empty _) => true,
          (Finite fin) {
            foreach (x; fin.arr) {
              if (!x.member(o)) return false;
            }
            return true;
          }
        );
      }
    );
  }

  bool equals(Set o) pure nothrow @safe const {
    return subset(o) && o.subset(this);
  }
}

