#!/usr/bin/env bash
# GozVision: measured Graviton3 vs x86 benchmark on real AWS instances.
#
# Launches one Spot c7g.xlarge (Graviton3, ARM64) and one Spot c6i.xlarge
# (Intel x86_64), runs backend/benchmark_cool_graviton.py on each, downloads
# both result JSONs, merges them with backend/compare_benchmarks.py, and
# terminates the instances.
#
# Prerequisites:
#   1. AWS credentials active (run `aws login` first).
#   2. The backend/ tree committed (the script archives HEAD via git archive).
#   3. AWS CLI v2 on PATH.
#
# Usage:
#   bash scripts/run_graviton_benchmark.sh [--region eu-north-1] [--keep] [--frames 100]
#        [--arm-instance t4g.small] [--x86-instance c7i-flex.large]
# Defaults are Free-Plan-eligible types: t4g.small is AWS Graviton2 (ARM64),
# c7i-flex.large is Intel x86_64. On a paid plan, pass --arm-instance c7g.xlarge
# --x86-instance c6i.xlarge for a Graviton3-vs-c6i pair.
set -euo pipefail

# Windows-style path under Git Bash (pwd -W); plain POSIX path elsewhere.
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && (pwd -W 2>/dev/null || pwd))"
# Git Bash on Windows rewrites leading-slash arguments into file paths; the AWS
# CLI needs them verbatim (parameter paths, IAM ARNs with paths, etc.).
export MSYS_NO_PATHCONV=1
REGION="${AWS_REGION:-$(aws configure get region 2>/dev/null || echo eu-north-1)}"
FRAMES=100
KEEP=0
ARM_INSTANCE="t4g.small"
X86_INSTANCE="c7i-flex.large"
while [[ $# -gt 0 ]]; do
  case "$1" in
    --region) REGION="$2"; shift 2;;
    --keep) KEEP=1; shift;;
    --frames) FRAMES="$2"; shift 2;;
    --arm-instance) ARM_INSTANCE="$2"; shift 2;;
    --x86-instance) X86_INSTANCE="$2"; shift 2;;
    *) echo "Unknown arg: $1"; exit 1;;
  esac
done

ACCOUNT_ID="$(aws sts get-caller-identity --query Account --output text)"
BUCKET="gozvision-benchmark-${ACCOUNT_ID}"
ROLE_NAME="gozvision-benchmark-ssm"
PROFILE_NAME="${ROLE_NAME}"
TAG_KEY="project"; TAG_VAL="gozvision-benchmark"
STAMP="$(date +%Y%m%d-%H%M%S)"
WORKDIR="${REPO_ROOT}/backend/evaluation/results/aws_benchmark_${STAMP}"
mkdir -p "${WORKDIR}"

echo "=== GozVision measured Graviton benchmark ==="
echo "Region: ${REGION}   Account: ${ACCOUNT_ID}"

# ---------- 0. Verify the backend tree is committed ----------
if [[ -n "$(git -C "${REPO_ROOT}" status --porcelain backend)" ]]; then
  echo "ERROR: backend/ has uncommitted changes. Commit first so the archive is exact."; exit 1
fi
git -C "${REPO_ROOT}" archive HEAD backend -o "${WORKDIR}/backend.tar.gz"

# ---------- 1. IAM role for SSM (idempotent) ----------
TRUST_POLICY='{"Version":"2012-10-17","Statement":[{"Effect":"Allow","Principal":{"Service":"ec2.amazonaws.com"},"Action":"sts:AssumeRole"}]}'
if ! aws iam get-role --role-name "${ROLE_NAME}" >/dev/null 2>&1; then
  aws iam create-role --role-name "${ROLE_NAME}" --assume-role-policy-document "${TRUST_POLICY}" >/dev/null
  aws iam attach-role-policy --role-name "${ROLE_NAME}" \
    --policy-arn arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore >/dev/null
  sleep 10
fi
if ! aws iam get-instance-profile --instance-profile-name "${PROFILE_NAME}" >/dev/null 2>&1; then
  aws iam create-instance-profile --instance-profile-name "${PROFILE_NAME}" >/dev/null
  aws iam add-role-to-instance-profile --instance-profile-name "${PROFILE_NAME}" --role-name "${ROLE_NAME}" >/dev/null
  sleep 10
fi

# ---------- 2. Staging bucket + artifacts ----------
aws s3 mb "s3://${BUCKET}" 2>/dev/null || true
aws s3 cp "${WORKDIR}/backend.tar.gz" "s3://${BUCKET}/code/backend-${STAMP}.tar.gz" >/dev/null
MODEL_SRC="${REPO_ROOT}/backend/evaluation/dataset/raw/model-small.onnx"
if [[ ! -f "${MODEL_SRC}" ]]; then echo "ERROR: depth model not found at ${MODEL_SRC}"; exit 1; fi
aws s3 cp "${MODEL_SRC}" "s3://${BUCKET}/models/model-small.onnx" >/dev/null
CODE_URL="$(aws s3 presign "s3://${BUCKET}/code/backend-${STAMP}.tar.gz" --expires-in 3600)"
MODEL_URL="$(aws s3 presign "s3://${BUCKET}/models/model-small.onnx" --expires-in 3600)"

# ---------- 3. User data ----------
write_user_data() {
  local out="$1"
  local inst="$2"
  cat > "${out}" <<EOF
#!/bin/bash
set -euxo pipefail
dnf install -y python3.11 python3.11-pip git tar gzip
useradd -m bench 2>/dev/null || true
sudo -u bench bash -s <<'INNER'
set -euxo pipefail
export AWS_INSTANCE_TYPE="${inst}"
cd /home/bench
curl -sL "${CODE_URL}" -o backend.tar.gz
tar xzf backend.tar.gz
cd backend
curl -sL "${MODEL_URL}" -o model-small.onnx
mkdir -p evaluation/dataset/raw
mv model-small.onnx evaluation/dataset/raw/
python3.11 -m venv venv
./venv/bin/pip install -q "opencv-python-headless>=5.0.0,<5.1" "numpy>=2.0,<3"
ARCH=\$(uname -m)
LABEL="aws_\${AWS_INSTANCE_TYPE}"
./venv/bin/python benchmark_cool_graviton.py --frames ${FRAMES} --resolution 640x480 --label "\${LABEL}" --save-json benchmark_results.json
INNER
EOF
}

# ---------- 4. Launch both Spot instances ----------
launch() {
  local arch="$1" itype="$2" ud="$3"
  local param="/aws/service/ami-amazon-linux-latest/al2023-ami-kernel-6.1-${arch}"
  local ami
  ami="$(aws ssm get-parameters --names "${param}" --region "${REGION}" \
        --query 'Parameters[0].Value' --output text)"
  local sg_id
  sg_id="$(aws ec2 describe-security-groups --region "${REGION}" --filters Name=group-name,Values=default \
        --query 'SecurityGroups[0].GroupId' --output text)"
  aws ec2 run-instances --region "${REGION}" \
    --image-id "${ami}" --instance-type "${itype}" \
    --instance-market-options '{"MarketType":"spot"}' \
    --iam-instance-profile Name="${PROFILE_NAME}" \
    --security-group-ids "${sg_id}" \
    --user-data "$(cat "${ud}")" \
    --tag-specifications "ResourceType=instance,Tags=[{Key=${TAG_KEY},Value=${TAG_VAL}},{Key=type,Value=${itype}}]" \
    --query 'Instances[0].InstanceId' --output text
}

ARM_TAG="$(echo "${ARM_INSTANCE}" | tr '.' '_')"
X86_TAG="$(echo "${X86_INSTANCE}" | tr '.' '_')"
UD_ARM="${WORKDIR}/ud_${ARM_TAG}.sh"; UD_X86="${WORKDIR}/ud_${X86_TAG}.sh"
write_user_data "${UD_ARM}" "${ARM_INSTANCE}"; write_user_data "${UD_X86}" "${X86_INSTANCE}"

# Clean up any stale instances from a previous run
STALE="$(aws ec2 describe-instances --region "${REGION}" \
  --filters Name=tag:${TAG_KEY},Values=${TAG_VAL} Name=instance-state-name,Values=running,pending \
  --query 'Reservations[].Instances[].InstanceId' --output text || true)"
if [[ -n "${STALE}" ]]; then
  echo "Terminating stale instances: ${STALE}"
  aws ec2 terminate-instances --region "${REGION}" --instance-ids ${STALE} >/dev/null
  sleep 15
fi

echo "Launching ${ARM_INSTANCE} (Graviton/ARM64) and ${X86_INSTANCE} (x86) Spot instances..."
ID_ARM="$(launch arm64 "${ARM_INSTANCE}" "${UD_ARM}")"
ID_X86="$(launch x86_64 "${X86_INSTANCE}" "${UD_X86}")"
echo "ARM: ${ID_ARM}   x86: ${ID_X86}"

aws ec2 wait instance-status-ok --region "${REGION}" --instance-ids "${ID_ARM}" "${ID_X86}"

fetch_results() {
  local id="$1" out="$2"
  for attempt in $(seq 1 40); do
    if aws ssm send-command --region "${REGION}" --instance-ids "${id}" \
        --document-name "AWS-RunShellScript" \
        --parameters 'commands=["cat /home/bench/backend/benchmark_results.json"]' \
        --query 'Command.CommandId' --output text > "${WORKDIR}/cmdid" 2>/dev/null; then
      local cid; cid="$(cat "${WORKDIR}/cmdid")"
      if aws ssm wait command-executed --region "${REGION}" --command-id "${cid}" --instance-id "${id}" 2>/dev/null; then
        aws ssm get-command-invocation --region "${REGION}" --command-id "${cid}" --instance-id "${id}" \
          --query 'StandardOutputContent' --output text > "${out}"
        if grep -q '"benchmarks"' "${out}"; then echo "  fetched ${out}"; return 0; fi
      fi
    fi
    echo "  waiting for ${id} (attempt ${attempt})..."; sleep 30
  done
  echo "ERROR: could not fetch results from ${id}"; return 1
}

echo "Waiting for benchmarks to complete (this takes a few minutes)..."
fetch_results "${ID_ARM}" "${WORKDIR}/results_${ARM_TAG}.json"
fetch_results "${ID_X86}" "${WORKDIR}/results_${X86_TAG}.json"

cd "${REPO_ROOT}/backend"
py -3 compare_benchmarks.py "${WORKDIR}/results_${ARM_TAG}.json" "${WORKDIR}/results_${X86_TAG}.json" \
  | tee "${WORKDIR}/COMPARISON.txt"

cp "${WORKDIR}/results_${ARM_TAG}.json" "benchmark_results_graviton_${ARM_TAG}.json"
cp "${WORKDIR}/results_${X86_TAG}.json" "benchmark_results_x86_${X86_TAG}.json"
echo "Saved: backend/benchmark_results_graviton_${ARM_TAG}.json, backend/benchmark_results_x86_${X86_TAG}.json"

if [[ "${KEEP}" -eq 1 ]]; then
  echo "Keeping instances (--keep): ARM=${ID_ARM} x86=${ID_X86}"
else
  aws ec2 terminate-instances --region "${REGION}" --instance-ids "${ID_ARM}" "${ID_X86}" >/dev/null
  echo "Terminated both instances. Estimated spend: < \$1."
fi
echo "Done. Comparison: ${WORKDIR}/COMPARISON.txt"
