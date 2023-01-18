#!/bin/bash

[ $# -gt 0 ] && {
  commitInfo=$1
}||{
  commitInfo="update"
}

# git pull
git add .
git commit -m $commitInfo
git push origin xb
echo "https://github.com/ssbandjl/spdk/tree/xb"
# git log|head -n 20
