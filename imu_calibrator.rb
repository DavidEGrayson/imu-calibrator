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

class Calibration
  include Comparable

  attr_reader :values, :raw_readings
  
  def initialize(values, raw_readings=nil)
    @values = values
    @values.freeze
    @raw_readings = raw_readings
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
    coords = raw_reading.collect.with_index do |component, axis|
      min, max = values[2*axis, 2]
      (component - min)/(max - min).to_f - (max - component)/(max - min).to_f  # TODO: simplify
    end
    
    Vector[*coords]
  end
  
  def increment(value_id, change)
    new_values = values.dup
    new_values[value_id] += change
    self.class.new new_values, raw_readings
  end

  def info_string
    "%-45s %7.4f %7.4f %7.4f" % [
      to_s,
      scaled_magnitudes.average,
      scaled_magnitudes.std_deviation,
      score
    ]
  end
  
  def to_s
    return values.inspect
    "%d %d %d %d %d %d" % values
  end
end

class ImuCalibrator
  Axes = (0..2)

  def run(file=$stdin)
    read_vectors(file)
    guess = guess_calibration
    cal = tune_calibration(guess)
    puts cal
  end
  
  def read_vectors(file)
    @raw_readings = []
    file.each_line do |line|
      coords = line.split(/,?\s+/).reject(&:empty?).first(3).collect(&:to_i)
      @raw_readings << Vector[*coords]
    end
    @raw_readings.freeze
  end
  
  def guess_calibration
    guess = Axes.flat_map do |axis|
      values = @raw_readings.collect { |v| v[axis] }
      values.percentile_to_value(1, 99)
    end
    Calibration.new guess, @raw_readings
  end
  
  def tune_calibration(calibration)
    $stderr.puts calibration.info_string
    while true
      last_calibration = calibration
    
      calibration.values.each_index do |value_id|
        [1, -1].each do |dir|
          puts "dir = #{dir}"
          new_cal = calibration.increment(value_id, dir)
          if new_cal.score > calibration.score
            calibration = new_cal
            while true
              new_cal = calibration.increment(value_id, dir)
              break unless new_cal.score > calibration.score
              calibration = new_cal
            end
            break
          end
        end
      end
      $stderr.puts calibration.info_string
      
      if last_calibration == calibration
        return calibration
      end
    end
  end

end

ImuCalibrator.new.run