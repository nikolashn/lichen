module set;

import std.algorithm : all, any, filter, map, max;
import std.array : array;
import std.range : iota;
import std.sumtype;

import env;
import formula;
import syntax;
import foldconst;

const class Set {
  private alias Type = const SumType!(Empty, Finite, MultiPow, SpecSet);
  private Type val;

  this() pure nothrow @safe const { val = Empty(); }
  this(Set s1) pure nothrow @safe const { val = Finite([s1]); }
  this(Set s1, Set s2) pure nothrow @safe const { val = Finite([s1, s2]); }

  this(Set[] ss) pure nothrow @safe const {
    if (ss.length > 0)
      val = Finite(ss);
    else
      val = Empty();
  }

  this(Set domain, const Variable var, Formula formula) 
    pure nothrow @safe const 
  {
    val = SpecSet(domain, var, formula);
  }

  private this(MultiPow x) pure nothrow @safe const { val = x; }

  override string toString() pure nothrow @safe const {
    return val.match!(
      (Empty _) => "0",
      (Finite fin) => fin.toString,
      (MultiPow pow) => pow.toString,
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
      (MultiPow oPow) => oPow.domains.any!(x => subset(x)),
      (SpecSet oSpec) => 
        member(oSpec.domain) && oSpec.formula.sub(oSpec.var, this).toBool
    );
  }

  bool subset(Set o) pure @safe const {
    return val.match!(
      (Empty _) => true,
      (Finite fin) => fin.subset(o),
      (MultiPow pow) => o.val.match!(
        (Empty _) => false,
        /+ Expensive & might not be finite. +/
        (Finite _) => toFinite.subset(o),
        /+ U{P(x) : x ∈ doms} ⊆ U{P(x) : x ∈ oDoms}
           <=> ∀x ∈ doms. ∃y ∈ oDoms. x ⊆ y +/
        (MultiPow oPow) => pow.domains.all!(
          x => oPow.domains.any!(y => x.subset(y))
        ),
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
      (MultiPow pow) => toFinite.forAll(var, formula),
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

  Set binaryUnion(Set o) pure @safe const {
    return val.match!(
      (Empty _) => o,
      (Finite fin) => o.val.match!(
        (Empty _) => this,
        (Finite oFin) => new Set(fin.arr ~ oFin.arr),
        _ => o.binaryUnion(this)
      ),
      (MultiPow pow) => o.val.match!(
        (Empty _) => this,
        /+ Expensive & might not be finite. +/
        (Finite _) => toFinite.binaryUnion(o),
        (MultiPow oPow) => new Set(MultiPow(pow.domains ~ oPow.domains)),
        _ => o.binaryUnion(this)
      ),
      (SpecSet spec) => o.val.match!(
        (Empty _) => this,
        /+ o U {x ∈ dom : φ} = {x ∈ dom U o : (x ∈ dom ∧ φ) ∨ x ∈ o} +/
        (_) {
          auto x = spec.var;
          auto expr = new Expr(BinOp(BinOp.Type.LOR,
            new Expr(BinOp(BinOp.Type.LAND,
              new Expr(BinOp(BinOp.Type.MEMBER, new Expr(x), new Expr(o))),
              spec.formula.expr
            )),
            new Expr(BinOp(BinOp.Type.MEMBER, new Expr(x), new Expr(o)))
          ));
          return new Set(
            spec.domain.binaryUnion(o), x, spec.formula.reformulate(expr)
          );
        }
      )
    );
  }

  Set setUnion() pure @safe const {
    return val.match!(
      (Empty _) => new Set,
      (Finite fin) => fin.arr.foldl1!((acc, x) => acc.binaryUnion(x)),
      (MultiPow pow) => (new Set(pow.domains)).setUnion,
      (SpecSet spec) => spec.setUnion
    );
  }

  static Set makePowerSet(Set x) pure nothrow @safe {
    return new Set(MultiPow([x]));
  }

  private Set toFinite() pure @safe const
    out (s; s.val.has!Empty || s.val.has!Finite)
  {
    /+ TODO: check for finiteness +/
    return val.match!(
      (Empty _) => this,
      (Finite _) => this,
      (MultiPow pow) {
        Set[] unionArr = [];
        foreach (elem; pow.domains) {
          if (elem.val.has!Empty) {
            unionArr ~= [ new Set ];
            continue;
          }

          /+ TODO: Check for finiteness +/
          
          auto fin = elem.toFinite.val.get!Finite;
          immutable n = fin.arr.length;
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
                subset ~= fin.arr[i];
            }

            powerArr ~= new Set(subset);
          }

          /+ Add contents of P(elem) to array +/
          unionArr ~= powerArr;
        }
        return new Set(unionArr);
      },
      (SpecSet spec) => spec.domain.toFinite.val.match!(
        (Empty _) => new Set,
        (Finite fin) => new Set(
          fin.arr.filter!(x => spec.formula.sub(spec.var, x).toBool).array
        ),
        _ => assert(false)
      )
    );
  }
}

/+ Set value types +/

private const struct Empty { };

private const struct Finite {
  /+ Explicit list of finite elements +/

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
}

private const struct MultiPow {
  /+ U{P(x) : x ∈ domains} +/

  private Set[] domains; /+ Non-unique +/
  invariant { assert(domains.length > 0); }
  this(Set[] xs) pure nothrow @safe { domains = xs; }

  string toString() pure nothrow @safe const {
    string str = "P(" ~ domains[0].toString ~ ")";
    foreach (dom; domains[1..$]) {
      str ~= " U P(" ~ dom.toString ~ ")";
    }
    return str;
  }
}

private const struct SpecSet {
  /+ {var ∈ domain : formula} +/

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

  Set setUnion() pure @safe const {
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

