#!/bin/bash
shopt -s extglob

while read -t 0.1 line; do
  teststrings+=( ${line} )
done

if [[ "${#teststrings}" -eq 0 ]];then
  read -r -d '' -a teststrings <<-'EOF'
  test.so.conf.test
  test.so.conf.conf.test
  test.so.confe.test
  test.so.econf.test
  conf.eps.pdf
  conf.so.ps.test
  so.test.conf.ps
  test.so.test
  test.so.d/.test
  test.so./ff/.test
	EOF
fi


cat << EOF > /tmp/testwcmatch.py
#!/usr/bin/env python3
from wcmatch import glob

import sys
import optparse

parser = optparse.OptionParser()

parser.add_option('-e', '--extglob',
  action="store", dest="extglob",
  help="extglob string", default="*")

options, args = parser.parse_args()

for line in sys.stdin.read().split('\n')[:-1]:
  if glob.globmatch(line, options.extglob, flags=glob.EXTGLOB):
    print('+++ ' + line)
  else:
    print('--- ' + line)
EOF
chmod +x /tmp/testwcmatch.py

patterns="$@"

for pattern in "$@";do
  echo -e "\nExtglob pattern: ${pattern}\n"
  sdiff <(
    while read -r -d $'\n' line;do
      [[ "$line" == $pattern ]] && echo -e "+++ ${line}" || echo "--- ${line}"
    done < <(printf "%s\n" "${teststrings[@]}")
  ) <(
    printf "%s\n" "${teststrings[@]}" | /tmp/testwcmatch.py --extglob "${pattern}"
  )
done
