require 'lib/zif/services/tick_trace_service.rb'
$trace_service = Zif::TickTraceService.new(10)
$trace_service.reset_tick

require 'lib/xy_pair_math.rb'
require 'lib/patches.rb'
require 'lib/utils.rb'

$Scalar = 1000
$WIDTH = 16*$Scalar
$HEIGHT = 9*$Scalar
$Scale = $HEIGHT / 4
AbsControls = false
# @param [GTK::Args] args
# @return [Object, nil]
def tick(args)
  unless args.state.model
    # Load from an arbitrary `.off` file.
    args.state.model = Object3D.new({path: 'data/tri_paperplane.off'})
    # args.state.model = Object3D.new({path: 'data/tetra.off'})
     args.state.model = Object3D.new({path: 'data/triangle_teapot.off'})
    args.state.model.fast_3x3_transform!(rotate3D(0,0,-Math::PI/2))
    # Holds the current orientation of the model
    args.state.orient_mtx = rotate3D(0.00, 0.00, 0.00)
    # Holds the inverse of the current orientation of the model
    args.state.inv_orient_mtx = rotate3D(0.00, 0.00, 0.00)
    # Rotations to apply when certain buttons are pressed
    sensitivity = 10
    args.state.ctrl_mtx = {
        d: rotate3D(0.00, 0.00, 0.01*sensitivity),
        a: rotate3D(0.00, 0.00, -0.01*sensitivity),
        e: rotate3D(0.00, 0.02*sensitivity, 0.00),
        q: rotate3D(0.00, -0.02*sensitivity, 0.00),
        w: rotate3D(0.01*sensitivity, 0.00, 0.00),
        s: rotate3D(-0.01*sensitivity, 0.00, 0.00),
    }
    # Draw everything 4 times, for thicker lines
    # args.outputs.static_lines << args.state.model.edges.map(&:dupe_off)
  end
  # Black backgrounds look cooler
  args.outputs.background_color = [0, 0, 0]

  # See if we need to rotate.
  rot_flag = false
  [:d, :a, :w, :s, :q, :e].each do |key|
    rot_flag |= args.inputs.keyboard.key_held.send(key)
  end

  if rot_flag || Kernel::tick_count == 0 || args.inputs.mouse.wheel
    if args.inputs.mouse.wheel
      $Scalar += args.inputs.mouse.wheel.y.sign
      $WIDTH = 16*$Scalar
      $HEIGHT = 9*$Scalar
      $Scale = $HEIGHT / 4
    end
    # Update the orientation matrix
    [:d, :a, :w, :s, :q, :e].each do |key|
      next unless args.inputs.keyboard.key_held.send(key)
      args.state.orient_mtx = MatrixMath::dot(args.state.orient_mtx, args.state.ctrl_mtx[key]) unless AbsControls
      args.state.orient_mtx = args.state.ctrl_mtx[key] if AbsControls
    end
    # Calculate the delta rotation matrix of the model by multiplying the updated orientation mtx by its non-updated inverse
    delta = MatrixMath::dot(args.state.orient_mtx, args.state.inv_orient_mtx) unless AbsControls
    delta = args.state.orient_mtx if AbsControls
    # Update the inverse orientation matrix
    [:d, :a, :w, :s, :q, :e].each do |key|
      next if AbsControls
      next unless args.inputs.keyboard.key_held.send(key)
      args.state.inv_orient_mtx = MatrixMath::dot(args.state.ctrl_mtx[key].transpose, args.state.inv_orient_mtx)
    end
    # Rotate the model
    args.state.model.fast_3x3_transform!(delta)
    scene = $Scalar != 80 ? args.render_target(:scene) : args.outputs
    scene.width = $WIDTH
    scene.height = $HEIGHT
    prims = render3D(args.state.model)
    args.outputs.static_primitives.clear
    scene.static_primitives << prims
    args.outputs.static_labels.clear
    args.outputs.static_labels << {x: 10, y: 30, text: $Scalar, r: 255, g: 0, b:0}
    ## Sort the lines by z index so we get proper z-buffering. TODO: do this in a less dumb way.
    #args.outputs.static_lines.sort!
  end
  args.sprites << [0,0,1280,720,:scene] unless $Scalar == 80
  args.outputs.primitives << args.gtk.framerate_diagnostics_primitives
end

# @param [Object3D] model
# @return [Array]
def render3D(model)
  # puts model.faces.map(&:to_s).join("\n")
  model.faces.sort_by { |face| face.verts[0].y.greater(face.verts[1].y).greater(face.verts[2].y) }.flat_map do
      # @type face [Face]
    |face|
    face_to_lines(face)
  end
end

# TODO: This is wildly inefficient. Replace all these solids with two rotated triangle sprites at some point
# @param [Face] face
def face_to_lines(face)
  Kernel.raise "non tris not supported" if face.verts.length != 3
  v1, v2, v3 = face.verts.map { |vert| [vert.render_x, vert.render_y, vert.y] }.sort_by { |vert| vert.y }
  cross = VectorMath::normalize(VectorMath::cross3((face.verts[1] - face.verts[0]).row_vector, (face.verts[2] - face.verts[0]).row_vector))
  r          = 254 * VectorMath::dot(cross,[0.0, 1.0, 0.0]).abs + 1
  g          = 254 * VectorMath::dot(cross,[1.0, 0.0, 0.0]).abs + 1
  b          = 254 * VectorMath::dot(cross,[0.0, 0.0, 1.0]).abs + 1
  g = b = r
  out = draw_tri(v1.x,v1.y,v2.x,v2.y,v3.x,v3.y,r,g,b)
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
  [0, 1, 2].map{|i|{x:[v1, v2, v3][i - 1].x,y:[v1, v2, v3][i - 1].y,x2:[v1, v2, v3][i].x,y2:[v1, v2, v3][i].y,r:r,g:g,b:b,a:a}.line} +
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



# @param [Float] theta_x
# @param [Float] theta_y
# @param [Float] theta_z
# @return [Array<Array<Float>>]
def rotate3D(theta_x = 0.1, theta_y = 0.1, theta_z = 0.1)
  c_x, s_x = Math.cos(theta_x), Math.sin(theta_x)
  c_y, s_y = Math.cos(theta_y), Math.sin(theta_y)
  c_z, s_z = Math.cos(theta_z), Math.sin(theta_z)
  rot_x    = [
      [1, 0, 0],
      [0, c_x, -s_x],
      [0, s_x, c_x],
  ]
  rot_y    = [
      [c_y, 0, s_y],
      [0, 1, 0],
      [-s_y, 0, c_y],
  ]
  rot_z    = [
      [c_z, -s_z, 0],
      [s_z, c_z, 0],
      [0, 0, 1],
  ]
  MatrixMath.dot(MatrixMath.dot(rot_x, rot_y), rot_z)
end

class Vertex

  attr_reader :x, :y, :z
  attr_accessor :id
  # @param [Array<String>] data
  # @param [Integer] id
  # @param [TrueClass, FalseClass] data_str
  # @return [Vertex]
  def initialize(data, id, data_str = true)
    @x = data[0]
    @y = data[1]
    @z = data[2]
    if data_str
      @x = @x.to_f
      @y = @y.to_f
      @z = @z.to_f
    end
    @id = id
    self
  end

  def fast_3x3_transform!(mtx)
    @x, @y, @z = mtx[0][0] * @x + mtx[0][1] * @y + mtx[0][2] * @z, mtx[1][0] * @x + mtx[1][1] * @y + mtx[1][2] * @z, mtx[2][0] * @x + mtx[2][1] * @y + mtx[2][2] * @z
  end

  # @return [Array<Array<Float>>]
  def col_vector
    [
        [@x],
        [@y],
        [@z]
    ]
  end

  # @return [Array<Float>]
  def row_vector
    [
        @x,
        @y,
        @z
    ]
  end

  # @param [Array<Array<Float>>] col
  # @return [nil]
  def set_col_vector(col)
    @x = col[0][0]
    @y = col[1][0]
    @z = col[2][0]
  end

  # @return [Hash]
  def serialize
    {
        x:  @x,
        y:  @y,
        z:  @z,
        id: @id
    }
  end

  def inspect
    serialize.to_s
  end

  def to_s
    serialize.to_s
  end

  def render_x
    @x * (10 / (5 - @y)) * $Scale + $WIDTH / 2
  end

  def render_y
    @z * (10 / (5 - @y)) * $Scale + $HEIGHT / 2
  end

  # @param [Integer] x
  # @return [Integer]
  def x=(x)
    @x = x
  end

  # @param [Integer] y
  # @return [Integer]
  def y=(y)
    @y = y
  end

  # @param [Integer] z
  # @return [Integer]
  def z=(z)
    @z = z
  end

  # @return [Vertex]
  # @param [Vertex] other
  def -(other)
    Vertex.new([@x - other.x, @y - other.y, @z - other.z], -1, false)
  end

  # @return [Vertex]
  # @param [Vertex] other
  def +(other)
    Vertex.new([@x + other.x, @y + other.y, @z + other.z], -1, false)
  end
end

class Face

  attr_reader :verts, :edges, :outlines
  # @param [Array<String>] data
  # @param [Array<Vertex>] verts
  # @return [Face]
  def initialize(data, verts)
    vert_count = data[0].to_i
    vert_ids   = data[1, vert_count].map(&:to_i)
    @verts     = vert_ids.map { |i| verts[i] }
    # @type [Array<Edge>]
    @edges = []
    (0...vert_count).each { |i| @edges[i] = Edge.new(verts[vert_ids[i - 1]], verts[vert_ids[i]]) }
    @edges.rotate!(1)
    @outlines = @edges.flat_map{|e|e.dupe_off_thick}
    self
  end

  # @return [Hash]
  def serialize
    {
        verts: @verts,
        edges: @edges,
    }
  end

  # @return [String]
  def inspect
    serialize.to_s
  end

  # @return [String]
  def to_s
    serialize.to_s
  end
end

class Edge
  attr_accessor :r, :g, :b, :a
  attr_reader :point_a, :point_b
  # @param [Vertex] point_a
  # @param [Vertex] point_b
  # @return [Edge]
  def initialize(point_a, point_b, x_off = 0, y_off = 0)
    # @type [Vertex]
    @point_a = point_a
    # @type [Vertex]
    @point_b = point_b
    @a       = 255
    @r       = 255
    @g       = 0
    @b       = 0
    @x_off   = x_off
    @y_off   = y_off
  end

  # @return [Edge]
  def sorted
    @point_a.id < @point_b.id ? self : Edge.new(@point_b, @point_a)
  end

  def dupe_off
    [
        self,
        Edge.new(@point_a, @point_b, 0, 1),
        Edge.new(@point_a, @point_b, 1, 0),
        Edge.new(@point_a, @point_b, 1, 1),
    ]
  end
  def dupe_off_thick
    [
        Edge.new(@point_a, @point_b, 1, 0),
        Edge.new(@point_a, @point_b, -1, 0),
        Edge.new(@point_a, @point_b, 0, 1),
        Edge.new(@point_a, @point_b, 0, -1),
    ]
  end

  # @return [Hash]
  def serialize
    {
        point_a: @point_a,
        point_b: @point_b,
    }
  end

  # @return [String]
  def inspect
    serialize.to_s
  end

  # @return [String]
  def to_s
    serialize.to_s
  end

  def x
    @point_a.render_x + @x_off
  end

  def y
    @point_a.render_y + @y_off
  end

  def x2
    @point_b.render_x + @x_off
  end

  def y2
    @point_b.render_y + @y_off
  end

  def r
    200 * VectorMath::sin((@point_a - @point_b).row_vector, [0.0, 1.0, 0.0]).abs + 55
  end

  def g
    0 #200 * VectorMath::sin((@point_a-@point_b).row_vector,[0.0,1.0,0.0]).abs + 55
  end

  def b
    0 #200 * VectorMath::sin((@point_a-@point_b).row_vector,[0.0,1.0,0.0]).abs + 55
  end

  def z
    (@point_a.y + @point_b.y) * 0.5
  end

  def <=> rhs
    z - rhs.z
  end

  def primitive_marker
    :line
  end
end

class Object3D
  # @!attribute [rw] verts
  #   @return [Array<Vertex>]
  attr_reader :vert_count, :face_count, :edge_count, :verts, :faces, :edges
  NewParameters = {
      path: 'data/model.off'
  }

  # @return [Object3D]
  # @param [Hash] parameters - Merged with Object3D::NewParameters
  def initialize(parameters = {})
    @vert_count = 0
    @face_count = 0
    @edge_count = 0
    # @type [Array<Vertex>]
    @verts = []
    @faces = []
    @edges = []

    params = Object3D::NewParameters.merge(parameters)
    _init_from_file(params[:path])
    self
  end

  # @param [String] path
  # @return [nil]
  def _init_from_file(path)
    # @type [Array<Array<String>>]
    file_lines = $gtk.read_file(path).split("\n")
                     .reject { |line| line.start_with?('#') || line.split(' ').length == 0 } # Strip out simple comments and blank lines
                     .map { |line| line.split('#')[0] } # Strip out end of line comments
                     .map { |line| line.split(' ') } # Tokenize by splitting on whitespace
    raise "OFF file did not start with OFF." if file_lines.shift != ["OFF"]
    raise "<NVertices NFaces NEdges> line malformed" if file_lines[0].length != 3
    @vert_count, @face_count, @edge_count = file_lines.shift&.map(&:to_i)
    raise "Incorrect number of vertices and/or faces (Parsed VFE header: #{@vert_count} #{@face_count} #{@edge_count})" if file_lines.length != @vert_count + @face_count
    vert_lines = file_lines[0, @vert_count]
    face_lines = file_lines[@vert_count, @face_count]
    @verts     = vert_lines.map_with_index { |line, id| Vertex.new(line, id) }
    # @type [Array<Face>]
    @faces = face_lines.map { |line| Face.new(line, @verts) }
    @edges = @faces.flat_map(&:edges).uniq do |edge|
      sorted = edge.sorted
      [sorted.point_a, sorted.point_b]
    end
  end

  # @param [Array<Array<Float>>] mtx
  # @return [nil]
  def fast_3x3_transform!(mtx)
    @verts.each { |vert| vert.fast_3x3_transform!(mtx) }
  end

  # @return [Hash]
  def serialize
    {
        vert_count: @vert_count,
        face_count: @face_count,
        edge_count: @edge_count,
        verts:      @verts,
        faces:      @faces,
        edges:      @edges,
    }
  end

  # @return [String]
  def inspect
    serialize.to_s
  end

  # @return [String]
  def to_s
    serialize.to_s
  end
end