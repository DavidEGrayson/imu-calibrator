import sys

class Vector(object):
  def __init__(self, x, y, z):
    self.x, self.y, self.z = x, y, z
  def __str__(self):
    return "(" + str(self.x) + ", " + str(self.y) + ", " + str(self.z) + ")"      

class ImuCalibrator:
  def run(self, file=sys.stdin):
    raw_readings = self.read_vectors(file)
    print raw_readings[0]
      
  def read_vectors(self, file):
    return [Vector(*[int(s) for s in line.split()[0:3]]) for line in file]
      
      
print "start"

if __name__=='__main__':
  ImuCalibrator().run()