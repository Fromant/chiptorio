import importlib.util
from pathlib import Path
from types import SimpleNamespace as NS
import unittest

spec=importlib.util.spec_from_file_location('gpu_device',Path(__file__).resolve().parents[2]/'graphics/blender/gpu_device.py')
module=importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)

class Preferences:
    def __init__(self,devices):self.devices=devices
    def refresh_devices(self):pass

def scene():return NS(cycles=NS(device='CPU',denoising_use_gpu=False))
def device(name,kind):return NS(id=name,name=name,type=kind,use=True)

class DevicePolicy(unittest.TestCase):
    def test_discrete_gpu_and_gpu_denoising_only(self):
        devices=[device('AMD Radeon(TM) Graphics','HIP'),device('AMD Ryzen CPU','CPU'),device('AMD Radeon RX 9070 XT','HIP')]
        s=scene();result=module.configure_device(s,preferences=Preferences(devices))
        self.assertEqual(result['name'],'AMD Radeon RX 9070 XT')
        self.assertEqual([d.name for d in devices if d.use],['AMD Radeon RX 9070 XT'])
        self.assertEqual(s.cycles.device,'GPU');self.assertTrue(s.cycles.denoising_use_gpu)
    def test_gpu_unavailable_never_falls_back(self):
        with self.assertRaisesRegex(RuntimeError,'No CPU fallback'):
            module.configure_device(scene(),preferences=Preferences([device('CPU','CPU')]))
    def test_cpu_requires_explicit_choice(self):
        s=scene();result=module.configure_device(s,'cpu')
        self.assertEqual(result['backend'],'CPU');self.assertEqual(s.cycles.device,'CPU')
    def test_requested_gpu_must_exist(self):
        with self.assertRaisesRegex(RuntimeError,'No CPU fallback'):
            module.configure_device(scene(),gpu_name='unavailable',preferences=Preferences([device('Radeon','HIP')]))

if __name__=='__main__':unittest.main()
