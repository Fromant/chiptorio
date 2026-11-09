"""Rebuild the editable datacenter lab preview model."""
import sys
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from lab_models import build
build("datacenter-lab")
