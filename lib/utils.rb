module Utils
  # @return [Array]
  # @param [Integer, Float] hue 0-360
  # @param [Integer, Float] sat 0-100
  # @param [Integer, Float] val 0-100
  def self.hsv_to_rgb(hue, sat, val)
    hue, sat, val = hue.to_f/360, sat.to_f/100, val.to_f/100
    h_i = (hue*6).to_i
    f = hue*6 - h_i
    p = val * (1 - sat)
    q = val * (1 - f*sat)
    t = val * (1 - (1 - f) * sat)
    r, g, b = val, t, p if h_i==0
    r, g, b = q, val, p if h_i==1
    r, g, b = p, val, t if h_i==2
    r, g, b = p, q, val if h_i==3
    r, g, b = t, p, val if h_i==4
    r, g, b = val, p, q if h_i==5
    [(r*255).to_i, (g*255).to_i, (b*255).to_i]
  end
end

module MatrixMath
  # @param [Array<Array<Float>>] a
  # @param [Array<Array<Float>>] b
  # @return [Array<Array<Float>>]
  def MatrixMath::dot(a, b)
    is = (0...a.length)
    js = (0...b[0].length)
    ks = (0...b.length)
    is.map do |i|
      js.map do |j|
        sum = 0
        ks.each do |k|
          sum += a[i][k] * b[k][j]
        end
        sum
      end
    end
  end
end

module VectorMath
  # @param [Array<Float>] a
  # @param [Array<Float>] b
  # @return [Array<Float>]
  def VectorMath::cross3(a, b)
    [a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0]]
  end

  # @param [Array<Float>] a
  # @param [Array<Float>] b
  # @return [Float]
  def VectorMath::sin(a, b)
    VectorMath::magnitude(VectorMath::cross3(a, b)) / ((VectorMath::magnitude(a) * VectorMath::magnitude(b)))
  end

  # @param [Array<Float>] a
  # @return [Float]
  def VectorMath::magnitude(a)
    Math.sqrt(a.map{|x|x*x}.reduce(&:plus))
  end
  # @param [Array<Float>] a
  # @return [Array<Float>]
  def VectorMath::normalize(a)
    mag = VectorMath.magnitude(a)
    a.map{|x|x/mag}
  end
  # @param [Array<Float>] a
  # @param [Float] s
  # @return [Array<Float>]
  def VectorMath::scale(a,s)
    a.map{|x|x*s}
  end

  # @param [Array<Float>] a
  # @param [Array<Float>] b
  # @return [Float]
  def VectorMath::dot(a,b)
    (0...a.length).map{|i|a[i]*b[i]}.reduce(&:plus)
  end
end