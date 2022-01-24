from networktables import NetworkTables

def run_network_tables_updater(network_tables_server_address=None, vision_telemetry_queue=None):
  print("attempt to connect to NetworkTables")
  NetworkTables.initialize(server=network_tables_server_address)
  print("connected to NetworkTables")
  network_table = NetworkTables.getTable("SmartDashboard")

  while True:
    x, y = vision_telemetry_queue.get()
    network_table.putNumber("center_x", x)
    network_table.putNumber("center_y", y)
