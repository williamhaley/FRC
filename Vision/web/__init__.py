from web.web_server import run_web_server_forever

def web_server_worker(image_bytes_queue=None):
  def get_latest_image_bytes():
    return image_bytes_queue.get()

  run_web_server_forever(image_bytes_reader=get_latest_image_bytes)
