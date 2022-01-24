import cv2

def run_util(camera):
  low = [0, 0, 0]
  high = [179, 255, 255]

  def on_update(x):
    low[0] = cv2.getTrackbarPos("low H", "controls")
    high[0] = cv2.getTrackbarPos("high H", "controls")
    low[1] = cv2.getTrackbarPos("low S", "controls")
    high[1] = cv2.getTrackbarPos("high S", "controls")
    low[2] = cv2.getTrackbarPos("low V", "controls")
    high[2] = cv2.getTrackbarPos("high V", "controls")

    print("low: ", low)
    print("high: ", high)

  cv2.namedWindow("controls", 2)
  cv2.resizeWindow("controls", 550, 10);

  cv2.createTrackbar("low H", "controls", 0, 179, on_update)
  cv2.createTrackbar("high H", "controls", 179, 179, on_update)

  cv2.createTrackbar("low S", "controls", 0, 255, on_update)
  cv2.createTrackbar("high S", "controls", 255, 255, on_update)

  cv2.createTrackbar("low V", "controls", 0, 255, on_update)
  cv2.createTrackbar("high V", "controls", 255, 255, on_update)

  stream = cv2.VideoCapture(camera)

  while stream.isOpened():
    ret, img = stream.read()
    if ret:
      hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)

      mask = cv2.inRange(hsv, tuple(low), tuple(high))
      cv2.imshow("mask", mask)

      result = cv2.bitwise_and(img, img, mask=mask)
      cv2.imshow("result", result)

      # Escape key pressed.
      k = cv2.waitKey(1) & 0xFF
      if k == 27:
        break

  cv2.destroyAllWindows()