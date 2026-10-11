from .camera import NODE_CLASS_MAPPINGS as CAMERA
from .texture import NODE_CLASS_MAPPINGS as TEXTURE
from .save import NODE_CLASS_MAPPINGS as SAVE

NODE_CLASS_MAPPINGS = {
    **CAMERA,
    **TEXTURE,
    **SAVE,
}

NODE_DISPLAY_NAME_MAPPINGS = {
    "PhotoCoreCameraLook": "PhotoCore Camera Look",
    "PhotoCoreSensorTexture": "PhotoCore Sensor Texture",
    "PhotoCoreSavePhoto": "PhotoCore Save Photo",
}