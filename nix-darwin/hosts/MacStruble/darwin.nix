# M1 Pro — mid-end GPU tier
# Model: Qwen2.5-Coder 1.5B Q8_0 (~1.6 GB)
# Expected FIM latency: ~680ms (empty ctx) to ~1741ms (full 32K ctx)
# Source: llama.cpp PR #9787 M1 Pro benchmarks
{
  services.llama-server = {
    enable = true;
    hfRepo = "ggerganov/Qwen2.5-Coder-1.5B-Q8_0-GGUF";
    hfFile = "qwen2.5-coder-1.5b-q8_0.gguf";
    # All other settings use module defaults:
    #   port=8012, contextSize=32768, batchSize=1024, uBatchSize=512,
    #   gpuLayers=99, flashAttn=true, cacheReuse=256, defragThreshold="0.1"
  };
}
