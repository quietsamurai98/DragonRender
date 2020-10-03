require 'lib/zif/services/tick_trace_service.rb'
$trace_service = Zif::TickTraceService.new(10)
$trace_service.reset_tick

require 'lib/xy_pair_math.rb'
require 'lib/patches.rb'
require 'lib/utils.rb'
# @param [GTK::Args] args
def tick(args)
  args.state.time ||= 0
  args.outputs.primitives << draw_tri(
      640.0 + 500.0 * Math.cos((0 * Math::PI / 3) + 2 * args.state.time / 360), 360.0 + 200.0 * Math.sin((0 * Math::PI / 3) + 3 * args.state.time / 360),
      640.0 + 500.0 * Math.cos((2 * Math::PI / 3) + 2 * args.state.time / 360), 360.0 + 200.0 * Math.sin((2 * Math::PI / 3) + 3 * args.state.time / 360),
      640.0 + 500.0 * Math.cos((4 * Math::PI / 3) + 3 * args.state.time / 360), 360.0 + 200.0 * Math.sin((4 * Math::PI / 3) + 3 * args.state.time / 360),
  )
  args.outputs.background_color = [255, 255, 255]
  args.state.time               += 1 if args.inputs.keyboard.key_held.space || true
  args.outputs.primitives << args.gtk.framerate_diagnostics_primitives
end

# @return [Array<Hash>]
# @param [Float] x1
# @param [Float] y1
# @param [Float] x2
# @param [Float] y2
# @param [Float] x3
# @param [Float] y3
# @param [Float] r
# @param [Float] g
# @param [Float] b
# @param [Float] a
def draw_tri(x1, y1, x2, y2, x3, y3, r = 0, g = 0, b = 0, a = 255)
  v1, v2, v3 = [x1, y1], [x2, y2], [x3, y3]
  v2, v3     = v3, v2 if (v2.x - v1.x) * (v3.y - v1.y) - (v2.y - v1.y) * (v3.x - v1.x) < 0
  c_i        = [0, 1, 2].max_by { |i| ([v1, v2, v3][i - 1].x - [v1, v2, v3][i - 2].x) ** 2 + ([v1, v2, v3][i - 1].y - [v1, v2, v3][i - 2].y) ** 2 }
  vc, vb, va = [v1, v2, v3].rotate(c_i)
  b_a        = [vb.x - va.x, vb.y - va.y]
  c_a        = [vc.x - va.x, vc.y - va.y]
  scale      = (c_a.x * b_a.x + c_a.y * b_a.y) / (b_a.x * b_a.x + b_a.y * b_a.y)
  d_a        = [b_a.x * scale, b_a.y * scale]
  d          = [d_a.x + va.x, d_a.y + va.y]
  h          = Math.sqrt((d_a.x - b_a.x) * (d_a.x - b_a.x) + (d_a.y - b_a.y) * (d_a.y - b_a.y))
  w          = Math.sqrt((d.x - vc.x) * (d.x - vc.x) + (d.y - vc.y) * (d.y - vc.y))
  wh         = Math.sqrt((d.x - va.x) * (d.x - va.x) + (d.y - va.y) * (d.y - va.y))
  angle1     = Math.atan2(vc.y - d.y, vc.x - d.x).to_degrees + 360
  angle2     = Math.atan2(va.y - d.y, va.x - d.x).to_degrees + 360
  [
      {
          x:              d.x,
          y:              d.y,
          w:              w,
          h:              h,
          path:           'sprites/triangle1.png', # Right triangle sprite. Lower right white, upper left transparent.
          angle_anchor_x: 0,
          angle_anchor_y: 0,
          angle:          angle1,
          r:              r,
          g:              g,
          b:              b,
          a:              a
      }.sprite,
      {
          x:              d.x,
          y:              d.y,
          w:              wh,
          h:              w,
          path:           'sprites/triangle2.png', # Right triangle sprite. Lower left white, upper right transparent.
          angle_anchor_x: 0,
          angle_anchor_y: 0,
          angle:          angle2,
          r:              r,
          g:              g,
          b:              b,
          a:              a
      }.sprite
  ]
end