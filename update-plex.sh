#!/bin/bash
# tomssl.com/update-plex-server-on-ubuntu-automatically
# Uncomment the next line if the script will be run as a cron job.
# PATH=/usr/local/sbin:/usr/sbin:/sbin:$PATH 
plex_token=PUTYOURSHERE
beta_channel=false
dry_run=false
force_installation=false
overwrite_file=false
display_help=false

while getopts 'bhfno-:' opt; do
    case "$opt" in
        b) beta_channel=true ;;
        h) display_help=true ;;
        f) force_installation=true ;;
        n) dry_run=true ;;
        o) overwrite_file=true ;;
        -) case "${OPTARG}" in
             beta) beta_channel=true ;;
             dry-run) dry_run=true ;;
             force) force_installation=true ;;
             help) display_help=true ;;
             overwrite) overwrite_file=true ;;
             *) if [ "$OPTERR" = 1 ] && [ "${opt:0:1}" != ":" ]; then
                        echo "Unknown option --${OPTARG}" >&2
                        exit 1
                fi ;;
           esac ;;
        *) echo "Error: the only valid options are --beta, -b, --dry-run, -n, --force, -f, --help, -h, --overwrite, -o" >&2
           exit 1
    esac
done

if [[ $display_help == true ]]; then
  echo "usage: $0 -h, --help, -b, --beta, -f, --force, -n, --dry-run, -o, --overwrite"
  exit 2
fi

echo "Beta Channel = $beta_channel"
echo "Dry Run = $dry_run"
echo "Force Download = $force_installation"
echo "Overwrite File = $overwrite_file"

detected_arch=`dpkg --print-architecture`
case $detected_arch in
    "arm64"|"amd64"|"i386"|"armhf") echo "Architecture = $detected_arch" ;; # Plex's download page has 4 architectures available
    *) echo -e "\e[31mYour architecture is not supported by Plex! \e[0m" && exit 1 ;; # need to stop the script early if the architecture detection line fails (i.e. a user running PowerPC or any OS other than Debian/Ubuntu)
esac

if [[ $EUID -ne 0 ]]; then
    echo "$0 is not running as root. Try using sudo."
    exit 2
fi

if [ "$beta_channel" == true ]; then
    rawjson=`curl -s "https://plex.tv/api/downloads/5.json?channel=plexpass" -H "X-Plex-Token: $plex_token"`
else
    rawjson=`curl -s "https://plex.tv/api/downloads/5.json"`
fi

url=`echo $rawjson | jq -r -c '.computer.Linux.releases | .[] | select(.url | contains("'$detected_arch'")) | select(.url | contains("debian")) | .url'`
latestversion=`echo $rawjson | jq -r -c '.computer.Linux.version'`
baselatestversion=`echo $rawjson | jq -r -c '.computer.Linux.version' | cut -d'-' -f1`
installedversion=`dpkg -s plexmediaserver | grep -i '^Version' | cut -d' ' -f2`
baseinstalledversion=`dpkg -s plexmediaserver | grep -i '^Version' | cut -d' ' -f2 | cut -d'-' -f1`
echo "Latest version:    $latestversion"
echo "Installed version: $installedversion"
echo "------------------------------------------------------------"
result=$(awk -v n1="$baseinstalledversion" -v n2="$baselatestversion" 'BEGIN{ print (n1 > n2) }')
if [ "$installedversion" == "$latestversion" ]; then
  echo "Already on latest version."
elif [ "$result" == 1 ]; then
  echo "Newer version already installed."
else
  echo "Need to upgrade..."
  echo "Found latest version at $url"
  filename=${url##*/}
  if [ -f "$filename" ] && [ "$overwrite_file" == false ]; then
    echo "File already exists, not going to download it again"
  else
    echo "Downloading $filename..."
    curl -sL -o $filename $url
  fi
  if [ "$dry_run" == false ]; then
    echo "Installing it now..."
    dpkg -i $filename
    echo "$filename installed"
  fi
fi
echo "Done"
exit 0
