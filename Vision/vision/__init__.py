from vision.vision import run_vision_processing_forever

def image_processing_worker(camera=None, vision_telemetry_queue=None, image_bytes_queue=None, vision_config_file_path=None):
  def image_update_handler(updated_image_bytes):
    if not image_bytes_queue.full():
      image_bytes_queue.put(updated_image_bytes)

  def data_update_handler(x, y):
    if not vision_telemetry_queue.full():
      vision_telemetry_queue.put((x, y))

  run_vision_processing_forever(camera, image_update_handler, data_update_handler, vision_config_file_path)
