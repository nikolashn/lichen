module set;

import std.algorithm;
import std.array;
import std.range;
import std.conv;
import std.sumtype;

const class Set {
  private alias Type = const SumType!(Empty, Finite, PowerSet);
  private Type val;

  private alias SatFunction = bool delegate(Set) pure @safe const;

  this() pure nothrow @safe const { val = Empty(); }
  this(Set s1) pure nothrow @safe const {
    val = Finite([s1]);
  }
  this(Set s1, Set s2) pure nothrow @safe const {
    val = Finite([s1, s2]);
  }
  this(Set[] ss) pure nothrow @safe const { val = Finite(ss); }

  private this(PowerSet x) pure nothrow @safe const { val = x; }

  override string toString() pure nothrow @safe const {
    return val.match!(
      (Empty _) => "0",
      (Finite fin) => fin.toString,
      (PowerSet pow) => pow.toString
    );
  }

  bool isEmpty() pure nothrow @safe const {
    return val.has!(const Empty);
  }

  bool member(Set o) pure nothrow @safe const {
    return o.val.match!(
      (Empty _) => false,
      (Finite oFin) => oFin.containsMember(this),
      (PowerSet oPow) => subset(oPow.max)
    );
  }

  bool subset(Set o) pure nothrow @safe const {
    return val.match!(
      (Empty _) => true,
      (Finite fin) => fin.subset(o),
      (PowerSet pow) => o.val.match!(
        (Empty _) => false,
        (Finite _) => pow.toFinite.subset(o), /+ Expensive! +/
        (PowerSet oPow) => pow.max.subset(oPow.max)
      )
    );
  }

  bool equals(Set o) pure nothrow @safe const {
    return subset(o) && o.subset(this);
  }

  bool forAll(SatFunction sat) pure @safe const {
    return val.match!(
      (Empty _) => true,
      (Finite fin) => fin.forAll(sat),
      (PowerSet pow) => pow.toFinite.forAll(sat) /+ Expensive! +/
    );
  }

  Set setUnion() pure nothrow @safe const {
    return val.match!(
      (Empty _) => new Set,
      (Finite fin) => fin.setUnion,
      (PowerSet pow) => pow.max
    );
  }

  static Set powerSet(Set x) pure nothrow @safe {
    return new Set(PowerSet(x));
  }

  /+ Set value types +/

  private const struct Empty { };

  private const struct Finite {
    private Set[] arr; /+ Non-unique +/
    invariant { assert(arr.length > 0); }
    this(Set[] xs) pure nothrow @safe { arr = xs; }

    string toString() pure nothrow @safe const {
      string[] strings = arr.map!(x => x.toString).array;
      string str = "{" ~ strings[0];
      foreach (s; strings[1..$]) {
        str ~= ", " ~ s;
      }
      return str ~ "}";
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

    bool forAll(SatFunction sat) pure @safe const {
      foreach (elem; arr) {
        if (!sat(elem)) return false;
      }
      return true;
    }

    Set setUnion() pure nothrow @safe const {
      Set[] unionArr = [];

      foreach (elem; arr) {
        elem.val.match!(
          (Empty _) {},
          (Finite fin) {
            unionArr ~= fin.arr;
          },
          (PowerSet pow) {
            unionArr ~= pow.toFinite.val.get!Finite.arr;
          }
        );
      }

      if (unionArr.length > 0)
        return new Set(unionArr);

      return new Set;
    }

    Set finitePowerSet() pure nothrow @safe const {
      immutable n = arr.length;
      bool[] config = iota(n).map!(x => false).array;

      assert(config.length == n);

      /+ Add empty set +/
      Set[] powerArr = [ new Set ];

      /+ Add non-empty subsets +/
      while (!config.all) {
        size_t j = n - 1;
        while (config[j]) {
          config[j] = false;
          j -= 1;
        }
        config[j] = true;

        Set[] subset = [];

        foreach (i; 0 .. n) {
          if (config[i])
            subset ~= arr[i];
        }

        powerArr ~= new Set(subset);
      }

      return new Set(powerArr);
    }
  }

  private const struct PowerSet {
    Set max;
    this(Set s) pure nothrow @safe const { max = s; }

    string toString() pure nothrow @safe const {
      return "P(" ~ max.toString ~ ")";
    }

    Set toFinite() pure nothrow @safe const {
      return max.val.match!(
        (Empty _) => new Set(new Set),
        (Finite fin) => fin.finitePowerSet,
        (PowerSet pow) => pow.toFinite.val.get!Finite.finitePowerSet
      );
    }
  }
}

