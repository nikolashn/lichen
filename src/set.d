module set;

import std.algorithm;
import std.array;
import std.range;
import std.conv;
import std.sumtype;

import env;
import formula;
import syntax;

const class Set {
  private alias Type = const SumType!(Empty, Finite, PowerSet, SpecSet);
  private Type val;

  this() pure nothrow @safe const { val = Empty(); }
  this(Set s1) pure nothrow @safe const { val = Finite([s1]); }
  this(Set s1, Set s2) pure nothrow @safe const { val = Finite([s1, s2]); }
  this(Set[] ss) pure nothrow @safe const { val = Finite(ss); }
  this(Set domain, const Variable var, Formula formula) 
    pure nothrow @safe const 
  {
    val = SpecSet(domain, var, formula);
  }

  private this(PowerSet x) pure nothrow @safe const { val = x; }

  override string toString() pure nothrow @safe const {
    return val.match!(
      (Empty _) => "0",
      (Finite fin) => fin.toString,
      (PowerSet pow) => pow.toString,
      (SpecSet spec) => spec.toString
    );
  }

  bool isEmpty() pure nothrow @safe const {
    return val.has!(const Empty);
  }

  bool member(Set o) pure @safe const {
    return o.val.match!(
      (Empty _) => false,
      (Finite oFin) => oFin.containsMember(this),
      (PowerSet oPow) => subset(oPow.max),
      (SpecSet oSpec) => 
        member(oSpec.domain) && oSpec.formula.sub(oSpec.var, this).toBool
    );
  }

  bool subset(Set o) pure @safe const {
    return val.match!(
      (Empty _) => true,
      (Finite fin) => fin.subset(o),
      (PowerSet pow) => o.val.match!(
        (Empty _) => false,
        /+ Expensive & might not be finite. +/
        (Finite _) => pow.toFinite.subset(o),
        (PowerSet oPow) => pow.max.subset(oPow.max),
        (SpecSet oSpec) => 
          subset(oSpec.domain) && forAll(oSpec.var, oSpec.formula)
      ),
      (SpecSet spec) {
        /+ {x ∈ dom : φ} ⊆ A 
           <=> ∀x ∈ dom. (φ -> x ∈ A) 
         +/
        auto expr = makeImpliesExpr(
          spec.formula.expr,
          new Expr(BinOp(BinOp.Type.MEMBER, new Expr(spec.var), new Expr(o)))
        );
        /+ TODO: This might also use the wrong env, fix this +/
        return spec.domain.forAll(spec.var, spec.formula.reformulate(expr));
      }
    );
  }

  bool equals(Set o) pure @safe const {
    return subset(o) && o.subset(this);
  }

  bool forAll(const Variable var, Formula formula) pure @safe const {
    return val.match!(
      (Empty _) => true,
      (Finite fin) => fin.forAll(var, formula),
      /+ Expensive & also needs to be rewritten not to assume the set is finite.
         Work out formula manipulation that would be helpful here. +/
      (PowerSet pow) => pow.toFinite.forAll(var, formula),
      (SpecSet spec) {
        /+ x: var; ψ: formula; y: spec.var; φ: spec.formula; z: fresh
           ∀x ∈ {y ∈ dom : φ}. ψ 
           <=> ∀z ∈ dom. (φ[z/y] -> ψ[z/x]) +/
        auto freshCount = max(spec.formula.freshCount, formula.freshCount);
        auto fresh = makeFresh(freshCount);
        auto expr = makeImpliesExpr(
          spec.formula.rename(spec.var, fresh).expr,
          formula.rename(var, fresh).expr
        );
        /+ TODO: fix this, the wrong env is being used for ψ[z/x] +/
        return spec.domain.forAll(fresh, spec.formula.reformulate(expr));
      }
    );
  }

  Set setUnion() pure nothrow @safe const {
    return val.match!(
      (Empty _) => new Set,
      (Finite fin) => fin.setUnion,
      (PowerSet pow) => pow.max,
      (SpecSet spec) => spec.setUnion
    );
  }

  static Set powerSet(Set x) pure nothrow @safe {
    return new Set(PowerSet(x));
  }
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

  bool containsMember(Set o) pure @safe const {
    foreach (x; arr) {
      if (o.equals(x)) return true;
    }
    return false;
  }

  bool subset(Set o) pure @safe const {
    foreach (x; arr) {
      if (!x.member(o)) return false;
    }
    return true;
  }

  bool forAll(const Variable var, Formula formula) pure @safe const {
    foreach (elem; arr) {
      if (!formula.sub(var, elem).toBool) return false;
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
          /+ Expensive & might not be finite. +/
          unionArr ~= pow.toFinite.val.get!Finite.arr;
        },
        (SpecSet spec) {
          /+ TODO: implement +/
          assert(false);
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

  Set toFinite() pure nothrow @safe const
    /+ TODO: precondition of finiteness +/
  {
    return max.val.match!(
      (Empty _) => new Set(new Set),
      (Finite fin) => fin.finitePowerSet,
      /+ Expensive & might not be finite. +/
      (PowerSet pow) => pow.toFinite.val.get!Finite.finitePowerSet,
      /+ TODO: implement +/
      (SpecSet spec) => assert(false)
    );
  }
}

private const struct SpecSet {
  Set domain;
  Variable var;
  Formula formula;

  this(Set s, const Variable v, Formula f) pure nothrow @safe const {
    domain = s; var = v; formula = f;
  }

  string toString() pure nothrow @safe const {
    return "{" ~ var.name ~ " < " ~ domain.toString ~ " : " ~ 
      formula.toString ~ "}";
  }

  Set setUnion() pure nothrow @safe const {
    /+ U {x ∈ dom : φ} 
       = {x ∈ U dom : ∃z ∈ dom (x ∈ z & φ[z/x])} +/
    auto fresh = makeFresh(formula.freshCount);
    auto expr = makeExistsExpr(
      fresh,
      new Expr(domain), 
      new Expr(BinOp(BinOp.Type.LAND,
        new Expr(BinOp(BinOp.Type.MEMBER, new Expr(var), new Expr(fresh))),
        formula.rename(var, fresh).expr
      ))
    );
    return new Set(domain.setUnion, var, formula.reformulate(expr));
  }
}

