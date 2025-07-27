#!/usr/bin/env bash
#***************************************************************#
#** This script is part of Thireus' GGUF Tool Suite.          **#
#** Qwen3-Coder-480B-A35B-Instruct-THIREUS-ANY-SPECIAL-SMOL-q **#
#** 2_K.sh used for q2_K only. Adjust $1 in $custom!          **#
#**                                                           **#
#** ********************************************************* **#
#** --------------- Updated: Jul-27-2025 -------------------- **#
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
#** Copyright © 2025 - Thireus.        Cₕₐₜᵦₒₜₛ ₙₑₑ𝒹 ₜₕₑᵣₐₚᵧ ₜₒₒ **#
#***************************************************************#
#**PLEASE REFER TO THE README FILE FOR ADDITIONAL INFORMATION!**#
#***************************************************************#

set -euo pipefail

# Toggle debug by exporting DEBUG=1
_debug() {
  [[ "${DEBUG:-0}" -ne 1 ]] && return
  printf '[DEBUG] %s\n' "$*" >&2
}

# cat tensors.map | cut -d: -f 3,5 | sed 's/\:dtype//g' | sed 's/\./\\\./g' | ./quants_regex_merger.sh 
custom="
## Quant mix recipe created using Thireus' GGUF Tool Suite - https://gguf.thireus.com/

## Model head & embeddings — qbits: 32 16 
token_embd\.weight=$1
output\.weight=$1
output_norm\.weight=f32

## Multi-headed attention parameters — qbits: 32 16 
blk\.([0-9]|[1-5][0-9]|6[0-1])\.attn_v\.weight=$1
blk\.([0-9]|[1-5][0-9]|6[0-1])\.attn_output\.weight=$1
blk\.([0-9]|[1-5][0-9]|6[0-1])\.attn_k_norm\.weight=f32
blk\.([0-9]|[1-5][0-9]|6[0-1])\.attn_q\.weight=$1
blk\.([0-9]|[1-5][0-9]|6[0-1])\.attn_norm\.weight=f32
blk\.([0-9]|[1-5][0-9]|6[0-1])\.attn_k\.weight=$1
blk\.([0-9]|[1-5][0-9]|6[0-1])\.attn_q_norm\.weight=f32

## Core FFN weights — qbits: 32 
blk\.([0-9]|[1-5][0-9]|6[0-1])\.ffn_norm\.weight=f32
blk\.([0-9]|[1-5][0-9]|6[0-1])\.ffn_gate_inp\.weight=f32

## CPU-loaded ffn_*_exps
# ffn_down_exps (down-extraction) — qbits: 16 - Set to q2_k_r4 to prevent segfaults
blk\.([0-9]|[1-5][0-9]|6[0-1])\.ffn_down_exps\.weight=q2_k_r4

# ffn_up_exps (up-extraction) — qbits: 16 
blk\.([0-9]|[1-5][0-9]|6[0-1])\.ffn_up_exps\.weight=$1

# ffn_gate_exps (gate-extraction) — qbits: 16 
blk\.([0-9]|[1-5][0-9]|6[0-1])\.ffn_gate_exps\.weight=$1



## THE END!
"

#custom="
#blk\.8\.attn_q_b\.weight=iq5_k_r4
#blk\.33\.attn_q_b\.weight=iq5_k_r4
#blk\.59\.attn_q_b\.weight=iq5_k_r4
#blk\.60\.attn_q_b\.weight=iq5_k_r4
#"

build_range_regex() {
  local S=$1 E=$2
  # declare every variable we use
  local parts=() full_decades=() partial=()
  local run_start run_prev d u_lo u_hi low2 start_d end_d joined

  _debug "    build_range_regex S=$S E=$E"

  # (1) single digits
  if (( S <= 9 )); then
    local hi=$(( E<9?E:9 ))
    if (( S==0 && hi==9 )); then
      parts+=("[0-9]"); _debug "      add [0-9]"
    elif (( S==hi )); then
      parts+=("$S");     _debug "      add $S"
    else
      parts+=("[${S}-${hi}]"); _debug "      add [${S}-${hi}]"
    fi
  fi

  # (2) decades 10–99
  if (( E >= 10 )); then
    low2=$(( S<10?10:S ))
    start_d=$(( low2/10 ))
    end_d=$(( E/10 ))
    _debug "      decades from $start_d to $end_d"

    for ((d=start_d; d<=end_d; d++)); do
      u_lo=$(( d==start_d? low2%10:0 ))
      u_hi=$(( d==end_d  ? E%10  :9 ))
      if (( u_lo==0 && u_hi==9 )); then
        full_decades+=("$d")
        _debug "        full decade $d"
      else
        if (( u_lo==u_hi )); then
          partial+=("${d}${u_lo}")
          _debug "        partial single ${d}${u_lo}"
        else
          partial+=("${d}[${u_lo}-${u_hi}]")
          _debug "        partial range ${d}[${u_lo}-${u_hi}]"
        fi
      fi
    done

    # collapse full_decades runs
    if (( ${#full_decades[@]} )); then
      IFS=$'\n' sorted_fd=($(printf '%s\n' "${full_decades[@]}" | sort -n))
      unset IFS
      run_start=${sorted_fd[0]}; run_prev=$run_start

      for d in "${sorted_fd[@]:1}"; do
        if (( d == run_prev+1 )); then
          run_prev=$d
        else
          if (( run_start==run_prev )); then
            parts+=("${run_start}[0-9]")
            _debug "          flush ${run_start}[0-9]"
          else
            parts+=("[${run_start}-${run_prev}][0-9]")
            _debug "          flush [${run_start}-${run_prev}][0-9]"
          fi
          run_start=$d; run_prev=$d
        fi
      done
      # final flush
      if (( run_start==run_prev )); then
        parts+=("${run_start}[0-9]")
        _debug "          final ${run_start}[0-9]"
      else
        parts+=("[${run_start}-${run_prev}][0-9]")
        _debug "          final [${run_start}-${run_prev}][0-9]"
      fi
    fi

    # append partial pieces
    for p in "${partial[@]}"; do
      parts+=("$p")
      _debug "        append partial $p"
    done
  fi

  # (3) fallback for E>99
  if (( E > 99 )); then
    parts=()
    for ((i=S; i<=E; i++)); do parts+=("$i"); done
  fi

  # (4) safe join
  joined=$(printf "|%s" "${parts[@]}")
  joined=${joined:1}
  _debug "    build_range_regex returns %s" "$joined"
  printf "%s" "$joined"
}


# -------------------------------------------------------------------
# shorten_regex_list(): read stdin, collapse consecutive blk.N lines
# -------------------------------------------------------------------
shorten_regex_list() {
  local -a lines
  declare -A groups

  # Read input line by line
  while IFS= read -r line; do
    if [[ $line =~ ^blk\\.([0-9]+)\\.(.+)$ ]]; then
      # Extract block number and suffix
      block_num="${BASH_REMATCH[1]}"
      suffix="${BASH_REMATCH[2]}"
      groups["$suffix"]+="$block_num "
      _debug "Bucket $block_num → suffix $suffix"
    else
      # Non-blk line: output immediately
      printf '%s\n' "$line"
    fi
  done

  # Process each group
  for suffix in "${!groups[@]}"; do
    # Get the numbers for this suffix
    nums_str="${groups[$suffix]}"
    # Split into array
    read -ra nums <<<"$nums_str"
    # Sort and uniq
    IFS=$'\n' sorted=($(printf '%s\n' "${nums[@]}" | sort -n | uniq))
    unset IFS

    # If no numbers, skip
    if (( ${#sorted[@]} == 0 )); then
      continue
    fi

    # Break into consecutive runs
    runs=()
    run_start=${sorted[0]}
    run_prev=${sorted[0]}

    for (( i=1; i<${#sorted[@]}; i++ )); do
      num=${sorted[i]}
      if (( num == run_prev + 1 )); then
        run_prev=$num
      else
        runs+=("$run_start $run_prev")
        run_start=$num
        run_prev=$num
      fi
    done
    runs+=("$run_start $run_prev")

    # Build the regex parts for the runs
    parts=()
    for run in "${runs[@]}"; do
      read s e <<<"$run"
      if (( s == e )); then
        parts+=("$s")
        _debug "Run: single number $s"
      else
        part=$(build_range_regex "$s" "$e")
        parts+=("$part")
        _debug "Run: consecutive $s to $e -> $part"
      fi
    done

    # Join parts with '|'
    block_regex=$(IFS='|'; echo "${parts[*]}")

    # If block_regex contains '|', wrap in non-capturing group
    if [[ "$block_regex" == *"|"* ]]; then
      #block_regex="(?:$block_regex)"
      block_regex="($block_regex)"
      _debug "Wrapped block_regex: $block_regex"
    fi

    printf 'blk\\.%s\\.%s\n' "$block_regex" "$suffix"
  done
}

# -----------------------------------------------------------------------------------------
# optimise_regex_list(): read stdin, merges the residual consecutive bracket-prefix/suffix
# -----------------------------------------------------------------------------------------
optimise_regex_list() {
  local line pr inner suffix
  local -a parts plain extras final_parts nums ks
  declare -A by_suffix by_prefix pmap

  while IFS= read -r line; do
    # only lines of the form blk\.(...)\.<suffix>
    if [[ $line == blk\\.* ]] && ([[ $line == *\|\[* ]] || [[ $line == *\]\|* ]]); then
      _debug "Original line: $line"

      # 1) strip leading 'blk\.('
      pr=${line#blk\(\\.}
      # Actually we want to remove literally "blk\.("
      pr=${line#'blk\.('} 

      # 2) extract up to ')\.' as inner
      inner=${pr%%')\.'*}
      # 3) suffix is what follows ")\."
      suffix=${pr#*')\.'}

      _debug "  pr         = '$pr'"
      _debug "  inner      = '$inner'"
      _debug "  suffix     = '$suffix'"

      # 4) split alternation into parts[]
      IFS='|' read -r -a parts <<<"$inner"
      _debug "  parts      = ${parts[*]}"

      # clear collectors
      plain=(); extras=()
      by_suffix=(); by_prefix=()

      # 5) classify each part
      for p in "${parts[@]}"; do
        if [[ $p =~ ^([0-9]+)(\[[0-9]+-[0-9]+\])$ ]]; then
          local num=${BASH_REMATCH[1]}
          local su=${BASH_REMATCH[2]}
          by_suffix["$su"]+="$num "
          _debug "    by_suffix[$su] += $num"
        elif [[ $p =~ ^(\[[0-9]+-[0-9]+\])([0-9]+)$ ]]; then
          local prf=${BASH_REMATCH[1]}
          local num=${BASH_REMATCH[2]}
          by_prefix["$prf"]+="$num "
          _debug "    by_prefix[$prf] += $num"
        else
          plain+=("$p")
          _debug "    plain += $p"
        fi
      done

      # 6) merge runs in by_suffix (X[lo-hi])
      for su in "${!by_suffix[@]}"; do
        # build and sort unique nums array
        read -r -a nums <<<"${by_suffix[$su]}"
        IFS=$'\n' nums=($(printf '%s\n' "${nums[@]}" | sort -n | uniq))
        unset IFS

        # skip if no entries
        if [[ ${#nums[@]} -eq 0 ]]; then
          _debug "  no entries for suffix $su, skipping"
          continue
        fi

        _debug "  merging by_suffix[$su]: ${nums[*]}"

        # declare before assignment
        local start prev n
        start=${nums[0]}
        prev=$start

        for n in "${nums[@]:1}"; do
          if (( n == prev+1 )); then
            prev=$n
          else
            if (( start < prev )); then
              extras+=("[${start}-${prev}]$su")
              _debug "    extras += [${start}-${prev}]$su"
            else
              extras+=("${start}$su")
              _debug "    extras += ${start}$su"
            fi
            start=$n; prev=$n
          fi
        done
        # flush last
        if (( start < prev )); then
          extras+=("[${start}-${prev}]$su")
          _debug "    extras += [${start}-${prev}]$su"
        else
          extras+=("${start}$su")
          _debug "    extras += ${start}$su"
        fi
      done

      for prf in "${!by_prefix[@]}"; do
        # build and sort unique nums array
        read -r -a nums <<<"${by_prefix[$prf]}"
        IFS=$'\n' nums=($(printf '%s\n' "${nums[@]}" | sort -n | uniq))
        unset IFS

        # skip if no entries
        if [[ ${#nums[@]} -eq 0 ]]; then
          _debug "    no entries for prefix $prf, skipping"
          continue
        fi

        _debug "  merging by_prefix[$prf]: ${nums[*]}"

        # declare before assignment
        local start prev n
        start=${nums[0]}
        prev=$start

        for n in "${nums[@]:1}"; do
          if (( n == prev+1 )); then
            prev=$n
          else
            if (( start < prev )); then
              extras+=("$prf[${start}-${prev}]")
              _debug "    extras += $prf[${start}-${prev}]"
            else
              extras+=("$prf$start")
              _debug "    extras += $prf$start"
            fi
            start=$n; prev=$n
          fi
        done
        # flush last
        if (( start < prev )); then
          extras+=("$prf[${start}-${prev}]")
          _debug "    extras += $prf[${start}-${prev}]"
        else
          extras+=("$prf$start")
          _debug "    extras += $prf$start"
        fi
      done

      # 8) combine plain + extras
      final_parts=( "${plain[@]}" "${extras[@]}" )
      _debug "  final_parts = ${final_parts[*]}"

      # 9) re-assemble
      printf 'blk\.('
      ( IFS='|'; printf '%s' "${final_parts[*]}" )
      printf ')\.%s\n' "$suffix"

    else
      printf '%s\n' "$line"
    fi
  done
}

# ---------------------------------------------------------------------------------------------
# expand_ranges(): read stdin, separate regex range entries if not supported by llama-quantize
# ---------------------------------------------------------------------------------------------
expand_ranges() {
  while IFS= read -r input; do
    local prefix body suffix

    # Check for parentheses
    if [[ "$input" =~ \(.*\) ]]; then
      prefix="${input%%(*}"
      body="${input#*\(}"
      body="${body%\)*}"
      suffix="${input##*\)}"
    else
      prefix=""
      body="${input}"
      suffix=""
    fi

    # Convert [a-b] to {a..b}
    body_expanded=$(echo "$body" | sed -E 's/\[([0-9]+)-([0-9]+)\]/{\1..\2}/g')

    # Always split on | and process each line
    echo "$body_expanded" | tr '|' '\n' | while IFS= read -r part; do
      # Use brace expansion only if there are braces
      if [[ "$part" == *\{*..*\}* ]]; then
        # Escape backslashes before eval
        escaped_part="${part//\\/\\\\}"
        eval "expanded=( $escaped_part )"
        for e in "${expanded[@]}"; do
          printf '%s%s%s\n' "$prefix" "$e" "$suffix"
        done
      else
        # No brace expansion needed
        printf '%s%s%s\n' "$prefix" "$part" "$suffix"
      fi
    done
  done
}

#echo 'blk\.[0-3]\.attn_output\.weight=iq3_s' | expand_ranges
#exit

#echo "$custom" | grep -v '^#' | grep -v '^$' | shorten_regex_list | optimise_regex_list
#exit

#echo 'blk\.([0-9]|[1-5][0-9]|60)\.attn_k_b\.weight=f16' | expand_ranges
#exit

#echo "$custom" | grep -v '^#' | grep -v '^$' | sort -u
#exit

#echo 'blk\.(9|[0-2]1|[0-2]3|1[4-9]|2[0-2]|2[4-9]|3[0-2]|4[0-9]|3[4-9]|5[0-5]|58)\.attn_q_b\.weight=iq3_xxs_r4' | optimise_regex_list
#echo 'blk\.[0-3]\.attn_q_b\.weight=iq3_xxs' | optimise_regex_list
#echo 'blk\.(3|9|1[0-2]|1[4-9]|2[0-2]|2[4-9]|3[0-2]|4[0-9]|3[4-9]|5[0-5]|58)\.ffn_gate_shexp\.weight=iq3_s' | optimise_regex_list
#exit

#echo "$custom" | grep -v '^#' | grep -v '^$' | shorten_regex_list | optimise_regex_list | expand_ranges | sed -E '/=q[0-9]+_._r[0-9]+$/! s/(=q.*)/\U\1/' | sed -E '/=iq[0-9]+_._r[0-9]+$/! s/(=q.*)/\U\1/'

echo "$custom" | grep -v '^#' | grep -v '^$' | shorten_regex_list | optimise_regex_list

custom=$(
  # | sed -E '/=q[0-9]+_._r[0-9]+$/! s/(=q.*)/\U\1/' | sed -E '/=iq[0-9]+_._r[0-9]+$/! s/(=q.*)/\U\1/' | \
  echo "$custom" | grep -v '^#' | grep -v '^$' | shorten_regex_list | optimise_regex_list | \
  sed -Ez 's:\n+:,:g;s:,$::;s:^,::'
)

# Fixed argument list too long and too many open files
ulimit -S -s unlimited
ulimit -n 99999

# Qwen3-Coder-480B-A35B-Instruct-THIREUS-TEMPLATE.gguf is too big and not worth using it because Q8_0 quanitsation is fast!
mkdir Qwen3-Coder-480B-A35B-Instruct-THIREUS-${1^^}-SPECIAL_SPLIT/ && llama-quantize --keep-split \
    --custom-q "$custom" \
    --imatrix imatrix_ubergarm.dat \
    Qwen3-Coder-480B-A35B-Instruct-THIREUS-BF16-SPECIAL_SPLIT/Qwen3-Coder-480B-A35B-Instruct-THIREUS-BF16-SPECIAL_TENSOR-00001-of-00748.gguf \
    Qwen3-Coder-480B-A35B-Instruct-THIREUS-${1^^}-SPECIAL_SPLIT/Qwen3-Coder-480B-A35B-Instruct-THIREUS-${1^^}-SPECIAL_TENSOR.gguf \
    ${1^^} \
    32 && chmod 444 Qwen3-Coder-480B-A35B-Instruct-THIREUS-${1^^}-SPECIAL_SPLIT/*.gguf || echo "ERROR: Something went wrong, please check the directory doesn't already exist and that you have sufficient available disk space!"
    