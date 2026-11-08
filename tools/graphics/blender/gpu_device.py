"""Explicit render-device policy. CPU rendering is opt-in, never a fallback."""
def configure_device(scene, mode='auto', gpu_name='', preferences=None):
    if mode == 'cpu':
        scene.cycles.device = 'CPU'
        if hasattr(scene.cycles,'denoising_use_gpu'):
            scene.cycles.denoising_use_gpu=False
        return {'name':'CPU','backend':'CPU','denoising_gpu':False}
    if preferences is None:
        import bpy
        preferences = bpy.context.preferences.addons['cycles'].preferences
    failures=[]
    for backend in (['HIP'] if mode=='hip' else ['HIP','OPTIX','CUDA','ONEAPI','METAL']):
        try:
            preferences.compute_device_type=backend
            preferences.refresh_devices()
            candidates=[d for d in preferences.devices if d.type==backend and gpu_name.lower() in d.name.lower()]
            candidates.sort(key=lambda d:(' RX ' not in d.name and 'RTX' not in d.name,d.name))
            if not candidates:
                failures.append(backend+': no matching GPU');continue
            chosen=candidates[0]
            for device in preferences.devices:
                device.use=device.id==chosen.id and device.type!='CPU'
            scene.cycles.device='GPU'
            if hasattr(scene.cycles,'denoising_use_gpu'):
                scene.cycles.denoising_use_gpu=True
            result={'name':chosen.name,'backend':backend,'denoising_gpu':getattr(scene.cycles,'denoising_use_gpu',False)}
            print('RENDER DEVICE: GPU',backend,chosen.name,'; CPU render device disabled; GPU denoising',result['denoising_gpu'],flush=True)
            return result
        except Exception as error:
            failures.append(backend+': '+str(error))
    raise RuntimeError('GPU rendering requested but unavailable. No CPU fallback. '+ '; '.join(failures))
