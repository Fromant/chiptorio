"""Rebuild the native Answer Engine game asset."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lab_models import build
build("answer-engine")
