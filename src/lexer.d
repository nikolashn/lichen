module lexer;

import std.conv;
import std.exception;
import std.file;
import std.stdio;
import std.sumtype;
import std.typecons;

struct Token {
  enum Special {
    INVALID,
    DEFINE
  }

  alias TokenVal = SumType!(char, Special, string);
  immutable TokenVal val;

  this(const char c) pure nothrow @safe { val = c; }
  this(const Special x) pure nothrow @safe { val = x; }
  this(const string x) pure nothrow @safe { val = x; }

  bool isInvalid() pure nothrow @safe const {
    return val.match!(
      (Special x) => x == Special.INVALID,
      _ => false
    );
  }

  string getIdentifier() pure nothrow @safe const {
    return val.match!(
      (string x) => x,
      _ => null
    );
  }

  bool opEquals(const Token o) pure nothrow @safe const {
    return val.match!(
      (char c) => o.val.match!(
        (char d) => c == d,
        _ => false
      ),
      (Special x) => o.val.match!(
        (Special y) => x == y,
        _ => false
      ),
      (string x) => o.val.match!(
        (string y) => x == y,
        _ => false
      )
    );
  }

  string toString() pure nothrow @safe const {
    return val.match!(
      (immutable char c) => [ c ],
      (Special x) {
        switch (x) {
          case Special.INVALID: return "[INVALID]";
          case Special.DEFINE: return ":=";
          default: assert(false);
        }
      },
      (string x) => "IDENTIFIER " ~ x
    );
  }
}

class LexerOutput {
  immutable(Token)[] tokens;
  string unread;
  size_t lines;
  size_t rows;

  void merge(const LexerOutput that) pure nothrow @safe {
    tokens ~= that.tokens;
    unread = that.unread;
    lines += that.lines;
    rows = that.lines == 0 ? rows + that.rows : that.rows;
  }
}

static immutable(Token)[] tokenizeFileAt(const string path) {
  LexerOutput output;

  try {
    output = tokenize(readText(path));
  }
  catch (Exception e) {
    throw new Exception("Error reading file at path '" ~ path ~ "'");
  }

  if (output.unread.length > 0) {
    throw new Exception("Invalid token in file at path '" ~ path ~ 
      "' on line " ~ to!string(output.lines) ~ ":" ~ to!string(output.rows));
  }
  
  return output.tokens;
}

private static Token nextToken(const string buff) pure nothrow @safe {
  if (buff == "=")
    return Token('=');
  if (buff == "<")
    return Token('<');
  if (buff == "0")
    return Token('0');
  if (buff == ";")
    return Token(';');
  if (buff == ":=")
    return Token(Token.Special.DEFINE);

  return Token(Token.Special.INVALID);
}

private static LexerOutput tokenize(const string input) pure nothrow @safe {
  auto output = new LexerOutput;
  size_t unreadIndex;
  string buff;

  foreach (i, c; input) {
    bool repeat;
    do {
      repeat = false;

      auto lines = output.lines;
      auto rows = output.rows;

      bool breakIdentifier;

      if (c == ' ' || c == '\t') {
        breakIdentifier = true;
      }
      else if (c == '\n') {
        output.lines += 1;
        output.rows = 0;
        breakIdentifier = true;
      }
      else {
        buff ~= c;
      }

      output.rows += 1;

      if (buff.length > 0) {
        auto token = nextToken(buff);

        if (token.isInvalid && breakIdentifier) {
          size_t j;
          for (j = 0; j < buff.length; ++j) {
            if (buff[j] == ';' || buff[j] == ':' || buff[j] == '=') {
              break;
            }
          }
          output.tokens ~= Token(buff[0..j]);
          buff = buff[j..$];
        }
        else if (!token.isInvalid) {
          output.tokens ~= token;
          buff = "";
        }

        if (!token.isInvalid || breakIdentifier) {
          unreadIndex = i + 1;
        }
      }
      else {
        unreadIndex = i + 1;
      }
    }
    while (repeat);
  }

  output.unread = input[unreadIndex..$];

  return output;
}

