#!/bin/bash
for i in {0..8}; do echo "$(tput setaf $i)this is color ${i}.$(tput sgr 0)"; done
