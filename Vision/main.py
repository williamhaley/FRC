import os
from multiprocessing import Process, Queue
from network_tables import network_tables_worker
from util import run_util
from vision import image_processing_worker
from web import web_server_worker

def vision_processing():
  try:
    camera = os.environ["CAMERA"]
    if not camera:
      print("must specify a CAMERA env var")
      exit(1)

    network_tables_server_address = os.environ["NETWORK_TABLES_SERVER_ADDRESS"]
    if not network_tables_server_address:
      print("must specify a NETWORK_TABLES_SERVER_ADDRESS env var")
      exit(1)

    vision_config_file_path = os.environ["VISION_CONFIG_FILE_PATH"]
    if not vision_config_file_path:
      print("must specify a VISION_CONFIG_FILE_PATH env var")
      exit(1)

    # Cap this to 30 for 30fps. 30 "frames" of image bytes. I wish we could have
    # the queue flush easily with a TTL (deque doesn't play work with
    # multiprocessing) or clear() a pipe or something. I found that a shared
    # list via Manager was incredibly slow.
    # If there's one flash of cached content so be it. New data will be written
    # once subscribers attach themselves.
    image_bytes_queue = Queue(30)

    vision_telemetry_queue = Queue(1)

    p1 = Process(target=image_processing_worker, kwargs={
      "camera": camera,
      "image_bytes_queue": image_bytes_queue,
      "vision_config_file_path": vision_config_file_path,
      "vision_telemetry_queue": vision_telemetry_queue
    })
    p2 = Process(target=web_server_worker, kwargs={"image_bytes_queue": image_bytes_queue})
    p3 = Process(target=network_tables_worker, kwargs={
      "network_tables_server_address": network_tables_server_address,
      "vision_telemetry_queue": vision_telemetry_queue
    })

    p1.start()
    p2.start()
    p3.start()

    p1.join()
    p2.join()
    p3.join()
  except KeyboardInterrupt:
    exit(1)

def hsv_util():
  camera = os.environ["CAMERA"]
  if not camera:
    print("must specify a CAMERA env var")
    exit(1)

  run_util(camera)

if __name__ == "__main__":
  # hsv_util()
  vision_processing()