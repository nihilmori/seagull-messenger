#include <cstdint>
#include <string>

#include <benchmark/benchmark.h>
#include <userver/engine/run_standalone.hpp>

void PlaceholderBenchmark(benchmark::State& state) {
  userver::engine::RunStandalone([&] {
    for (auto _ : state) {
      std::string s = "seagull-messenger";
      benchmark::DoNotOptimize(s);
    }
  });
}

BENCHMARK(PlaceholderBenchmark);