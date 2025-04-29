module foldconst;

/+ Const-friendly folds +/

template foldl(alias fun) {
  auto foldl(S, T)(S seed, T[] xs) {
    if (xs.length == 0) {
      return seed;
    }

    return foldl(fun(seed, xs[0]), xs[1..$]);
  }
}

template foldl1(alias fun) {
  auto foldl1(T)(T[] xs) {
    return foldl!(fun)(xs[0], xs[1..$]);
  }
}

