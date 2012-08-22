from __future__ import print_function
import sys
import math

# TODO: this shouldn't work, right???  Becuase cache will not be instance-specific
# try: http://code.activestate.com/recipes/577452-a-memoize-decorator-for-instance-methods/
def memoize(f):  # change this to assume no args are provided and simplify it
  cache = {}
  def memf(*x):
    if x not in cache:
      cache[x] = f(*x)
    return cache[x]
  return memf

def average(list):
  return sum(list)/len(list)

def percentile_to_value(list, *percentiles):
  list = sorted(list)
  return [list[int(p / 100.0 * (len(list)-1))] for p in percentiles]

def variance(list):
  m = average(list)
  return sum([(i-m)**2 for i in list]) / float(len(list))

def std_deviation(list):
  return math.sqrt(variance(list))

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
      
  def magnitude(self):
    return math.sqrt(self.x**2 + self.y**2 + self.z**2)
    
Axes = range(3)

class Calibration:
  def __init__(self, values, raw_readings=None):
    self.values = values
    self.raw_readings = raw_readings

  def scale(self, raw_reading):
    return Vector((raw_reading[0] - self.values[0])/float(self.values[1] - self.values[0]) * 2 - 1,
      (raw_reading[1] - self.values[2])/float(self.values[3] - self.values[2]) * 2 - 1,
      (raw_reading[2] - self.values[4])/float(self.values[5] - self.values[4]) * 2 - 1)

  def __str__(self):
    return "%d %d %d %d %d %d" % tuple(self.values)

  def info_string(self):
    return "%-32s %7.4f %7.4f %7.4f" % (
      str(self),
      average(self.scaled_magnitudes()),
      std_deviation(self.scaled_magnitudes()),
      self.score()
    )
    
  def switch_readings(self, raw_readings):
    return Calibration(self.values, raw_readings)
  
  @memoize
  def scaled_magnitudes(self):
    return [s.magnitude() for s in self.scaled_readings()]
    
  @memoize
  def scaled_readings(self):
    return [self.scale(r) for r in self.raw_readings]
  
  @memoize
  def score(self):
    return -average([(m - 1.0)**2 for m in self.scaled_magnitudes()])
  
  def increment(self, value_id, dir):
    values = list(self.values)
    values[value_id] += dir
    return Calibration(values, self.raw_readings)
    
  
def run(file=sys.stdin):
  raw_readings = read_vectors(file)
  raw_readings_sample = raw_readings[0::(len(raw_readings)/300)]
  cal1 = guess(raw_readings)
  cal2 = tune(cal1, raw_readings_sample)
  cal3 = tune(cal2, raw_readings)  
  print(cal3)

def read_vectors(file):
  return [Vector(*[int(s) for s in line.split()[0:3]]) for line in file]

def guess(readings):
  guess = []
  for axis in Axes:
    values = [v[axis] for v in readings]
    guess.extend(percentile_to_value(values, 1, 99))
  return Calibration(guess)

def try_dir(cal, value_id, dir):
  improved_cal = None
  while True:
    new_cal = cal.increment(value_id, dir)
    if not new_cal.score() > cal.score():
      return improved_cal
    improved_cal = cal = new_cal
  return None
  
def tune(cal, readings):
  cal = cal.switch_readings(readings)
  print(cal.info_string(), file=sys.stderr)
  while True:
    last_cal = cal
    
    for value_id in range(len(cal.values)):
      cal = try_dir(cal, value_id, 1) or try_dir(cal, value_id, -1) or cal
    print(cal.info_string(), file=sys.stderr)

    if last_cal == cal:
      return cal 
    
  
  
if __name__=='__main__':
  run()