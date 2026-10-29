# Prints one line per requirement row in the spec files it reads:
#   ID <TAB> status <TAB> column count <TAB> file:line <TAB> verified by
# Verified by comes last because it may be empty, and bash's read merges adjacent tabs.
# A requirement row is a table row whose first cell is a backticked ID such as `AREA-12`.
# The status is the first word of the third cell, so "done (ongoing)" and "partial: gap" read
# as done and partial.
BEGIN { FS = "|"; OFS = "\t" }
/^[|] *`[A-Z]+-[0-9]+` *[|]/ {
  id = $2; gsub(/[ `]/, "", id)
  st = $4; gsub(/^ +| +$/, "", st); sub(/[ :(].*/, "", st)
  vb = ""
  if (NF >= 6) { vb = $5; gsub(/^ +| +$/, "", vb) }
  print id, st, NF - 2, FILENAME ":" FNR, vb
}
