#!/bin/env ruby

require 'matrix'

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
  
end

class ImuCalibrator
  Axes = (0..2)

  def run(file=$stdin)
    read_vectors(file)
    guess_calibration
    tune_calibration
    print_results
  end
  
  def read_vectors(file)
    @raw_readings = []
    file.each_line do |line|
      coords = line.split(/,?\s+/).reject(&:empty?).first(3).collect(&:to_i)
      @raw_readings << Vector[*coords]
    end
  end
  
  def guess_calibration
    @calibration = Axes.flat_map do |axis|
      values = @raw_readings.collect { |v| v[axis] }
      values.percentile_to_value(1, 99)
    end
    
    puts "Initial guess: #{@calibration.inspect}"
  end
  
  def tune_calibration
    puts "%-45s %7.4f %7.4f %7.4f" % [
      @calibration.inspect,
      scaled_magnitudes.average,
      scaled_magnitudes.std_deviation,
      score
    ]
  end
  
  def score
    -scaled_magnitudes.collect{ |m| (m - 1.0)**2 }.average
  end
  
  def scaled_magnitudes
    scaled_readings.collect(&:magnitude)
  end
  
  def scaled_readings
    # TODO: cache these and expire the cache when the calibration changes
    @raw_readings.collect { |r| scale r }
  end
  
  def scale(raw_reading)
    coords = raw_reading.collect.with_index do |component, axis|
      max, min = @calibration[2*axis, 2]
      (component - min)/(max - min).to_f - (max - component)/(max - min).to_f
    end
    
    Vector[*coords]
  end
  
  def print_results
    puts @calibration.inspect
  end
end

ImuCalibrator.new.run