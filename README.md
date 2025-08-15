# GGUF Tool Suite - [![Open in Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/Thireus/GGUF-Tool-Suite/blob/main/quant_recipe_pipeline.ipynb)

**GGUF Tool Suite** is a set of flexible utilities that enables users to experiment with and create custom GGUF quantization blends. It simplifies the process of mixing quant formats (like `iq3_xxs`, `iq4_nl`, etc.) to:

- Cook GGUF recipes for any given RAM and VRAM target  
- Optimize performance  
- Reduce model size  
- Preserve accuracy across different hardware and use cases

## See for yourself

Here's how DeepSeek-R1-0528 quantized with **Thireus' GGUF Tool Suite** compares to others (lower perplexity is better at the same or lower BPW):

![PPLs Compared With Others](ppl_graphs/DeepSeek-R1-0528.svg)

*The recipe_examples files are there to serve as examples of good recipes. Thireus' GGUF Tool Suite allows you to compute any quant mix recipe that follows the optimum ppl/bpw curve of this graph. Specify a target RAM and VRAM (and qtypes) specific to your computer specs, and the `quant_assign.py` script will automatically find the optimum quant mix recipe that achieves the best ppl.*

---

### ✅ Supported models

*In theory, any model supported by llama.cpp is also supported by this tool suite. However, models that are not explicitely in the models/ folder would require additional efforts such as benchmarking and quantizing the model tensors. This table provides an overview of the models officially supported.*

| **Model** | **Calibration Data** | **Quantized Shards** | **Google Colabs** | **Evaluated** | **Comments** |
|---|---|---|---|---|---|
| [DeepSeek-R1-0528](https://huggingface.co/collections/Thireus/deepseek-r1-0528-thireus-special-split-68725429aceffbd1094bdd29) | ✅ Complete | ✅ Complete | ✅ Tested and Working | ✅ Yes | Works like a charm. When the quant_assign settings are right, it produces recipes with better ppl than any other reputable GGUFs. |
| [DeepSeek-TNG-R1T2-Chimera](https://huggingface.co/collections/Thireus/deepseek-tng-r1t2-chimera-thireus-special-split-68737c17e50ee1d7fb0fc474) | ✅ Complete | ✅ Complete | ✅ Tested and Working | ⚠️ Not personally | Should not be any different than DeepSeek-R1-0528. |
| [DeepSeek-V3-0324](https://huggingface.co/collections/Thireus/deepseek-v3-0324-thireus-special-split-6885d5fba52645afa377cc79) | ✅ Complete | ✅ Complete  | ✅ Tested and Working | ⚠️ Not evaluated | Should not be any different than DeepSeek-R1-0528. Calibration data produced by @ewhacc. |
| [Kimi-K2-Instruct](https://huggingface.co/collections/Thireus/kimi-k2-instruct-thireus-special-split-68778e3701cf3e80574185e2) | ✅ Complete | ✅ Complete | ✅ Tested and Working | ✅ Tested and Working | Examples provided. It would appear that it does really well on _kt quants, likely because this is the target quant that was used for the calibration data. I may need to redo the calibration data using iq1_s_r4 to verify this theory. |
| [Qwen3-235B-A22B-Instruct-2507](https://huggingface.co/collections/Thireus/qwen3-235b-a22b-instruct-2507-thireus-special-split-68813c81fa03b52fe0d6f4e9) | ✅ Complete | ✅ Best effort (a few quants are still missing) | ⚠️ Untested | ⚠️ Not evaluated | All you need is available to produce quant mixes, but not personally tested. |
| [Qwen3-235B-A22B-Thinking-2507](https://huggingface.co/collections/Thireus/qwen3-235b-a22b-thinking-2507-thireus-special-split-688368c416e0f03b1853b10f) | ✅ Complete | ✅ Best effort (a few quants are still missing) | ✅ Tested and Working | ✅ Tested and Working | Best to use at most two tensors for `quant_assign` to choose from per tensor group. |
| [Qwen3-Coder-480B-A35B-Instruct](https://huggingface.co/collections/Thireus/qwen3-coder-480b-a35b-instruct-thireus-special-split-68813cb65745c166d0386e91) | ✅ Complete | ✅ Best effort (a few quants are still missing) | ⚠️ Untested | ⚠️ Not evaluated | Looks like [iq3_k is faulty](https://huggingface.co/Thireus/Qwen3-Coder-480B-A35B-Instruct-THIREUS-IQ3_K-SPECIAL_SPLIT/discussions/1) - avoid using it. |
| [GLM-4.5](https://huggingface.co/collections/Thireus/glm-45-thireus-special-split-6888e23853f18dd2d57a295b) | ✅ Complete | ✅ Complete | ✅ Tested and Working | ✅ Yes | GGUF format has changed as per last llama.cpp/ik_llama.cpp PR. Shards and calibration data needs to be redone. Supported in `llama.cpp` – see the discussion in [PR #14939](https://github.com/ggml-org/llama.cpp/pull/14939). You must use the latest version of `llama.cpp`/`ik_llama.cpp`. Support in `ik_llama.cpp` – see the discussion in [ikawrakow/ik_llama.cpp#668](https://github.com/ikawrakow/ik_llama.cpp/pull/668) |
| [GLM-4.5-Air](https://huggingface.co/collections/Thireus/glm-45-air-thireus-special-split-688f9936d839ef353d92426a) | ✅ Complete | ✅ Complete | ✅ Tested and Working | ✅ Yes | You must use the latest version of `llama.cpp`/`ik_llama.cpp`. Support in `llama.cpp` – see the discussion in [PR #14939](https://github.com/ggml-org/llama.cpp/pull/14939). Support in `ik_llama.cpp` – see the discussion in [ikawrakow/ik_llama.cpp#668](https://github.com/ikawrakow/ik_llama.cpp/pull/668) |

### ⚠️ Requirements

You have **four options** for using `ik_llama.cpp` or `llama.cpp`:

- You are strongly encouraged to use Linux for best results with `ik_llama.cpp` (optimum speed and ppl per model size).
- Windows users (including when using WSL2) can experiment `ik_llama.cpp` with [PR #689](https://github.com/ikawrakow/ik_llama.cpp/pull/689) which brings support to CUDA graphs for MoE models and somewhat restores high TG speed for MoE models (still lower TG speed than `llama.cpp`).

I would strongly encourage users to assess the TG and PP speed of both `ik_llama.cpp` and `llama.cpp` for their use cases, as seen [here](https://github.com/ikawrakow/ik_llama.cpp/pull/689#issuecomment-3191092917). `llama.cpp` can perform better than `ik_llama.cpp` in some use-cases!

1. **Use the Thireus fork of `ik_llama.cpp` (recommended)**  
   - **Linux**: compile as usual.  
   - **Windows builds available** but recommended to use `llama.cpp` for high context >30k and `ik_llama.cpp` for context <30k for performance reasons on MoE models. Windows users can also use [WSL2](https://documentation.ubuntu.com/wsl/stable/tutorials/develop-with-ubuntu-wsl/), see compilation instructions below, but will result in the same performance discrepencies observed:  
        <details>

        ```
        # Install CUDA Toolkit on WSL
        https://developer.nvidia.com/cuda-downloads?target_os=Linux&target_arch=x86_64&Distribution=WSL-Ubuntu&target_version=2.0&target_type=deb_network

        # Install dependencies
        pip install uv # or "apt-get install pipx", then "pipx install uv" as user # On Debian 13, or try "pipx install uv --python python3.10"

        # Not sure if all are needed (use su -)
        apt-get install libfftw3-dev ocl-icd-opencl-dev git
        apt-get install build-essential libgmp-dev libmpfr-dev libmpc-dev flex bison # Used to build gcc-14

        # Prepare env
        mkdir -p ~/AI/
        cd ~/AI/
        uv venv ./venv --python 3.12 --python-preference=only-managed

        # Activate env
        source venv/bin/activate

        # Install dependencies
        pip3 install cmake # If that fails, do: "pip3 install cmake --only-binary :all:"

        # Clone ik_llama.cpp
        git clone https://github.com/Thireus/ik_llama.cpp --recursive
        cd ik_llama.cpp
        git pull

        # Build ik_llama.cpp
        # WSL with CUDA
        cmake -B build -DGGML_NATIVE=OFF  \
        -DGGML_OPENMP=ON  \
        -DGGML_AVX2=ON  \
        -DGGML_CUDA=ON  \
        -DGGML_SCHED_MAX_COPIES=1  \
        -DGGML_CUDA_IQK_FORCE_BF16=1  \
        -DGGML_MAX_CONTEXTS=2048  \
        -DLLAMA_CURL=OFF
        cmake --build build --config Release -j16 # Adjust j to your number of CPU cores

        # (Optional) Add to PATH
        export PATH=~/AI/ik_llama.cpp/build/bin/:$PATH
        ```

        </details>

   - Source code and builds:  
     👉 https://github.com/Thireus/ik_llama.cpp/releases  

2. **Use the official `ik_llama.cpp` repo**  
   - You must compile with: `-DGGML_MAX_CONTEXTS=2048`  
   - Windows users: see notes in Option 1.  
   - Official repo:  
     👉 https://github.com/ikawrakow/ik_llama.cpp  

3. **Use the Thireus fork of `llama.cpp`**  
   - **Compatibility with GGUF shards produced by Thireus is not guaranteed or always tested**.  
   - **Windows builds available** (not affected by the MoE performance issue).  
   - Source code and builds:  
     👉 https://github.com/Thireus/llama.cpp/releases  

4. **Use `llama.cpp` from ggml-org**   
   - **Compatibility with GGUF shards produced by Thireus is not guaranteed or always tested**.  
   - **Windows users** (not affected by the MoE performance issue) but must also apply: [PR #620](https://github.com/ikawrakow/ik_llama.cpp/pull/620)  
   - Source code and builds:  
     👉 https://github.com/ggml-org/llama.cpp/releases  

### 🧠 Important: Linux `ulimit` command

Split models with a large number of files may **fail to load** unless you increase file descriptor limits.  
Run the following command on Linux/macOS **before launching llama binaries**:

```bash
# Lifts "too many open files" limitation
ulimit -n 99999
```

---

## 📁 Recipe Examples

Examples of recipes are included in the `recipe_examples` folder. Have a look at the file name or inside the recipe files to see the VRAM and RAM requirements of each.

> ⚠️ You’re encouraged to build your own recipes tailored to your setup rather than relying on others'.

---

## 📥 Download Model Shards from a Recipe

```bash
git clone https://github.com/Thireus/GGUF-Tool-Suite
cd GGUF-Tool-Suite
# Make sure to copy the relevant download.conf for the model before running quant_assign.py
rm -f download.conf
# Use the download.conf of the chosen model
cp -f models/DeepSeek-R1-0528/download.conf .
mkdir -p kitchen && cd kitchen
../quant_downloader.sh ../recipe_examples/ik_llama.cpp_recipes/DeepSeek-R1-0528.THIREUS-1.9364bpw-4.3533ppl.151GB-GGUF_11GB-GPU_140GB-CPU.3c88ec6_9fd615d.recipe
```

> 💡 **Pro tip**: Re-running `quant_downloader.sh` in the same directory will only download the **missing/different shards** from your current quant mix.

---

## 🧠 Run a Downloaded Model (Example)

```bash
ulimit -n 99999 # Required on Linux - Also make sure you have compiled ik_llama.cpp with -DGGML_MAX_CONTEXTS=2048
~/ik_llama-main-b3904-41a9c8a-bin-win-cuda-12.8-x64-avx512/llama-cli \
  -m DeepSeek-R1-0528-THIREUS-BF16-SPECIAL_TENSOR-00001-of-01148.gguf \
  -mla 3 -fa -amb 1024 -fmoe -ctk f16 -c 16384 -ngl 99 \
  -ot "blk\.(3|4|5|6)\.ffn_.*=CUDA0" \
  -ot "blk\.(7|8|9)\.ffn_.*=CUDA1" \
  -ot "blk\.(10|11|12)\.ffn_.*=CUDA2" \
  -ot exps=CPU -b 4096 -ub 4096 --warmup-batch --no-mmap --threads 36 \
  --main-gpu 0 \
  -p '<｜begin▁of▁sentence｜><｜User｜>What is the solution of x+5=-2?<｜Assistant｜><think>\n'
```

---

## 🛠️ Generate a Custom Recipe for Your Config

> Recipe files can also be turned back into Google Colab pipeline parameters - [![Open in Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/Thireus/GGUF-Tool-Suite/blob/main/recipe_to_colab_params.ipynb) or locally with `recipe_to_colab_params.py`.

[Open the quant recipe pipeline notebook in Colab to create your own recipes → ](https://colab.research.google.com/github/Thireus/GGUF-Tool-Suite/blob/main/quant_recipe_pipeline.ipynb) [![Open in Colab](https://colab.research.google.com/assets/colab-badge.svg)](https://colab.research.google.com/github/Thireus/GGUF-Tool-Suite/blob/main/quant_recipe_pipeline.ipynb)

... or use `quant_assign.py` as shown below.

```bash
# Make sure to copy the relevant download.conf and ppl_results.csv for the model before running quant_assign.py
rm -f download.conf ppl_results.csv
# Use the download.conf and ppl_results.csv of the chosen model
cp -f models/DeepSeek-R1-0528/download.conf .
cp -f models/DeepSeek-R1-0528/ppl_results.csv .
# Run the quant_assign.py script (adjust the parameters to match your configuration and target model)
python quant_assign.py ppl_results.csv \
  --gpu-tensors '.*' \
  --cpu-tensors 'blk\.([3-9]|[1-5][0-9]|60)\.ffn_down_exps\.weight' \
                 'blk\.([3-9]|[1-5][0-9]|60)\.ffn_up_exps\.weight' \
                 'blk\.([3-9]|[1-5][0-9]|60)\.ffn_gate_exps\.weight' \
  --cpu-quants iq4_ks iq3_k iq2_k iq1_m_r4 \
  --gpu-quants q8_0 iq5_k_r4 iq6_k \
  --cpu-tensors-max-size 230 \
  --gpu-tensors-max-size 95% \
  --tolerance 0.01 \
  --exponential-factor 8 \
  --gpu-assign-qtype iq4_xs \
  --gpu-assign-tensors 'blk\.([0-9]|[1-5][0-9]|60)\.attn_k_b\.weight=q8_0' \
  | ./quants_regex_merger.sh \
    --model-name "recipe_examples/ik_llama.cpp_recipes/DeepSeek-R1-0528" \
    --add-ppl 0 \
    --model-link "https://huggingface.co/deepseek-ai/DeepSeek-R1-0528"
```

> 🔧 **Adjust parameters** such as `--cpu-tensors-max-size` or `--gpu-quants` as needed for your specific hardware.

> ⚠️ q\*_K quants must be used with a capital "K" letter at the end of their name. All other quants are lowercase.

- List of quants compatible with `ik_llama.cpp`:

> iq1_bn iq1_kt iq1_m iq1_s iq1_s_r4 iq2_bn iq2_bn_r4 iq2_k iq2_k_r4 iq2_kl iq2_ks iq2_kt iq2_m iq2_m_r4 iq2_s iq2_xs iq2_xs_r4 iq2_xxs iq2_xxs_r4 iq3_k iq3_k_r4 iq3_kl iq3_ks iq3_kt iq3_m iq3_s iq3_s_r4 iq3_xs iq3_xxs iq3_xxs_r4 iq4_k iq4_k_r4 iq4_ks iq4_ks_r4 iq4_kss iq4_kt iq4_nl iq4_nl_r4 iq4_xs iq4_xs_r8 iq5_k iq5_k_r4 iq5_ks iq5_ks_r4 iq6_k q1_m_r4 q2_K q2_k_r4 q2_k_s q3_K q3_k_l q3_k_m q3_k_r4 q3_k_s q4_0 q4_0_4_4 q4_0_4_8 q4_0_8_8 q4_0_r8 q4_1 q4_K q4_k_m q4_k_r4 q4_k_s q5_0 q5_0_r4 q5_1 q5_K q5_k_m q5_k_r4 q5_k_s q6_0 q6_0_r4 q6_K q6_k_r4 q8_0 q8_0_r8 q8_k_r8 q8_kv q8_kv_r8

- List of [quants compatible](https://github.com/ggml-org/llama.cpp/blob/master/tools/quantize/README.md) with `llama.cpp`:

> iq1_m iq1_s iq2_m iq2_s iq2_xs iq2_xxs iq3_m iq3_s iq3_xs iq3_xxs iq4_nl iq4_xs mxfp4_moe tq1_0 tq2_0 q2_K q2_k_s q3_K q3_k_l q3_k_m q3_k_s q4_0 q4_1 q4_K q4_k_m q4_k_s q5_0 q5_1 q5_K q5_k_m q5_k_s q6_K q8_0

---

## 📊 About `ppl_results.csv`

The file `ppl_results.csv` contains **individual tensor-level PPL benchmarks**, for example for **DeepSeek-R1-0528**:

- `Q8_0` (GPU tensors) + `IQ3-XXS` (CPU tensors)
- Target model: **DeepSeek-R1-0528**
- Quantization degradation reference: `IQ1-M-R4`

This is the **core file** used to determine optimal quant mix strategies.  
> ⚠️ Generating this CSV took **several days of GPU + CPU compute time**.

- `IQ3-XXS` was chosen for CPU tensors as it fits within **256GB RAM**
- Scripts used to generate (edit the "USER CONFIGURATION" section in the bash scripts as needed):

```bash
# Make sure to copy the relevant download.conf for the model before running quant_assign.py
rm -f download.conf
# Use the download.conf of the chosen model
cp -f models/DeepSeek-R1-0528/download.conf .
# Make sure to adjust all configuration settings from both of these scripts, such as the most important USER_REGEX variable
./benchmark_each_tensor.sh --qtypes iq1_m_r4
./collect_ppl_results.sh --chunks 250 --qtypes iq1_m_r4
```

📄 An article explaining the methodology is **coming soon**.

---

## 🙏 Acknowledgements

Big thanks to **ubergarm** for his support and for providing the invaluable **`imatrix` files**.

📄 Ubergarm's `imatrix` for DeepSeek-R1-0528 can be found here:  
🔗 [imatrix_DeepSeek-R1-0528_ubergarm.dat](https://huggingface.co/ubergarm/DeepSeek-R1-0528-GGUF/blob/main/imatrix-DeepSeek-R1-0528.dat)

📄 Ubergarm's `imatrix` for DeepSeek-TNG-R1T2-Chimera can be found here:  
🔗 [imatrix_DeepSeek-TNG-R1T2-Chimera_r1t2_ubergarm.dat](https://huggingface.co/ubergarm/DeepSeek-TNG-R1T2-Chimera-GGUF/blob/main/imatrix-DeepSeek-TNG-R1T2-Chimera-Q8_0.dat)

📄 Ubergarm's `imatrix` for Kimi-K2-Instruct can be found here:  
🔗 [imatrix_Kimi-K2-Instruct_ubergarm.dat](https://huggingface.co/ubergarm/Kimi-K2-Instruct-GGUF/blob/main/imatrix-Kimi-K2-Instruct-Q8_0.dat)

📄 Ubergarm's `imatrix` for Qwen3-235B-A22B-Instruct-2507 can be found here:  
🔗 [imatrix_Qwen3-235B-A22B-Instruct-2507_ubergarm.dat](https://huggingface.co/ubergarm/Qwen3-235B-A22B-Instruct-2507-GGUF/blob/main/imatrix-eaddario-combined-all-medium-Qwen3-235B-A22B-Instruct-2507-BF16.dat)

📄 Ubergarm's `imatrix` for Qwen3-235B-A22B-Thinking-2507 can be found here:  
🔗 [imatrix_Qwen3-235B-A22B-Thinking-2507_ubergarm.dat](https://huggingface.co/ubergarm/Qwen3-235B-A22B-Thinking-2507-GGUF/blob/main/imatrix-Qwen3-235B-A22B-Thinking-2507-BF16.dat)

📄 Ubergarm's `imatrix` for Qwen3-Coder-480B-A35B-Instruct can be found here:  
🔗 [imatrix_Qwen3-Coder-480B-A35B-Instruct_ubergarm.dat](https://huggingface.co/ubergarm/Qwen3-Coder-480B-A35B-Instruct-GGUF/blob/main/imatrix-Qwen3-Coder-480B-A35B-Instruct-Q8_0.dat)

📄 Ubergarm's `imatrix` for DeepSeek-V3-0324 can be found here:  
🔗 [imatrix_DeepSeek-V3-0324_ubergarm.dat](https://huggingface.co/ubergarm/DeepSeek-V3-0324-GGUF/blob/main/DeepSeek-V3-0324.imatrix)

📄 Ubergarm's `imatrix` for GLM-4.5 can be found here:  
🔗 [imatrix_GLM-4.5_ubergarm.dat](https://huggingface.co/ubergarm/GLM-4.5-GGUF/blob/main/imatrix-GLM-4.5-BF16.dat)

📄 Ubergarm's `imatrix` for GLM-4.5-Air can be found here:  
🔗 [imatrix_GLM-4.5-Air_ubergarm.dat](https://huggingface.co/ubergarm/GLM-4.5-Air-GGUF/blob/main/imatrix-GLM-4.5-Air-BF16.dat)

Also sincere thanks to **ikawrakow** and all **co-authors** of `ik_llama.cpp` for making this entire toolchain possible.

---

## 📜 License & Attribution

Any **use, reproduction, or modification** of this software **must give clear and visible credit** to **Thireus** and the **GGUF Tool Suite**.  
See the [LICENSE](./LICENSE) file for more details.

🔗 https://gguf.thireus.com/
