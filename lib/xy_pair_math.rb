module XYPairMath

  # @param [self] rhs
  # @return [Array]
  def xyp_add(rhs)
    return self.x + rhs.x, self.y + rhs.y
  end

  # @param [self] rhs 
  # @return [self]
  def xyp_add!(rhs)
    self.x+=rhs.x
    self.y+=rhs.y
    return self
  end

  # @param [self] rhs 
  # @return [Array]
  def xyp_sub(rhs)
    return self.x - rhs.x, self.y - rhs.y
  end

  # @param [self] rhs 
  # @return [self]
  def xyp_sub!(rhs)
    self.x-=rhs.x
    self.y-=rhs.y
    return self
  end

  # @param [Float, Integer] factor
  # @return [Array]
  def xyp_scale(factor)
    return self.x * factor, self.y * factor
  end

  # @param [Float, Integer] factor
  # @return [self]
  def xyp_scale!(factor)
    self.x*=factor
    self.y*=factor
    return self
  end

  # @param [Float, Integer] divisor
  # @return [Array]
  def xyp_inv_scale(divisor)
    return self.xyp_scale(1.0/(divisor))
  end

  # @param [Float, Integer] divisor
  # @return [self]
  def xyp_inv_scale!(divisor)
    return self.xyp_scale!(1.0/(divisor))
  end

  # @param [self] rhs
  # @return [Float, Integer]
  def xyp_dot(rhs)
    return self.x * rhs.x + self.y * rhs.y
  end

  # @param [Float, Integer] mag The magnitude of the resultant XYPair
  # @return [Array]
  def xyp_norm(mag=1.0)
    factor = mag / Math.sqrt(self.x * self.x + self.y * self.y)
    return self.x * factor, self.y * factor
  end

  # @param [Float, Integer] mag The magnitude of the resultant XYPair
  # @return [self]
  def xyp_norm!(mag=1.0)
    return self.xyp_scale!(mag / self.xyp_abs)
  end

  # @return [Float, Integer]
  def xyp_abs2
    return self.x * self.x + self.y * self.y
  end

  # @return [Float]
  def xyp_abs
    return Math.sqrt(self.x * self.x + self.y * self.y)
  end

  # @return [Float]
  def xyp_theta
    return Math.atan2(self.y, self.x)
  end
end

