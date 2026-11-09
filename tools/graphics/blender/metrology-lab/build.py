"""Rebuild the native metrology-lab game asset."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lab_models import build
build("metrology-lab")
