#!/usr/bin/env bash
#***************************************************************#
#** This script is part of Thireus' GGUF Tool Suite.          **#
#** create_map_file.sh is tool that creates tensors.map files **#
#** for your gguf models.                                     **#
#**                                                           **#
#** ********************************************************* **#
#** --------------- Updated: Jul-10-2025 -------------------- **#
#** ********************************************************* **#
#**                                                           **#
#** Author: Thireus <gguf@thireus.com>                        **#
#**                                                           **#
#** https://gguf.thireus.com/                                 **#
#** Thireus' GGUF Tool Suite - Quantize LLMs Like a Chef       **#
#**                                  ·     ·       ·~°          **#
#**     Λ,,Λ             ₚₚₗ  ·° ᵍᵍᵐˡ   · ɪᴋ_ʟʟᴀᴍᴀ.ᴄᴘᴘ°   ᴮᶠ¹⁶ ·  **#
#**    (:·ω·)       。··°      ·   ɢɢᴜғ   ·°·  ₕᵤ𝓰𝓰ᵢₙ𝓰𝒻ₐ𝒸ₑ   ·°   **#
#**    /    o―ヽニニフ))             · · ɪǫ3_xxs      ~·°        **#
#**    し―-J                                                   **#
#**                                                           **#
#** Copyright © 2025 - Thireus.        ₁₋ᵦᵢₜ ᵦᵣₐᵢₙ, ₃₂₋ᵦᵢₜ ₑ𝓰ₒ **#
#***************************************************************#
#**PLEASE REFER TO THE README FILE FOR ADDITIONAL INFORMATION!**#
#***************************************************************#

# Exit on error, undefined variable, or pipe failure
set -euo pipefail

# Trap SIGINT/SIGTERM for clean exit
trap 'echo "[$(date "+%Y-%m-%d %H:%M:%S")] Received termination signal. Exiting."; exit 0' SIGINT SIGTERM

#
# USER CONFIGURATION
#
# (Leave empty or add any bash vars you need here)

#
# End of user configuration
#

# Check that sha256sum is available
if ! command -v sha256sum &>/dev/null; then
    echo "Warning: 'sha256sum' not found. Entries will omit hash." >&2
    USE_SHA256=false
else
    USE_SHA256=true
fi

# Require at least one .gguf file argument
if [[ $# -lt 1 ]]; then
    echo "Usage: $0 file1.gguf [file2.gguf ...]"
    exit 1
fi

for gguf_file in "$@"; do
    # Verify file exists and is .gguf
    if [[ ! -f "$gguf_file" || "${gguf_file##*.}" != "gguf" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Skipping '$gguf_file': not a .gguf file or not found." >&2
        continue
    fi

    dir="$(dirname "$gguf_file")"
    fname="$(basename "$gguf_file")"
    map_file="$dir/tensors.map"

    # Create map file if it doesn't exist
    if [[ ! -f "$map_file" ]]; then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Creating map file: $map_file"
        : > "$map_file"
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Appending to existing map: $map_file"
    fi

    # Compute SHA256 if possible
    if [[ "$USE_SHA256" == "true" ]]; then
        file_hash="$(sha256sum "$gguf_file" | awk '{print $1}')"
    else
        file_hash=""
    fi

    echo "[$(date '+%Y-%m-%d %H:%M:%S')] Running gguf_info.py on '$fname'..."
    if gguf_info.py "$gguf_file" | \
       while IFS= read -r line; do
           # Skip headers or empty lines
           [[ "$line" =~ ^=== ]] && continue
           [[ -z "$line" ]] && continue

           # Parse tab‑delimited fields
           IFS=$'\t' read -r tensor_name field_shape field_dtype field_elements field_bytes <<< "$line"
           if [[ -z "$tensor_name" || -z "$field_shape" ]]; then
               echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: Malformed line: '$line'" >&2
               continue
           fi

           # Append entry to map:
           # filename:sha256?:tensor_name:shape=…:dtype=…:elements=…:bytes=…
           if [[ -n "$file_hash" ]]; then
               echo "${fname}:${file_hash}:${tensor_name}:${field_shape}:${field_dtype}:${field_elements}:${field_bytes}" \
                   >> "$map_file"
           else
               echo "${fname}:${file_hash}:${tensor_name}:${field_shape}:${field_dtype}:${field_elements}:${field_bytes}" \
                   >> "$map_file"
           fi
       done
    then
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] Finished processing '$fname'."
    else
        echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: gguf_info.py failed on '$fname'." >&2
    fi

done

echo "[$(date '+%Y-%m-%d %H:%M:%S')] All done."
