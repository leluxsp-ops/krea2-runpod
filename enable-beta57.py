#!/usr/bin/env python3
"""Idempotently register RES4LYF-style beta57 before ComfyUI starts.

Use this in addition to comfyui-obvpm. It makes the registration independent
of custom-node import order, and checks the API when the server is available.
"""
from pathlib import Path
import sys

path = Path(sys.argv[1])
marker = '# KREA2_BETA57_STARTUP_PATCH_V1'
source = path.read_text(encoding='utf-8')
if marker not in source:
    source += '''\n\n# KREA2_BETA57_STARTUP_PATCH_V1
# Equivalent to comfyui-obvpm's beta57 (alpha=0.5, beta=0.7).
from functools import partial as _krea_partial
if "beta57" not in SCHEDULER_HANDLERS:
    SCHEDULER_HANDLERS["beta57"] = SchedulerHandler(
        _krea_partial(beta_scheduler, alpha=0.5, beta=0.7)
    )
for _krea_schedulers in (SCHEDULER_NAMES, KSampler.SCHEDULERS):
    if "beta57" not in _krea_schedulers:
        _krea_schedulers.append("beta57")
'''
    path.write_text(source, encoding='utf-8')
    print('[beta57] Startup registration installed:', path)
else:
    print('[beta57] Startup registration already present:', path)
