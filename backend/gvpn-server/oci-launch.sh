#!/usr/bin/env bash
# Creates the G Server on Oracle Cloud from the command line, retrying every
# availability domain until Always Free A1 capacity appears. That is the
# normal way to get an A1: capacity frees up at random times.
#
#   bash oci-launch.sh            # 2 OCPU / 12 GB
#   bash oci-launch.sh 1 6        # 1 OCPU / 6 GB (fits more often)
#
# Needs the OCI CLI, set up once:  brew install oci-cli && oci setup bootstrap
# Safe to re-run: it stops if the instance already exists.
set -uo pipefail

OCPUS="${1:-2}"
MEMORY="${2:-12}"
NAME="gserver-fra-1"
SUBNET_NAME="public subnet-gvpn-net"
SSH_KEY="$HOME/.ssh/id_ed25519.pub"
WAIT_SECONDS=60
MAX_ROUNDS=600   # about 10 hours

die() { echo "ERROR: $*" >&2; exit 1; }
command -v oci >/dev/null || die "OCI CLI not found. Run: brew install oci-cli && oci setup bootstrap"
[[ -f "$SSH_KEY" ]] || die "No SSH key at $SSH_KEY"

# The tenancy OCID is the root compartment, where gvpn-net lives.
C=$(awk -F= '/^tenancy[[:space:]]*=/{gsub(/[[:space:]]/,"",$2); print $2; exit}' ~/.oci/config)
[[ -n "$C" ]] || die "No tenancy in ~/.oci/config. Run: oci setup bootstrap"

EXISTING=$(oci compute instance list -c "$C" --display-name "$NAME" --lifecycle-state RUNNING \
  --query 'data[0].id' --raw-output 2>/dev/null)
if [[ -n "$EXISTING" && "$EXISTING" != "null" ]]; then
  echo "$NAME already exists and is running: $EXISTING"
  exit 0
fi

SUBNET=$(oci network subnet list -c "$C" --display-name "$SUBNET_NAME" --query 'data[0].id' --raw-output)
[[ "$SUBNET" == ocid1.subnet* ]] || die "Subnet '$SUBNET_NAME' not found"

# Newest Ubuntu 24.04 image built for Arm (A1).
IMAGE=$(oci compute image list -c "$C" --operating-system "Canonical Ubuntu" --operating-system-version "24.04" \
  --shape VM.Standard.A1.Flex --sort-by TIMECREATED --sort-order DESC --query 'data[0].id' --raw-output)
[[ "$IMAGE" == ocid1.image* ]] || die "No Ubuntu 24.04 Arm image found"

ADS=$(oci iam availability-domain list -c "$C" --query 'data[*].name | join(`\n`, @)' --raw-output)
echo "Shape: VM.Standard.A1.Flex ${OCPUS} OCPU / ${MEMORY} GB, Ubuntu 24.04"
echo "Trying every availability domain, every ${WAIT_SECONDS}s. Ctrl+C to stop."

for ((round = 1; round <= MAX_ROUNDS; round++)); do
  while read -r AD; do
    [[ -z "$AD" ]] && continue
    echo "[$(date +%H:%M:%S)] round $round, ${AD##*:}"
    OUT=$(oci compute instance launch -c "$C" \
      --availability-domain "$AD" \
      --display-name "$NAME" \
      --shape VM.Standard.A1.Flex \
      --shape-config "{\"ocpus\": ${OCPUS}, \"memoryInGBs\": ${MEMORY}}" \
      --image-id "$IMAGE" \
      --subnet-id "$SUBNET" \
      --assign-public-ip true \
      --ssh-authorized-keys-file "$SSH_KEY" \
      --wait-for-state RUNNING \
      --query 'data.id' --raw-output 2>&1)
    # The CLI prints status lines before the id, so look for it anywhere.
    INSTANCE=$(grep -o 'ocid1\.instance[^[:space:]"]*' <<<"$OUT" | head -1)
    if [[ -n "$INSTANCE" ]]; then
      IP=$(oci compute instance list-vnics --instance-id "$INSTANCE" --query 'data[0]."public-ip"' --raw-output)
      echo
      echo "Created $NAME in ${AD##*:}"
      echo "Public IP: $IP"
      echo
      echo "Next:  IP=$IP"
      exit 0
    fi
    if ! grep -qi "capacity" <<<"$OUT"; then
      # Anything other than "out of capacity" will not fix itself by waiting.
      echo "$OUT" >&2
      die "Launch failed for a reason other than capacity (above)."
    fi
  done <<<"$ADS"
  sleep "$WAIT_SECONDS"
done
die "No capacity after $MAX_ROUNDS rounds. Try: bash oci-launch.sh 1 6"
