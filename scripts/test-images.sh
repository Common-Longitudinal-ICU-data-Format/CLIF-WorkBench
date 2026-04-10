#!/usr/bin/env bash
# =============================================================================
# Smoke tests for clif-workbench Docker images
#
# Usage:
#   ./scripts/test-images.sh ml     # Test ML image
#   ./scripts/test-images.sh ai     # Test AI image
#   ./scripts/test-images.sh all    # Test both
# =============================================================================

set -euo pipefail

IMAGE_NAME="clif-workbench"
PASSED=0
FAILED=0

run_test() {
    local tag="$1"
    local description="$2"
    local cmd="$3"

    echo -n "  [${tag}] ${description} ... "
    if docker run --rm "${IMAGE_NAME}:${tag}" python -c "${cmd}" > /dev/null 2>&1; then
        echo "PASS"
        PASSED=$((PASSED + 1))
    else
        echo "FAIL"
        FAILED=$((FAILED + 1))
    fi
}

test_ml() {
    echo "==> Testing ${IMAGE_NAME}:ml"
    run_test ml "clifpy import"       "import clifpy; print(clifpy.__version__)"
    run_test ml "pandas import"       "import pandas; print(pandas.__version__)"
    run_test ml "polars import"       "import polars; print(polars.__version__)"
    run_test ml "duckdb import"       "import duckdb; print(duckdb.__version__)"
    run_test ml "scikit-learn import" "import sklearn; print(sklearn.__version__)"
    run_test ml "statsmodels import"  "import statsmodels; print(statsmodels.__version__)"
    run_test ml "matplotlib import"   "import matplotlib; print(matplotlib.__version__)"
    run_test ml "streamlit import"    "import streamlit; print(streamlit.__version__)"
    run_test ml "uv available"        "import subprocess; subprocess.run(['uv', '--version'], check=True)"
}

test_ai() {
    echo "==> Testing ${IMAGE_NAME}:ai"
    run_test ai "clifpy import"       "import clifpy; print(clifpy.__version__)"
    run_test ai "torch import"        "import torch; print(f'torch={torch.__version__}')"
    run_test ai "transformers import" "import transformers; print(transformers.__version__)"
    run_test ai "deepspeed import"    "import deepspeed; print(deepspeed.__version__)"
    run_test ai "accelerate import"   "import accelerate; print(accelerate.__version__)"
    run_test ai "xgboost import"      "import xgboost; print(xgboost.__version__)"
    run_test ai "scikit-learn import" "import sklearn; print(sklearn.__version__)"
    run_test ai "uv available"        "import subprocess; subprocess.run(['uv', '--version'], check=True)"
}

case "${1:-}" in
    ml)
        test_ml
        ;;
    ai)
        test_ai
        ;;
    all)
        test_ml
        echo ""
        test_ai
        ;;
    *)
        echo "Usage: $0 {ml|ai|all}"
        exit 1
        ;;
esac

echo ""
echo "==> Results: ${PASSED} passed, ${FAILED} failed"
[ "${FAILED}" -eq 0 ] || exit 1
