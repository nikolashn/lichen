import std.stdio;

import lexer;
import parser;

static enum USAGE_STR =
"Usage:
  Interpret file: lichen <file>";

int main(string[] args) {
  if (args.length <= 1) {
    writeln(USAGE_STR);
    return 0;
  }

  auto tokens = tokenizeFileAt(args[1]);
  try {
    auto tree = tokens.parse;
  }
  catch (SyntaxException e) {
    stderr.writeln("Error: Syntax error");
  }
  catch (EOFException e) {
    stderr.writeln("Error: Unexpected end of file");
  }

  return 0;
}

