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
