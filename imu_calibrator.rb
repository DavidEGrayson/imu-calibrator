#!/bin/env ruby

require 'matrix'

module Profiler    
  require 'ruby-prof'

  def run_time
    start = Time.now
    yield
    Time.now - start
  end
  
  def profile(&block)
    result = RubyProf.profile &block
    print_profile_result result
    result
  end
  
  def print_profile_result(result)
    File.open("profile.html", "w") do |file|
      RubyProf::GraphHtmlPrinter.new(result).print(file)
    end
  end
end
  
include Profiler

module Enumerable
  def percentile_to_value(*percentiles)
    sorted_values = sort
    percentiles.collect do |p|
      index = (p / 100.0 * (sorted_values.size-1)).round
      sorted_values[index]
    end
  end
  
  def average
    inject(:+) / size.to_f
  end
  
  def variance
    m = average
    sum = inject(0){|accum, i| accum + (i-m)**2 }
    sum/(size - 1).to_f
  end

  def std_deviation
    Math.sqrt variance
  end
  
  def regular_sample(num)
    each_slice(size/num).collect(&:first)
  end
  
end

class Calibration

  attr_reader :values, :raw_readings
  
  def initialize(values, raw_readings=nil)
    @values = values
    @values.freeze
    @raw_readings = raw_readings
  end
  
  def switch_readings(readings)
    self.class.new values, readings
  end
  
  def increment(value_id, change)
    new_values = values.dup
    new_values[value_id] += change
    self.class.new new_values, raw_readings
  end

  
  def score
    @score ||= -scaled_magnitudes.collect{ |m| (m - 1.0)**2 }.average
  end
  
  def scaled_magnitudes
    @scaled_magnitudes ||= scaled_readings.collect(&:magnitude)
  end
  
  def scaled_readings
    @scaled_readings ||= raw_readings.collect { |r| scale r }
  end
  
  def scale(raw_reading)
    Vector[(raw_reading[0] - values[0])/(values[1] - values[0]).to_f * 2 - 1,
      (raw_reading[1] - values[2])/(values[3] - values[2]).to_f * 2 - 1,
      (raw_reading[2] - values[4])/(values[5] - values[4]).to_f * 2 - 1]
  end

  def info_string
    "%-32s %7.4f %7.4f %7.4f" % [
      to_s,
      scaled_magnitudes.average,
      scaled_magnitudes.std_deviation,
      score
    ]
  end
  
  def to_s
    "%d %d %d %d %d %d" % values
  end
end

class ImuCalibrator
  Axes = (0..2)

  def run(file=$stdin)
    raw_readings = read_vectors(file).freeze
    raw_readings_sample = raw_readings.regular_sample(300).freeze
    cal1 = guess(raw_readings)
    cal2 = tune(cal1, raw_readings_sample)
    cal3 = tune(cal2, raw_readings)
    puts cal3
  end
  
  def read_vectors(file)
    vectors = file.each_line.collect do |line|
      coords = line.split(/,?\s+/).reject(&:empty?).first(3).collect(&:to_i)
      Vector[*coords]
    end
    
    vectors.uniq!  # save processing time
    
    vectors
  end
  
  def guess(readings)
    guess = Axes.flat_map do |axis|
      values = readings.collect { |v| v[axis] }
      values.percentile_to_value(1, 99)
    end
    Calibration.new guess
  end
  
  def tune(cal, readings)
    cal = cal.switch_readings(readings)
    $stderr.puts cal.info_string
    while true
      last_cal = cal
    
      cal.values.each_index do |value_id|
        cal = try_dir(cal, value_id, 1) || try_dir(cal, value_id, -1) || cal
      end
      $stderr.puts cal.info_string
      
      return cal if last_cal == cal
    end
  end

  def try_dir(cal, value_id, dir)
    improved_cal = nil
    while true
      new_cal = cal.increment(value_id, dir)
      return improved_cal unless new_cal.score > cal.score
      improved_cal = cal = new_cal
    end
  end
  
end

profile do
  ImuCalibrator.new.run
end