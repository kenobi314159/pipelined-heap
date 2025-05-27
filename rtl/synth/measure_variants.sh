#!/bin/bash -e

CONFIGURED_PERIOD=50 # ns

function parse_results() {
    proj_name="pipelined_heap"
    fit_file=${proj_name}.fit.rpt
    sta_file=${proj_name}.sta.rpt

    luts=`grep "Total logic elements" $fit_file | head -n 3 | tail -n 1 | awk '{print $6}'`
    regs=`grep "Dedicated logic registers" $fit_file | head -n 3 | tail -n 1 | awk '{print $7}'`
    labs=`grep "Total LABs:  partially or completely used" $fit_file | head -n 3 | tail -n 1 | awk '{print $9}'`
    m9ks=`grep "M9K     " $fit_file | head -n 3 | tail -n 1 | awk '{print $4}'`
    worst_path=`grep "Worst-case setup slack is" $sta_file | head -n 1 | awk '{print $7}'`

    # Print info as one line with values formatted to certain number of symbols
    python3 -c "print(f'{int($luts):>8} ; {int($regs):>8} ; {int($labs):>8} ; {int($m9ks):>8} ; {1000/(float($CONFIGURED_PERIOD)-float($worst_path)):>10.3f} ;')"
}

ITEMSS=( 1 3 7 15 31 63 127 255 511 1023 2047 4095 8191 )
TS_WIDTHS=( 8 16 32 )
META_WIDTHS=( 8 16 32 )

result_file="results.csv"

echo " ITEMS ; TS_WIDTH ; META_WIDTH ;   LUTs   ;   Regs   ;   LABs   ;   M9Ks   ;    Fmax    ;" > $result_file

for ITEMS in "${ITEMSS[@]}"; do
  for TS_WIDTH in "${TS_WIDTHS[@]}"; do
    for META_WIDTH in "${META_WIDTHS[@]}"; do
      echo "ITEMS: $ITEMS, TS_WIDTH: $TS_WIDTH, META_WIDTH: $META_WIDTH"
      # Run ful synthesis
      make clean all ITEMS=$ITEMS TS_WIDTH=$TS_WIDTH META_WIDTH=$META_WIDTH
      python3 -c "print(f'{$ITEMS:>6} ; {$TS_WIDTH:>8} ; {$META_WIDTH:>10} ; `parse_results`')" >> $result_file
    done
  done
done
