module env;

import std.stdio;
import std.sumtype;

import lexer;
import set;

alias Value = const SumType!(Set, bool);

struct Env {
  private RedBlack entries;

  private this(RedBlack rb) pure nothrow @safe { entries = rb; }

  Value* find(
      const string x,
      const size_t line,
      const size_t col,
      const string path = null)
    pure @safe const
  {
    auto value = entries is null ? null : entries.find(x);
    if (value is null) {
      throw new TokenException("Used undefined identifier '" ~ x ~ "'",
        line, col, path);
    }
    return value;
  }

  Env updated(const string x, Value* v) pure nothrow @safe const {
    return Env(entries is null ? new RedBlack(x, v) : entries.updated(x, v));
  }
}

/+ Red-black tree string -> Value*
   I got annoyed with D's associative arrays so I wrote this out of spite +/
class RedBlack {
  private string key;
  private Value* value;
  private RedBlack left, right, parent;
  private enum Colour { BLACK, RED };
  private Colour colour = Colour.BLACK;

  invariant {
    assert(this.black || (left.black && right.black));
  }

  this(const string k, Value* v) pure nothrow @safe {
    key = k; value = v;
  }

  Value* find(const string x) pure nothrow @safe const {
    auto p = findRBParent(x);
    if (p is null) return this.value;
    auto search = (x < p.key) ? p.left : p.right;
    return (search is null ? null : search.value);
  }

  RedBlack updated(const string x, Value* v) pure nothrow @safe const {
    auto root = copyWithParent(null);
    auto par = root.findRBParent(x);
    auto search = (par is null) ? root : ((x < par.key) ? par.left : par.right);

    if (search !is null) {
      search.key = x;
      search.value = v;
      return root;
    }

    auto make = new RedBlack(x, v);
    make.parent = par;
    if (x < par.key)
      par.left = make;
    else
      par.right = make;

    make.colour = Colour.RED;
    while (make.parent !is null && make.red && make.parent.red) {
      RedBlack p = make.parent, a = make.aunt, gp = make.grandparent;

      if (a.red) {
        p.colour = Colour.BLACK;
        a.colour = Colour.BLACK;
        gp.colour = Colour.RED;
        make = gp;
      }
      else if (make is p.left && p is gp.left) {
        p.colour = Colour.BLACK;
        gp.colour = Colour.RED;
        make = gp.rightRotate;
      }
      else if (make is p.right && p is gp.right) {
        p.colour = Colour.BLACK;
        gp.colour = Colour.RED;
        make = gp.leftRotate;
      }
      else if (make is p.left && p is gp.right) {
        p.rightRotate;
        make = p;
      }
      else if (make is p.right && p is gp.left) {
        p.leftRotate;
        make = p;
      }
      else assert(false);

      assert(make !is null);
    }

    root = make.findRoot;
    root.colour = Colour.BLACK;

    return root;
  }

  private RedBlack findRBParent(const string x) pure nothrow @trusted const {
    RedBlack p = null;
    auto search = cast(RedBlack) this;
    while (search !is null && search.key != x) {
      p = search;
      search = (x < search.key) ? search.left : search.right;
    }
    return p;
  }

  private RedBlack copyWithParent(RedBlack p) pure nothrow @safe const {
    auto root = new RedBlack(key, value);
    root.left = left is null ? null : left.copyWithParent(root);
    root.right = right is null ? null : right.copyWithParent(root);
    root.parent = p;
    root.colour = colour;
    return root;
  }

  private RedBlack leftRotate() pure nothrow @safe 
    in (right !is null)
  {
    auto root = this.right;
    auto middle = right.left;
    auto p = this.parent;

    root.parent = p;
    if (p !is null) {
      if (this is p.left) p.left = root;
      else p.right = root;
    }

    root.left = this;
    this.parent = root;

    this.right = middle;
    if (middle !is null) middle.parent = this;

    return root;
  }

  private RedBlack rightRotate() pure nothrow @safe 
    in (left !is null)
  {
    auto root = this.left;
    auto middle = left.right;
    auto p = this.parent;

    root.parent = p;
    if (p !is null) {
      if (this is p.left) p.left = root;
      else p.right = root;
    }

    root.right = this;
    this.parent = root;

    this.left = middle;
    if (middle !is null) middle.parent = this;

    return root;
  }

  private RedBlack grandparent() pure nothrow @safe 
    in (parent !is null)
  {
    return parent.parent;
  }

  private RedBlack aunt() pure nothrow @safe 
    in (grandparent !is null)
  {
    return (parent is grandparent.left) ? grandparent.right : grandparent.left;
  }

  private RedBlack findRoot() pure nothrow @trusted const {
    auto root = cast(RedBlack) this;
    while (root.parent !is null) {
      root = root.parent;
    }
    return root;
  }
}

private static bool black(const RedBlack rb) pure nothrow @safe {
  return rb is null || rb.colour == RedBlack.Colour.BLACK;
}

private static bool red(const RedBlack rb) pure nothrow @safe {
  return !rb.black;
}

