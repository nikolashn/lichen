import std.stdio;

import lexer;

static enum USAGE_STR =
"Usage:
  Interpret file: lichen <file>";

int main(string[] args) {
  if (args.length <= 1) {
    writeln(USAGE_STR);
    return 0;
  }

  tokenizeFileAt(args[1]);

  return 0;
}

