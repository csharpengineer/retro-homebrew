// A tiny test harness: CHECK records a failure and keeps going; each test file
// ends main() with DONE().
#pragma once
#include <stdio.h>

static int checks_run, checks_failed;
#define CHECK(cond, ...) do { checks_run++; if (!(cond)) { checks_failed++; \
  printf("FAIL %s:%d: ", __FILE__, __LINE__); printf(__VA_ARGS__); printf("\n"); } } while (0)
#define DONE() do { printf("%s: %d checks, %d failed\n", __FILE__, checks_run, checks_failed); \
  return checks_failed ? 1 : 0; } while (0)
