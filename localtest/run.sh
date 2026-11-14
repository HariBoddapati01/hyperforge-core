#!/usr/bin/env bash
# Test the HyperForge Terraform against a local AWS mock (moto server) —
# no Docker, no AWS account, no cost. For every profile in profiles/, it
# runs the REAL envs/test root through apply -> assert -> destroy, then
# exercises the TTL reaper's kill logic.
#
# Usage: ./run.sh            # all profiles + reaper test
#        ./run.sh kvm hyperv # just these profiles
set -euo pipefail

HERE="$(cd "$(dirname "$0")" && pwd)"
CORE="$(cd "$HERE/.." && pwd)"
PORT=5005

export AWS_REGION=us-east-2
export AWS_DEFAULT_REGION=us-east-2
export AWS_ACCESS_KEY_ID=testing
export AWS_SECRET_ACCESS_KEY=testing
export AWS_ENDPOINT_URL="http://127.0.0.1:$PORT"
export AWS_ENDPOINT_URL_S3="http://127.0.0.1:$PORT"

# --- venv with moto -----------------------------------------------------
VENV="$HERE/.venv"
if [[ ! -x "$VENV/bin/moto_server" ]]; then
  echo "== creating venv + installing moto (one-time)"
  python3 -m venv "$VENV"
  "$VENV/bin/pip" -q install --upgrade pip
  "$VENV/bin/pip" -q install 'moto[server]' boto3 pyyaml
fi

# --- start mock ---------------------------------------------------------
"$VENV/bin/moto_server" -p "$PORT" >"$HERE/moto.log" 2>&1 &
MOTO_PID=$!
cleanup() { kill "$MOTO_PID" 2>/dev/null || true; }
trap cleanup EXIT

for _ in $(seq 1 20); do
  curl -s "http://127.0.0.1:$PORT/moto-api/" >/dev/null && break
  sleep 0.5
done
echo "== moto server up (pid $MOTO_PID, port $PORT)"

# --- seed ---------------------------------------------------------------
eval "$("$VENV/bin/python" "$HERE/seed.py")"
echo "== seeded: subnet=$SEED_SUBNET_ID sg=$SEED_SG_ID"

# --- apply/assert/destroy every profile ---------------------------------
if [[ $# -gt 0 ]]; then
  PROFILES=("$@")
else
  PROFILES=()
  for f in "$CORE"/profiles/*.yaml; do PROFILES+=("$(basename "$f" .yaml)"); done
fi

BACKEND_ARGS=(
  -backend-config="bucket=hyperforge-tfstate"
  -backend-config="region=$AWS_REGION"
  -backend-config="skip_credentials_validation=true"
  -backend-config="skip_metadata_api_check=true"
  -backend-config="skip_requesting_account_id=true"
  -backend-config="use_path_style=true"
)

cd "$CORE/envs/test"
for hv in "${PROFILES[@]}"; do
  RUN_ID="local-$hv-$$"
  echo "== profile: $hv (run $RUN_ID)"
  terraform init -reconfigure -input=false \
    "${BACKEND_ARGS[@]}" -backend-config="key=runs/$RUN_ID.tfstate" >/dev/null
  terraform apply -auto-approve -input=false \
    -var "run_id=$RUN_ID" \
    -var "leg=$hv" \
    -var "subnet_id=$SEED_SUBNET_ID" \
    -var "security_group_id=$SEED_SG_ID" \
    -var "lab_image_s3_uri=s3://hyperforge-golden-images/golden/$hv/deadbeef.img" \
    >/dev/null
  "$VENV/bin/python" "$HERE/check.py" "$hv" "$RUN_ID"
  terraform destroy -auto-approve -input=false \
    -var "run_id=$RUN_ID" \
    -var "leg=$hv" \
    -var "subnet_id=$SEED_SUBNET_ID" \
    -var "security_group_id=$SEED_SG_ID" \
    -var "lab_image_s3_uri=s3://hyperforge-golden-images/golden/$hv/deadbeef.img" \
    >/dev/null
  echo "  OK: destroyed"
done

# --- reaper logic test --------------------------------------------------
echo "== reaper kill-logic test"
"$VENV/bin/python" "$HERE/reaper_test.py"

echo
echo "PASS: all profiles applied/asserted/destroyed against the local mock."
