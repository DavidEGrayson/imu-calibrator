from __future__ import print_function
import sys

def average(list):
  return sum(list)/len(list)

def percentile_to_value(list, *percentiles):
  list = sorted(list)
  return [list[int(p / 100.0 * (len(list)-1))] for p in percentiles]


class Vector(object):
  def __init__(self, x, y, z):
    self.x, self.y, self.z = x, y, z
  def __str__(self):
    return "(" + str(self.x) + ", " + str(self.y) + ", " + str(self.z) + ")"      

  def __getitem__(self, key):
    if key == 0:
      return self.x
    elif key == 1:
      return self.y
    elif key == 2:
      return self.z
    else:
      raise Exception("Invalid key")
    
Axes = range(3)

class Calibration:
  def __init__(self, values, raw_readings=None):
    self.values = tuple(values)
    self.raw_readings = raw_readings

  def __str__(self):
    return "%d %d %d %d %d %d" % self.values

  def info_string(self):
    return "%-32s %7.4f %7.4f %7.4f" % (
      str(self),
      average(self.scaled_magnitudes),
      std_deviation(self.scaled_magnitudes),
      self.score()
    )
    
  def switch_readings(self, raw_readings):
    return Calibration(self.values, raw_readings)
    
  def scaled_readings(self): # TODO: memoize this!
    return [scale(r) for r in self.raw_readings]
    
  def scale(self):
     raise Exception("TODO")
  
  
def run(file=sys.stdin):
  raw_readings = read_vectors(file)
  raw_readings_sample = raw_readings[0::(len(raw_readings)/300)]
  cal1 = guess(raw_readings)
  cal2 = tune(cal1, raw_readings_sample)

def read_vectors(file):
  return [Vector(*[int(s) for s in line.split()[0:3]]) for line in file]

def guess(readings):
  guess = []
  for axis in Axes:
    values = [v[axis] for v in readings]
    guess.extend(percentile_to_value(values, 1, 99))
  return Calibration(guess)

def tune(cal, readings):
  cal = cal.switch_readings(readings)
  print(cal.info_string(), file=sys.stderr)

if __name__=='__main__':
  run()