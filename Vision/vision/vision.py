import cv2
import json
import time

def run_vision_processing_forever(camera=None, image_update_handler=None, data_update_handler=None, vision_config_file_path=None):
  low = [0, 0, 0]
  high = [179, 255, 255]

  def __filter(image):
      hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)

      mask = cv2.inRange(hsv, tuple(low), tuple(high))
      with_mask = cv2.bitwise_and(image, image, mask=mask)

      gray = cv2.cvtColor(with_mask, cv2.COLOR_BGR2GRAY)
      threshold = cv2.threshold(gray, 128, 255, cv2.THRESH_BINARY)[1]

      result = image.copy()
      contours = cv2.findContours(threshold, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
      contours = contours[0] if len(contours) == 2 else contours[1]

      areas = []
      largest_area_index = -1

      index = 0
      for contour in contours:
          x, y, width, height = cv2.boundingRect(contour)
          areas.append({ "x": x, "y": y, "width": width, "height": height })
          area = width * height
          largest_area_index = index if area > largest_area_index else largest_area_index
          index += 1

      if largest_area_index != -1:
          largest_area = areas[largest_area_index]
          # Draw a rectangle onto the result.
          cv2.rectangle(result, (largest_area["x"], largest_area["y"]), (largest_area["x"] + largest_area["width"], largest_area["y"] + largest_area["height"]), (0, 0, 255), 2)
          # Post data to network tables.
          data_update_handler((largest_area["x"] + largest_area["width"]) * 0.5, (largest_area["y"] + largest_area["height"]) * 0.5)
      else:
          data_update_handler(-1, -1)

      return result

  stream = cv2.VideoCapture(camera)
  stream.set(cv2.CAP_PROP_FRAME_WIDTH, 640)
  stream.set(cv2.CAP_PROP_FRAME_HEIGHT, 480)

  last_check = None

  with open(vision_config_file_path) as config_file:
    while stream.isOpened():
      rc, image = stream.read()
      if not rc:
        continue

      if last_check is None or time.time() - last_check > 5:
        config_file.seek(0)
        config = json.load(config_file)
        low[0], low[1], low[2] = config["lower"]
        high[0], high[1], high[2] = config["upper"]
        last_check = time.time()

      filtered_image = __filter(image)
      image_bytes = cv2.imencode(".jpg", filtered_image)[1].tobytes()
      image_update_handler(image_bytes)
