#!/usr/bin/env bash
set -euo pipefail
mode=${1:?}; shift
case "$mode" in
    routing)
        [[ $# == 2 && $1 =~ ^[124]$ ]] || exit 2
        awk -v selected="$(($1 / 2))" '
          /^\/sys\/kernel\/debug\/rockchip-rga\/cores\/[012]\/tasks / {
            split($1,p,"/"); i=p[7]; n[i]++;
            if(NF!=2 || $2 !~ /^[0-9]+$/) bad=1;
            if(n[i]==1) before[i]=$2; else after[i]=$2;
          }
          END { for(i=0;i<3;i++) if(n[i]!=2 || after[i]-before[i]!=(i==selected ? 1000 : 0)) bad=1; exit bad; }
        ' "$2" ;;
    psnr)
        [[ $# == 2 ]] || exit 2
        awk -F, '
          BEGIN { split("nv16-nv12 bgr-nv12 scale-4k-1080p crop rotate-90 bgr-601-limited bgr-601-full bgr-709-limited bgr-709-full",names," "); for(i in names) required[names[i]]=1; }
          $2=="improcess" {
            if(NF!=5 || $3!=0 || !($1 in required) || ($5!="inf" && $5!~/^[0-9]+([.][0-9]+)?$/)) { bad=1; next; }
            if($5!="inf" && $5<30) bad=1;
            if(FILENAME==ARGV[1]) { if(++seen_base[$1]!=1) bad=1; baseline[$1]=$5; }
            else {
              if(++seen_candidate[$1]!=1 || !($1 in baseline)) bad=1;
              else if($5=="inf" || baseline[$1]=="inf") { if($5!=baseline[$1]) bad=1; }
              else { d=$5-baseline[$1]; if(d>0.01 || d< -0.01) bad=1; }
            }
          }
          END { for(name in required) if(seen_base[name]!=1 || seen_candidate[name]!=1) bad=1; exit bad; }
        ' "$1" "$2" ;;
    soak)
        [[ $# == 1 ]] || exit 2
        awk '
          /^soak-4k-nv16,/ { split($0,c,","); if(c[2]!="improcess" || c[3]!=rows || (c[5]!="inf" && (c[5]!~/^[0-9]+([.][0-9]+)?$/ || c[5]<30))) bad=1; rows++; }
          /^completed=[0-9]+ cell=soak-4k-nv16$/ { split($1,a,"="); completed=a[2]; completions++; }
          /^soak_elapsed_seconds=[0-9]+([.][0-9]+)?$/ { split($0,a,"="); elapsed=a[2]; durations++; }
          /^fd_census_before=[0-9]+ after=[0-9]+$/ { split($1,a,"="); split($2,b,"="); if(a[2]!=b[2]) bad=1; censuses++; }
          END { exit (bad || rows<1 || completed!=rows || completions!=1 || durations!=1 || elapsed<3600 || censuses!=1); }
        ' "$1" ;;
    *) exit 2 ;;
esac
