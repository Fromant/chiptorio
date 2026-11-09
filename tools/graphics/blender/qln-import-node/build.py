"""Rebuild the native QLN import node game asset."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lab_models import build
build("qln-import-node")
